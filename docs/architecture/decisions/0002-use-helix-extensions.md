# Use Helix Extensions

* Status: accepted
* Deciders: Nathan Fiedler
* Date: 2020-08-20

## Context

The goal of the authentication integration project is to enable our products to leverage existing authentication standards as implemented by third party providers. This consists of OpenID Connect and SAML 2.0, both of which are open standards with numerous providers available to choose from. For the purpose of integrating with Helix Core server, this integration must be facilitated via something akin to triggers.

Around the time this project first started, support for extensions was being introduced to Helix Core. This offered a standard, easy to learn language, a built-in runtime, with logging, and library of functions to use that would be available on all platforms supported by Helix Core. Compare this with the option of writing triggers in something like Python or Ruby. While that is certainly feasible, it is not always a simple matter to install and configure triggers based on a dynamic scripting language. The previous generation of SAML integration employed a set of Python triggers -- it was okay on Linux-based systems where Python is easy to install, but unworkable for Windows systems (e.g. installing the `libxml` prerequisite was basically impossible).

## Decision

It was decided early on by the architect(s) to use Helix Core **extensions** to integrate with the authentication providers. While installation and configuration of extensions is easy, it does require having a current release of Helix Core (at least 2019.1).

Other benefits of using extensions include the ease-of-use, primarily around installation and configuration. If triggers were used, they would need to be configured, probably with a file, and that file location would have to be known at run time by the triggers, and be readable by the user running the trigger. Additionally, the trigger would need a long-lived p4 ticket in order to be able to invoke commands against the server. With extensions, we do not have any of those problems. Lastly, since the extension stays resident in memory during the login process, the request identifier retrieved in `AuthPreSSO` is accessible to `AuthCheckSSO` without the need to persist the value on disk.

## Consequence

The choice of extensions has worked well for the most part. Customers are fine with upgrading Helix Core, and since that is the only prerequisite, it means that installing the extensions is easy compared to installing Python and any necessary libraries.

One drawback with extensions was that support for them was not available on Windows systems until the 2021.2 release. This limited some opportunites with Windows-only customers.
