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

function getData (command) {
  // Some commands (or just `p4 extension --package` apparently) return their
  // data differently depending on the version of p4/p4d. How fun.
  if (command.prompt) {
    return command.prompt.trim()
  } else if (command.info && Array.isArray(command.info) && command.info.length > 0) {
    return command.info[0].data
  }
  throw new Error('command does not have a readable value:', command)
}

function establishTrust (config) {
  const p4 = makeP4(config)
  const trustCmd = p4.cmdSync('trust -y -f')
  assert.include(trustCmd.data, 'Added trust for P4PORT')
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
  const configCmd = p4.cmdSync('configure set security=3')
  assert.equal(configCmd.stat[0].Action, 'set')
}

function createUser (user, password, config) {
  const p4 = makeP4(config)
  const userIn = p4.cmdSync('user -i -f', user)
  assert.equal(userIn.info[0].data, `User ${user.User} saved.`)
  const passwdCmd = p4.cmdSync(`passwd ${user.User}`, `${password}\n${password}`)
  assert.equal(passwdCmd.info[0].data, 'Password updated.')
}

function createGroup (group, config) {
  const p4 = makeP4(config)
  const groupOut = p4.cmdSync(`group -o ${group.Group}`)
  const input = Object.assign({}, groupOut.stat[0], group)
  delete input.code
  const groupIn = p4.cmdSync('group -i', input)
  assert.equal(groupIn.info[0].data, `Group ${group.Group} created.`)
}

function startService (env) {
  // must run the service in another process
  return fork('./test/www', [], { env, stdio: 'ignore' })
}

function startNonSslService (port) {
  return startService({ PORT: port })
}

function startSslService (port) {
  return startService({ PORT: port, USE_SSL: true })
}

function installExtension (config) {
  const p4 = makeP4(config)
  const listCmd = p4.cmdSync('extension --list --type=extensions')
  if ('stat' in listCmd && listCmd.stat[0].extension === 'Auth::loginhook') {
    const deleteCmd = p4.cmdSync('extension --delete Auth::loginhook -y')
    assert.include(deleteCmd.info[0].data, 'successfully deleted')
  }
  if (fs.existsSync('loginhook.p4-extension')) {
    fs.unlinkSync('loginhook.p4-extension')
  }
  const packageCmd = p4.cmdSync('extension --package loginhook')
  assert.equal(getData(packageCmd), 'Extension packaged successfully.')
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
    'non-sso-groups:\n\tadmins\n' +
    'non-sso-users:\n\tbruno\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

// like configureExtension, but with only sso-users defined
function configureSsoUsers (config, protocol, serviceUrl) {
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
    'non-sso-groups:\n\t... ignore\n' +
    'non-sso-users:\n\t... ignore\n' +
    'sso-users:\n\trepoman\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

// like configureExtension, but with only sso-groups defined
function configureSsoGroups (config, protocol, serviceUrl) {
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
    'non-sso-groups:\n\t... ignore\n' +
    'non-sso-users:\n\t... ignore\n' +
    'sso-groups:\n\trequireds\n' +
    'sso-users:\n\t... none\n' +
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
  establishTrust,
  establishSuper,
  createUser,
  createGroup,
  startNonSslService,
  startSslService,
  installExtension,
  configureExtension,
  configureSsoUsers,
  configureSsoGroups,
  restartServer,
  readExtensionLog
}
