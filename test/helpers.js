//
// Copyright 2020 Perforce Software
//
const { fork } = require('child_process')
const fs = require('fs')
const path = require('path')
const { assert } = require('chai')
const { P4 } = require('p4api')

function makeP4 (config) {
  const p4 = new P4({
    P4PORT: config.port,
    P4USER: config.user,
    P4PASSWD: config.password
  })
  return p4
}

function establishSuper (config) {
  const p4 = makeP4(config)
  const userOut = p4.cmdSync('user -o')
  const userSpec = userOut.stat[0]
  userSpec.Email = 'bruno@example.com'
  userSpec.FullName = 'Bruno Venus'
  const userIn = p4.cmdSync('user -i', userSpec)
  assert.equal(userIn.info[0].data, 'User bruno saved.')
  const passwdCmd = p4.cmdSync('passwd', 'p8ssword\np8ssword')
  assert.equal(passwdCmd.info[0].data, 'Password updated.')
  const loginCmd = p4.cmdSync('login', 'p8ssword')
  assert.equal(loginCmd.stat[0].TicketExpiration, '43200')
}

function createUser (user, config) {
  const p4 = makeP4(config)
  const userIn = p4.cmdSync('user -i -f', user)
  assert.equal(userIn.info[0].data, `User ${user.User} saved.`)
  const passwdCmd = p4.cmdSync(`passwd -P 3E61275075F3AE4D1844 ${user.User}`)
  assert.equal(passwdCmd.info[0].data, 'Password updated.')
}

function startService (port) {
  // must run the service in another process
  return fork('./test/www', [], { env: { PORT: port }, stdio: 'ignore' })
}

function installExtension (config) {
  const p4 = makeP4(config)
  const listCmd = p4.cmdSync('extension --list --type=extensions')
  if ('stat' in listCmd && listCmd.stat[0].extension === 'Auth::loginhook') {
    const deleteCmd = p4.cmdSync('extension --delete Auth::loginhook -y')
    assert.include(deleteCmd.info[0].data, 'successfully deleted')
  }
  fs.unlinkSync('loginhook.p4-extension')
  const packageCmd = p4.cmdSync('extension --package loginhook')
  assert.equal(packageCmd.info[0].data, 'Extension packaged successfully.')
  const installCmd = p4.cmdSync('extension --install loginhook.p4-extension -y')
  assert.include(installCmd.info[0].data, 'installed successfully')
}

function configureExtension (config, protocol, serviceUrl) {
  const p4 = makeP4(config)
  // configure global
  const globalOut = p4.cmdSync('extension --configure Auth::loginhook -o')
  const globalSpec = globalOut.stat[0]
  globalSpec.ExtP4USER = config.user
  globalSpec.ExtConfig = `Auth-Protocol:\n\t${protocol}\nService-URL:\n\t${serviceUrl}\n`
  const globalIn = p4.cmdSync('extension --configure Auth::loginhook -i', globalSpec)
  assert.equal(globalIn.info[0].data, 'Extension config loginhook saved.')

  // configure instance
  const instanceOut = p4.cmdSync('extension --configure Auth::loginhook --name testing -o')
  const instanceSpec = instanceOut.stat[0]
  instanceSpec.ExtConfig = 'enable-logging:\n\ttrue\n' +
    `name-identifier:\n\t${protocol === 'oidc' ? 'email' : 'nameID'}\n` +
    'non-sso-groups:\n\t...\n' +
    'non-sso-users:\n\tbruno\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

function restartServer (config) {
  return new Promise((resolve, reject) => {
    const p4 = makeP4(config)
    p4.cmdSync('admin restart')
    // give the server time to start up again
    setTimeout(resolve, 100)
  })
}

const dataDirPath = ['server.extensions.dir', '117E9283-732B-45A6-9993-AE64C354F1C5', '1-data']

function readExtensionLog (config) {
  const logPath = path.join(config.p4root, ...dataDirPath, 'log.json')
  return fs.readFileSync(logPath, 'utf8')
}

module.exports = {
  establishSuper,
  createUser,
  startService,
  installExtension,
  configureExtension,
  restartServer,
  readExtensionLog
}