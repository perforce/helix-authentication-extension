//
// Copyright 2022 Perforce Software
//
import { assert } from 'chai'
import { after, before, describe, it } from 'mocha'
import getPort from 'get-port'
import * as helpers from 'helix-auth-extension/test/helpers.js'
import * as runner from 'helix-auth-extension/test/runner.js'
import p4pkg from 'p4api'
const { P4 } = p4pkg

describe('RunCommand', function () {
  let serviceProcess
  let p4config
  let port

  before(async function () {
    this.timeout(30000)
    p4config = await runner.startServer()
    // establish a super user and create the test user
    helpers.establishSuper(p4config)
    // start the authentication mock service
    port = await getPort()
    serviceProcess = helpers.startNonSslService(port)
  })

  after(async function () {
    this.timeout(30000)
    await runner.stopServer(p4config)
    serviceProcess.kill()
  })

  describe('test-svc failure', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureExtension(p4config, 'oidc', `http://localhost:12345/pass/oidc`)
      await helpers.restartServer(p4config)
    })

    it('should report service error', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: p4config.user
      })
      const loginCmd = p4.cmdSync('login', 'p8ssword')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const extCmd = p4.cmdSync('extension --run testing test-svc')
      assert.isTrue(helpers.findData(extCmd, "Couldn't connect to server"))
    })
  })

  describe('test-svc success', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
      await helpers.restartServer(p4config)
    })

    it('should indicate request start success', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: p4config.user
      })
      const loginCmd = p4.cmdSync('login', 'p8ssword')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const extCmd = p4.cmdSync('extension --run testing test-svc')
      assert.isTrue(helpers.findData(extCmd, 'Request start: OK'))
    })
  })

  describe('test-ssl success', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/fail/404`)
      await helpers.restartServer(p4config)
    })

    it('should indicate request status success', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: p4config.user
      })
      const loginCmd = p4.cmdSync('login', 'p8ssword')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const extCmd = p4.cmdSync('extension --run testing test-ssl')
      assert.isTrue(helpers.findData(extCmd, 'Request status: OK'))
    })
  })

  describe('test-cmd success', function () {
    before(async function () {
      helpers.installExtension(p4config)
      helpers.configureExtension(p4config, 'oidc', `http://localhost:${port}/pass/oidc`)
      await helpers.restartServer(p4config)
    })

    it('should indicate command success', function () {
      const p4 = new P4({
        P4PORT: p4config.port,
        P4USER: p4config.user
      })
      const loginCmd = p4.cmdSync('login', 'p8ssword')
      assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
      const extCmd = p4.cmdSync('extension --run testing test-cmd')
      assert.isTrue(helpers.findData(extCmd, 'Command successful'))
    })
  })

  // Testing command failure is difficult without a reliable means of
  // reproducing the underlying tickets issue on every test system.
})
