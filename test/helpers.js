//
// Copyright 2024 Perforce Software
//
import { fork } from 'node:child_process'
import * as fs from 'node:fs'
import * as path from 'node:path'
import { assert } from 'chai'
import p4pkg from 'p4api'
const { P4 } = p4pkg

function makeP4(config) {
  const p4 = new P4({
    P4PORT: config.port,
    P4USER: config.user,
    P4PASSWD: config.password
  })
  return p4
}

// Search all the things to find a string of output that contains query.
export function findData(command, query) {
  if (command.prompt && typeof command.prompt === 'string') {
    if (command.prompt.includes(query)) {
      return true
    }
  }
  if (command.data && typeof command.data === 'string') {
    if (command.data.includes(query)) {
      return true
    }
  }
  if (command.info && Array.isArray(command.info)) {
    for (const entry of command.info) {
      if (typeof entry.data === 'string' && entry.data.includes(query)) {
        return true
      }
    }
  }
  if (command.error && Array.isArray(command.error)) {
    for (const entry of command.error) {
      if (typeof entry.data === 'string' && entry.data.includes(query)) {
        return true
      }
    }
  }
  return false
}

export function establishTrust(config) {
  const p4 = makeP4(config)
  const trustCmd = p4.cmdSync('trust -y -f')
  assert.include(trustCmd.data, 'Added trust for P4PORT')
}

export function establishSuper(config) {
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
  const seecurityCmd = p4.cmdSync('configure set security=3')
  assert.equal(seecurityCmd.stat[0].Action, 'set')
  const allowpasswdCmd = p4.cmdSync('configure set auth.sso.allow.passwd=1')
  assert.equal(allowpasswdCmd.stat[0].Action, 'set')
  const nonldapCmd = p4.cmdSync('configure set auth.sso.nonldap=1')
  assert.equal(nonldapCmd.stat[0].Action, 'set')
}

export function createUser(user, password, config) {
  const p4 = makeP4(config)
  const userIn = p4.cmdSync('user -i -f', user)
  assert.equal(userIn.info[0].data, `User ${user.User} saved.`)
  const passwdCmd = p4.cmdSync(`passwd ${user.User}`, `${password}\n${password}`)
  assert.equal(passwdCmd.info[0].data, 'Password updated.')
}

export function configureLdap(config) {
  const p4 = makeP4(config)
  const ldap = {
    Name: 'simple',
    Host: 'ldap.doc',
    Port: '389',
    Encryption: 'none',
    BindMethod: 'simple',
    Options: 'nodowncase nogetattrs norealminusername',
    SimplePattern: 'uid=%user%,ou=people,dc=example,dc=org',
    SearchScope: 'subtree',
    GroupSearchScope: 'subtree'
  }
  const ldapIn = p4.cmdSync('ldap -i', ldap)
  assert.equal(ldapIn.info[0].data, 'LDAP configuration simple saved.')
  const ldaporderCmd = p4.cmdSync('configure set auth.ldap.order.1=simple')
  assert.equal(ldaporderCmd.stat[0].Action, 'set')
}

export function createLdapUser(user, config) {
  const p4 = makeP4(config)
  const ldapUser = Object.assign({}, user, { AuthMethod: 'ldap' })
  const userIn = p4.cmdSync('user -i -f', ldapUser)
  assert.equal(userIn.info[0].data, `User ${user.User} saved.`)
}

export function createSvcUser(user, password, config) {
  const p4 = makeP4(config)
  const svcUser = Object.assign({}, user, { Type: 'service' })
  const userIn = p4.cmdSync('user -i -f', svcUser)
  assert.equal(userIn.info[0].data, `User ${user.User} saved.`)
  const passwdCmd = p4.cmdSync(`passwd ${user.User}`, `${password}\n${password}`)
  assert.equal(passwdCmd.info[0].data, 'Password updated.')
}

export function createGroup(group, config) {
  const p4 = makeP4(config)
  const groupOut = p4.cmdSync(`group -o ${group.Group}`)
  const input = Object.assign({}, groupOut.stat[0], group)
  delete input.code
  const groupIn = p4.cmdSync('group -i', input)
  assert.equal(groupIn.info[0].data, `Group ${group.Group} created.`)
}

function startService(env) {
  // must run the service in another process
  return fork('./test/www', [], { env, stdio: 'ignore' })
}

export function startNonSslService(port) {
  return startService({ PORT: port })
}

export function startSslService(port) {
  return startService({ PORT: port, USE_SSL: true })
}

export function installExtension(config) {
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
  assert.isTrue(findData(packageCmd, 'Extension packaged successfully.'))
  const installCmd = p4.cmdSync('extension --install loginhook.p4-extension -y --allow-unsigned')
  assert.include(installCmd.info[0].data, 'installed successfully')
}

export function configureExtension(config, protocol, serviceUrl) {
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
export function configureSsoUsers(config, protocol, serviceUrl) {
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
    'sso-users:\n\trepoman\n\tgeorge\n\tedgelord\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

// like configureExtension, but with only sso-groups defined
export function configureSsoGroups(config, protocol, serviceUrl) {
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

// like configureExtension, but with only client-sso-users defined
export function configureClientUsers(config, protocol, serviceUrl) {
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
    'non-sso-users:\n\tbruno\n' +
    'sso-groups:\n\t... ignore\n' +
    'sso-users:\n\t... ignore\n' +
    'client-name-identifier:\n\toid\n' +
    'client-user-identifier:\n\tfullname\n' +
    'client-sso-groups:\n\t... ignore\n' +
    'client-sso-users:\n\tclientman\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

// like configureExtension, but with only client-sso-groups defined
export function configureClientGroups(config, protocol, serviceUrl) {
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
    'non-sso-users:\n\tbruno\n' +
    'sso-groups:\n\t... ignore\n' +
    'sso-users:\n\t... ignore\n' +
    'client-name-identifier:\n\toid\n' +
    'client-user-identifier:\n\tfullname\n' +
    'client-sso-groups:\n\tclient_sso\n' +
    'client-sso-users:\n\t... ignore\n' +
    'user-identifier:\n\temail\n'
  const instanceIn = p4.cmdSync('extension --configure Auth::loginhook --name testing -i', instanceSpec)
  assert.equal(instanceIn.info[0].data, 'Extension config testing saved.')
}

export function restartServer(config) {
  return new Promise((resolve, reject) => {
    const p4 = makeP4(config)
    p4.cmdSync('admin restart')
    // give the server time to start up again
    setTimeout(resolve, 1000)
  })
}

const dataDirPath = ['server.extensions.dir', '117E9283-732B-45A6-9993-AE64C354F1C5', '1-data']

export function readExtensionLog(config) {
  const logPath = path.join(config.p4root, ...dataDirPath, 'log.json')
  return fs.readFileSync(logPath, 'utf8')
}
