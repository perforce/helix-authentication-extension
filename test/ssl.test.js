//
// Copyright 2020 Perforce Software
//
const { assert } = require('chai')
const { after, before, describe, it } = require('mocha')
const { P4 } = require('p4api')
const getPort = require('get-port')
const helpers = require('./helpers')
const runner = require('./runner')

describe('SSL', function () {
  let serviceProcess
  let p4config
  let port

  before(async function () {
    this.timeout(30000)
    p4config = await runner.startSslServer()
    helpers.establishTrust(p4config)
    // establish a super user and create the test user
    helpers.establishSuper(p4config)
    helpers.createUser({
      User: 'repoman',
      Email: 'repoman@example.com',
      FullName: 'Repo Man'
    }, '3E61275075F3AE4D1844', p4config)
    helpers.createUser({
      User: 'nimda',
      Email: 'nimda@example.com',
      FullName: 'Admin Man'
    }, 'secret123', p4config)
    helpers.createGroup({
      Group: 'admins',
      Users0: 'nimda'
    }, p4config)
    // start the authentication mock service
    port = await getPort()
    serviceProcess = helpers.startSslService(port)
  })

  after(async function () {
    this.timeout(30000)
    await runner.stopServer(p4config)
    serviceProcess.kill()
  })

  describe('Success cases', function () {
    this.timeout(30000)
    describe('non-sso-users login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `https://localhost:${port}/pass/oidc`)
        await helpers.restartServer(p4config)
      })

      it('should login successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: p4config.user
        })
        const loginCmd = p4.cmdSync('login', 'p8ssword')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: skipping user bruno')
      })
    })

    describe('non-sso-groups login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `https://localhost:${port}/pass/oidc`)
        await helpers.restartServer(p4config)
      })

      it('should login successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: 'nimda'
        })
        const loginCmd = p4.cmdSync('login', 'secret123')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: group-based skipping user nimda')
      })
    })

    describe('login with OpenID Connect', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `https://localhost:${port}/pass/oidc`)
        await helpers.restartServer(p4config)
      })

      it('should login successfully', function () {
        const config = {
          P4USER: 'repoman',
          P4PORT: p4config.port,
          P4USEBROWSER: false
        }
        const p4 = new P4(config)
        const loginCmd = p4.cmdSync('login')
        // should prompt the user to open a URL
        assert.include(helpers.getData(loginCmd), 'Navigate to URL')
        // and it has already verified the profile so we have a ticket
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"preferred_username":"repoman"')
        assert.include(log, 'info: identifiers match')
      })
    })
  })

  describe('Failure cases', function () {
    this.timeout(30000)
    describe('user identifiers do not match', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'saml', `https://localhost:${port}/fail/mismatch`)
        await helpers.restartServer(p4config)
      })

      it('should login successfully', function () {
        const config = {
          P4USER: 'repoman',
          P4PORT: p4config.port,
          P4USEBROWSER: false
        }
        const p4 = new P4(config)
        const loginCmd = p4.cmdSync('login')
        // should prompt the user to open a URL
        assert.include(helpers.getData(loginCmd), 'Navigate to URL')
        // and it has already failed validation
        assert.include(helpers.getErrorData(loginCmd), 'validation failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'error: identifiers do not match')
      })
    })
  })
})
