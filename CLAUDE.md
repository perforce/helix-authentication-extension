# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

The P4 Authentication Extension is a **Helix Core Server (p4d) extension written in Lua** that adds
web-based Single-Sign-On (SSO). The shippable code is two Lua files; everything else (JavaScript,
shell, Docker) exists to build, configure, and test it. The extension has no runtime dependencies
beyond what p4d itself provides (curl, JSON/cjson, SSL).

The extension is the client half of a two-part system: it talks over HTTP/S to the separate
**P4 Authentication Service** (https://github.com/perforce/helix-authentication-service), which in
turn brokers OIDC/SAML 2.0 with the actual identity provider. Most end-to-end behavior cannot be
exercised without that service (or a mock of it — see `test/www.js`).

## Commands

```shell
npm install        # install JS test dependencies
npm test           # run the full Mocha suite (mocha --recursive --exit)

# run a single test file
npx mocha test/command.test.js

# run tests matching a name
npx mocha --recursive test/ --grep "test-svc"
```

**Tests require the `p4d` and `p4` binaries on PATH.** The suite spawns real `p4d` instances on
random ports (`test/runner.js`), installs/packages the extension against them, and drives logins
via the `p4api` npm package. There is no mocking of p4d itself; only the auth service is mocked
(`test/www.js`, an Express app started in a forked process by `test/helpers.js`).

The `bin/configure-login-hook.sh` script uses GNU getopt, which macOS lacks. On macOS, prefix PATH
with the Homebrew `gnu-getopt` (e.g. `/opt/homebrew/opt/gnu-getopt/bin` on Apple Silicon).

## Architecture

### The two hook entry points (`loginhook/main.lua`)

p4d invokes the extension at two points during `p4 login`, registered in `InstanceConfigEvents()`:

- **`AuthPreSSO()`** — decides *whether and how* a user authenticates, and hands p4d a login URL.
  Its return tuple is overloaded; the header comment above the function documents the five cases
  (return `false` to fail through to another auth method, return `true, url` for P4PHP/TeamHub
  clients, return `true, "unused", <url>, false` to open a browser, etc.). This hook cannot send
  client messages — `SetClientMsg` is a no-op here, so errors are deferred to `AuthCheckSSO`.
- **`AuthCheckSSO()`** — validates the result. Two modes:
  - *2-step* (normal): long-polls the service's `/requests/status` route, which blocks until the
    user authenticates with the IdP or times out, then compares identifiers.
  - *1-step*: when a token/password is supplied directly (Swarm sends a SAML response this way),
    it validates against `/saml/validate` or `/oauth/validate` instead of polling.
- **`RunCommand()`** — backs `p4 extension --run testing test-svc|test-ssl|test-cmd|test-all`,
  diagnostic commands for verifying connectivity to the service.

### User routing logic (the heart of the feature)

`AuthPreSSO` classifies each user through a series of checks (all implemented in
`loginhook/ExtUtils.lua`) **in this precedence order**:

1. Non-`standard` user types and `ldap*` auth methods are unconditionally skipped (SSO bypassed).
2. `client-sso-users` / `client-sso-groups` → must authenticate via a `P4LOGINSSO` program that
   returns a JWT (`usingClient = true`, validated through the OAuth route).
3. `sso-users` / `sso-groups` (the "required" lists) → if a required list exists, users *not* in it
   are skipped; users in it must use SSO.
4. Only when no required list exists do the `non-sso-users` / `non-sso-groups` ("skip") lists apply.

This precedence is the source of most behavioral subtlety — preserve it when editing. The list
membership helpers (`isClientUser`, `isRequiredUser`, `isSkipUser`) all return
`(ok, matches, hasList)` triples, and a `false` `ok` (a failed `p4` sub-command) causes
`AuthPreSSO` to return `false` rather than risk locking out all users.

### Identifier matching

SSO succeeds when the p4d-side identifier matches the IdP-side identifier (case-insensitively):
- `user-identifier` / `client-user-identifier` — which trigger var (`email`, `fullname`, `user`)
  identifies the p4d user.
- `name-identifier` / `client-name-identifier` — which field of the IdP/JWT response to compare
  against. Both default to `email`.

### Configuration model

Config lives in p4d, not files. Two scopes, both declared in `main.lua`:
- **`GlobalConfigFields()`** — service connection: `Service-URL`, certs (`Client-Cert`,
  `Client-Key`, `Authority-Cert`), `Verify-Peer`/`Verify-Host`, `Auth-Protocol`, `Resolve-Host`.
- **`InstanceConfigFields()`** — per-instance user routing lists and identifier fields above, plus
  `enable-logging`.

A leading `...` in any value means "unchanged from the documentation default" — it is a Perforce
wildcard that cannot otherwise appear, so the Lua code treats `^%.%.%.` as "unset" everywhere
(see the `string.match( v, "^%.%.%." )` guards throughout `ExtUtils.lua`). When adding a setting,
follow this convention.

### Packaging

`loginhook.p4-extension` is a **zip archive** of the `loginhook/` directory (Lua sources, manifest,
and the bundled self-signed `ca.crt`/`client.crt`/`client.key`). It is produced by
`p4 extension --package loginhook` and committed to the repo. The bundled certs are why the curl
code defaults `Verify-Peer`/`Verify-Host` to off. `loginhook/manifest.json` carries the version,
the fixed extension key `117E9283-...`, and the required p4d `api_version`.

### `ExtUtils.lua`

Shared helpers, with state in `ExtUtils.gCfgData` / `iCfgData` / `manifest`, lazily loaded by
`ExtUtils.init()` (called at the top of every hook). Includes URL builders, the cert/SSL option
resolvers, the user-list logic above, `runP4command` (wraps `P4.P4` with error capture and forces
a fresh ticket), and `isOlderP4V` (version-sniffs the `clientprog`/`clientversion` trigger vars to
reject pre-2019 P4V that lacks `login2` support).

## Testing infrastructure details

- `test/helpers.js` — the toolkit: spins up super user, creates users/groups/LDAP/service users,
  packages+installs the extension (`installExtension`), and applies named config permutations
  (`configureExtension`, `configureSsoUsers`, `configureSsoGroups`, `configureClientUsers`,
  `configureClientGroups`). Read these to understand exactly which config each test exercises.
- `test/runner.js` — starts/stops disposable `p4d` servers (non-SSL and SSL) under `./tmp/p4d`.
- `test/www.js` / `test/app.js` — the mock auth service with `/pass/...` and `/fail/...` routes.
- `test/install/` — Dockerfiles (CentOS8, Rocky9, Ubuntu22/24, Amazon2) + `runtest.sh` for
  validating installation across Linux distros.
- `containers/` + `docker-compose.yml` — a fuller manual test rig (standalone p4d, Swarm,
  commit/edge `chicago`/`tokyo`). See `containers/README.md`; requires `.doc` name resolution
  (dnsmasq) and the auth-service containers running alongside.

## Conventions

- Lua sources target the **Lua 5.3** runtime embedded in p4d (per `manifest.json`); only the
  libraries p4d exposes (`cjson`, `cURL.safe`, `P4`, the `Helix.Core.Server` API) are available.
- JS is ESM (`"type": "module"`); tests import the package by its own name
  (`helix-auth-extension/test/...`) via the self-referencing `exports` map in `package.json`.
- Versioning: official releases are `YYYY.N`; patches add a third number; snapshots append
  `-snapshot`. Bump both `package.json` and `loginhook/manifest.json` together, and update
  `RELNOTES.txt`.
- Admin-facing docs live in `docs/` (current `Administrator-Guide.md` plus dated archives,
  `LDAP.md`, `Architecture.md`, `Development.md`).
