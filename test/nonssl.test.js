//
// Copyright 2020-2021 Perforce Software
//
import { assert } from 'chai'
import { after, before, describe, it } from 'mocha'
import getPort from 'get-port'
import * as helpers from 'helix-auth-extension/test/helpers.js'
import * as runner from 'helix-auth-extension/test/runner.js'
import p4pkg from 'p4api'
const { P4 } = p4pkg

describe('Non-SSL', function () {
  let serviceProcess
  let p4config
  let port

  before(async function () {
    this.timeout(30000)
    p4config = await runner.startServer()
    // establish a super user and create the test user
    helpers.establishSuper(p4config)
    helpers.createUser({
      User: 'clientman',
      Email: 'clientman@example.com',
      FullName: '4dbdf450-958d-4c64-88b2-abba2e46f1ff'
    }, '1c6c49155699d49b397c', p4config)
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
    this.timeout(30000)
    await runner.stopServer(p4config)
    serviceProcess.kill()
  })

  describe('Success cases', function () {
    this.timeout(30000)
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
        assert.include(log, 'info: skipping SSO for user')
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
        assert.include(log, 'info: skipping SSO for user')
      })
    })

    describe('sso-groups login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.createGroup({
          Group: 'requireds',
          Users0: 'repoman'
        }, p4config)
        helpers.configureSsoGroups(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
        await helpers.restartServer(p4config)
      })

      it('should login required SSO groups successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: 'repoman'
        })
        const loginCmd = p4.cmdSync('login', 'secret123')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: checking user')
        assert.include(log, 'info: identifiers match')
      })

      it('should login non-SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: p4config.user
        })
        const loginCmd = p4.cmdSync('login', 'p8ssword')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: skipping user, SSO not required')
      })
    })

    describe('sso-users login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureSsoUsers(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
        await helpers.restartServer(p4config)
      })

      it('should login required SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: 'repoman'
        })
        const loginCmd = p4.cmdSync('login', 'secret123')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: checking user')
        assert.include(log, 'info: identifiers match')
      })

      it('should login non-SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: p4config.user
        })
        const loginCmd = p4.cmdSync('login', 'p8ssword')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: skipping user, SSO not required')
      })
    })

    describe('client-sso-groups login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.createGroup({
          Group: 'client_sso',
          Users0: 'clientman'
        }, p4config)
        helpers.configureClientGroups(p4config, 'oidc', `http://localhost:${port}/pass/token`)
        await helpers.restartServer(p4config)
      })

      it('should login client-sso groups successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: 'clientman',
          P4LOGINSSO: './test/webtoken.sh'
        })
        const loginCmd = p4.cmdSync('login', 'secret123')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: checking user')
        assert.include(log, 'info: identifiers match')
      })

      it('should login non-SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: p4config.user
        })
        const loginCmd = p4.cmdSync('login', 'p8ssword')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: skipping SSO for user')
      })
    })

    describe('client-sso-users login', function () {
      before(async function () {
        helpers.installExtension(p4config)
        helpers.configureClientUsers(p4config, 'oidc', `http://localhost:${port}/pass/token`)
        await helpers.restartServer(p4config)
      })

      it('should login required SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: 'clientman',
          P4LOGINSSO: './test/webtoken.sh'
        })
        const loginCmd = p4.cmdSync('login', 'secret123')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: checking user')
        assert.include(log, 'info: identifiers match')
      })

      it('should login non-SSO users successfully', function () {
        const p4 = new P4({
          P4PORT: p4config.port,
          P4USER: p4config.user
        })
        const loginCmd = p4.cmdSync('login', 'p8ssword')
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'info: skipping SSO for user')
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
        // and it has already verified the profile so we have a ticket
        assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, '"nameID":"rEpOmAn@example.com"')
        assert.include(log, 'info: identifiers match')
      })
    })
  })

  describe('Failure cases', function () {
    this.timeout(30000)
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
        // and it has already failed validation
        assert.isTrue(helpers.findData(loginCmd, 'validation failed'))
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
        // and it has already failed validation
        assert.isTrue(helpers.findData(loginCmd, 'validation failed'))
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
        // and it has already failed validation
        assert.isTrue(helpers.findData(loginCmd, 'validation failed'))
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
        // will emit a error message about the service
        assert.isTrue(helpers.findData(loginCmd, 'error connecting to service'))
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
        assert.isTrue(helpers.findData(loginCmd, 'Navigate to URL'))
        // and it has already failed validation
        assert.isTrue(helpers.findData(loginCmd, 'validation failed'))
        const log = helpers.readExtensionLog(p4config)
        assert.include(log, 'error: identifiers do not match')
      })
    })
  })
})
