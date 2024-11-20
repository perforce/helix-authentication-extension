//
// Copyright 2024 Perforce Software
//
import { assert } from 'chai'
import { after, before, describe, it } from 'mocha'
import getPort from 'get-port'
import * as helpers from 'helix-auth-extension/test/helpers.js'
import * as runner from 'helix-auth-extension/test/runner.js'
import p4pkg from 'p4api'
const { P4 } = p4pkg

describe('Not SSO users', function () {
  let serviceProcess
  let p4config
  let port

  before(async function () {
    this.timeout(30000)
    p4config = await runner.startServer()
    // establish a super user and create the test user
    helpers.establishSuper(p4config)
    helpers.createLdapUser({
      User: 'george',
      Email: 'george@example.org',
      FullName: 'Curious George'
    }, p4config)
    helpers.createUser({
      User: 'repoman',
      Email: 'repoman@example.com',
      FullName: 'Repo Man'
    }, '3E61275075F3AE4D1844', p4config)
    helpers.createSvcUser({
      User: 'edgelord',
      Email: 'edgelord@example.org',
      FullName: 'Villianess Level 99'
    }, 'BlackHole!', p4config)
    helpers.configureLdap(p4config)
    // start the authentication mock service
    port = await getPort()
    serviceProcess = helpers.startNonSslService(port)
  })

  after(async function () {
    this.timeout(30000)
    await runner.stopServer(p4config)
    serviceProcess.kill()
  })

  describe('LDAP users should ignore SSO configuration', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureSsoUsers(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
      await helpers.restartServer(p4config)
    })

    it('should login non-LDAP "required" users via SSO', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: 'repoman',
        P4USEBROWSER: false
      })
      const loginCmd = p4.cmdSync('login', 'secret123')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const log = helpers.readExtensionLog(p4config)
      assert.include(log, 'info: checking user')
      assert.include(log, 'info: identifiers match')
    })

    it('should ignore LDAP users in "required" list', function () {
      // even though george is listed in the sso-users list, because they are
      // LDAP, they will always be skipped by the extension
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: 'george'
      })
      const loginCmd = p4.cmdSync('login', 'p8ssword')
      // failure is expected because the LDAP server is not reachable
      assert.equal(loginCmd.error[0].data, 'Authentication failed.\n')
      const log = helpers.readExtensionLog(p4config)
      assert.include(log, 'info: skipping LDAP user')
    })
  })

  describe('Service users should ignore SSO configuration', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureSsoUsers(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
      await helpers.restartServer(p4config)
    })

    it('should login non-service "required" users via SSO', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: 'repoman',
        P4USEBROWSER: false
      })
      const loginCmd = p4.cmdSync('login', 'secret123')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const log = helpers.readExtensionLog(p4config)
      assert.include(log, 'info: checking user')
      assert.include(log, 'info: identifiers match')
    })

    it('should ignore service users in "required" list', function () {
      // even though edgelord is listed in the sso-users list, because they are
      // a service user, they will always be skipped by the extension
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: 'edgelord'
      })
      const loginCmd = p4.cmdSync('login', 'BlackHole!')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const log = helpers.readExtensionLog(p4config)
      assert.include(log, 'info: skipping non-standard user')
    })
  })
})
