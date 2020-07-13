//
// Copyright 2020 Perforce Software
//
const { assert } = require('chai')
const { after, before, describe, it } = require('mocha')
const { P4 } = require('p4api')
const getPort = require('get-port')
const helpers = require('./helpers')
const runner = require('./runner')

describe('Non-SSL', function () {
  let serviceProcess
  let p4config
  let port

  before(async function () {
    p4config = await runner.startServer()
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
    serviceProcess = helpers.startNonSslService(port)
  })

  after(async function () {
    await runner.stopServer(p4config)
    serviceProcess.kill()
  })

  describe('Success cases', function () {
    describe('non-sso-users login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
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
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
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
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already verified the profile so we have a ticket
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"preferred_username":"repoman"')
        assert.include(log, 'info: identifiers match')
      })
    })

    describe('login with SAML 2.0', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'saml', `http://localhost:${port}/pass/saml`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already verified the profile so we have a ticket
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"nameID":"repoman@example.com"')
        assert.include(log, 'info: identifiers match')
      })
    })

    describe('login with mixed case identifier', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'saml', `http://localhost:${port}/pass/case`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already verified the profile so we have a ticket
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"nameID":"rEpOmAn@example.com"')
        assert.include(log, 'info: identifiers match')
      })
    })
  })

  describe('Failure cases', function () {
    describe('extension receives 401 from service', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/fail/401`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already failed validation
        assert.include(loginCmd.error[1].data, 'validation failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"http-code":401')
      })
    })

    describe('extension receives 403 from service', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/fail/403`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already failed validation
        assert.include(loginCmd.error[1].data, 'validation failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"http-code":403')
      })
    })

    describe('extension receives 408 from service', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/fail/408`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already failed validation
        assert.include(loginCmd.error[1].data, 'validation failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"http-code":408')
      })
    })

    describe('extension receives error in pre-sso', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/fail/start`)
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
        // should fallback to attempting the ususal SSO login which fails
        // because P4LOGINSSO is not set in the client
        assert.include(loginCmd.error[0].data, 'Single sign-on on client failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"http-code":500')
      })
    })

    describe('user identifiers do not match', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureExtension(p4config, 'saml', `http://localhost:${port}/fail/mismatch`)
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
        assert.include(loginCmd.error[0].data, 'Navigate to URL')
        // and it has already failed validation
        assert.include(loginCmd.error[1].data, 'validation failed')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'error: identifiers do not match')
      })
    })
  })
})
