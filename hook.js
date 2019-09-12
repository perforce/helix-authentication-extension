//
// Node.js script to build, install, and configure the server extension.
//
// Requirements:
//   * Node.js v10 or higher
//   * p4 client binary in the PATH
//   * P4 ticket with privileged access
//
// Example usage:
//   $ P4USER=bruno P4PORT=p4test:1666 node hook.js
//
// Note:
//   * This will overwrite any existing installation without confirmation.
//   * This will restart the Helix Server to enable the authentication changes.
//
// Settings are taken from environment variables, with defaults suitable for the
// development environment. See the "process.env" references below for the set of
// supported environment variables.
//
// If the extension has been installed previously, any settings that were defined
// earlier will be copied to the new installation. Settings that have been removed
// from newer versions of the extension may be silently dropped. Any settings that
// start with an ellipsis (...) may be overridden with new values or text.
//
const { exec, spawn } = require('child_process')
const fs = require('fs')

// The Perforce user installing and managing the extension. This is also used to
// set the ExtP4USER property in the global extension configuration, if the
// value has not been set previously. Additionally, if the non-sso-users field
// was not set previously in the named instance configuration, the user named
// here will be added to that list (that is, we assume this user does not
// authenticate using SSO, which is almost certainly the case).
const p4user = process.env.P4USER || 'super'

// Address of the Helix Server.
const p4port = process.env.P4PORT || 'localhost:1666'

// AUTH_PROTOCOL can be whatever the authentication service supports, such as
// "saml" or "oidc". If unset, the service will use its own default setting.
const protocol = process.env.AUTH_PROTOCOL

// Base URL for the authentication service by which the extension can reach the
// service to initiate login requests and retrieve user profiles.
const baseUrl = process.env.AUTH_URL || 'https://localhost:3000'

// Name for the extension instance configuration.
const confname = process.env.EXT_NAME || 'loginhook-all'

const p4cmd = `p4 -u ${p4user} -p ${p4port}`
const hookname = 'Auth::loginhook'
const hookpath = 'loginhook'
const filename = 'loginhook.p4-extension'

async function main () {
  try {
    // remove build artifacts and assemble the package
    if (fs.existsSync(filename)) {
      fs.unlinkSync(filename)
    }
    await makePackage()
    // collect the existing configuration, if any
    let oldGlobalConfig
    let oldInstanceConfig
    if (await isInstalled()) {
      oldGlobalConfig = await getGlobalConfig(true)
      oldInstanceConfig = await getInstanceConfig(true)
      await deleteExtension()
    }
    // install and configure the extension
    await installExtension()
    const newGlobalConfig = await getGlobalConfig()
    await setGlobalConfig(oldGlobalConfig, newGlobalConfig)
    const newInstanceConfig = await getInstanceConfig()
    await setInstanceConfig(oldInstanceConfig, newInstanceConfig)
    // restart p4d so the authentication changes take effect
    await restartServer()
  } catch (err) {
    console.error(err)
  }
}

main()

function makePackage () {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --package ${hookpath}`, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        console.info('Extension package built...')
        resolve()
      }
    })
  })
}

function isInstalled () {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --list --type=extensions`, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        resolve(stdout.includes(hookname))
      }
    })
  })
}

function getGlobalConfig (quiet) {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --configure ${hookname} -o`, (error, stdout, stderr) => {
      if (error) {
        if (quiet) {
          resolve(undefined)
        } else {
          reject(error)
        }
      } else {
        resolve(stdout)
      }
    })
  })
}

function getInstanceConfig (quiet) {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --configure ${hookname} -o --name ${confname}`, (error, stdout, stderr) => {
      if (error) {
        if (quiet) {
          resolve(undefined)
        } else {
          reject(error)
        }
      } else {
        resolve(stdout)
      }
    })
  })
}

function deleteExtension () {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --delete --yes ${hookname}`, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        console.info('Previously installed extension removed...')
        resolve()
      }
    })
  })
}

function installExtension () {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} extension --install ${filename} -y`, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        console.info('Newly built extension installed...')
        resolve()
      }
    })
  })
}

function setGlobalConfig (oldConfig, newConfig) {
  newConfig = setExtP4USER(oldConfig, newConfig)
  newConfig = setServiceURL(oldConfig, newConfig)
  newConfig = setAuthProtocol(oldConfig, newConfig)
  return new Promise((resolve, reject) => {
    const child = spawn('p4', [
      '-u', p4user,
      '-p', p4port,
      'extension',
      '--configure',
      hookname,
      '-i'
    ])
    child.stdout.on('data', (data) => {
      console.info(data.toString())
    })
    child.stderr.on('data', (data) => {
      console.error(`p4 stderr: ${data}`)
    })
    child.stdin.write(newConfig)
    child.stdin.end()
    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`child exited: ${code}`))
      } else {
        resolve()
      }
    })
  })
}

function setInstanceConfig (oldConfig, newConfig) {
  newConfig = setEnableLogging(oldConfig, newConfig)
  newConfig = setNameIdentifier(oldConfig, newConfig)
  newConfig = setNonSSOGroups(oldConfig, newConfig)
  newConfig = setNonSSOUsers(oldConfig, newConfig)
  newConfig = setUserIdentifier(oldConfig, newConfig)
  return new Promise((resolve, reject) => {
    const child = spawn('p4', [
      '-u', p4user,
      '-p', p4port,
      'extension',
      '--configure',
      hookname,
      '-i',
      '--name', confname
    ])
    child.stdout.on('data', (data) => {
      console.info(data.toString())
    })
    child.stderr.on('data', (data) => {
      console.error(`p4 stderr: ${data}`)
    })
    child.stdin.write(newConfig)
    child.stdin.end()
    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`child exited: ${code}`))
      } else {
        console.info('p4d restarted')
        resolve()
      }
    })
  })
}

function restartServer () {
  return new Promise((resolve, reject) => {
    exec(`${p4cmd} admin restart`, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        resolve()
      }
    })
  })
}

function setExtP4USER (oldConfig, newConfig) {
  let extUser = p4user
  if (oldConfig) {
    const match = oldConfig.match(/^ExtP4USER:\t(.*)$/m)
    if (match[1] !== 'sampleExtensionsUser') {
      extUser = match[1]
    }
  }
  return newConfig.replace(/^ExtP4USER:\t.*$/m, `ExtP4USER:\t${extUser}`)
}

function setAuthProtocol (oldConfig, newConfig) {
  let authProtocol = protocol
  if (oldConfig) {
    const match = oldConfig.match(/^\tAuth-Protocol:\n\t\t(.*)$/m)
    if (match[1] && match[1].slice(0, 3) !== '...') {
      authProtocol = match[1]
    }
  }
  if (authProtocol) {
    return newConfig.replace(/^\tAuth-Protocol:\n\t\t.*$/m, `\tAuth-Protocol:\n\t\t${authProtocol}`)
  }
  return newConfig
}

function setServiceURL (oldConfig, newConfig) {
  let serviceUrl = baseUrl
  if (oldConfig) {
    const match = oldConfig.match(/^\tService-URL:\n\t\t(.*)$/m)
    if (match[1] && match[1].slice(0, 3) !== '...') {
      serviceUrl = match[1]
    }
  }
  return newConfig.replace(/^\tService-URL:\n\t\t.*$/m, `\tService-URL:\n\t\t${serviceUrl}`)
}

function setEnableLogging (oldConfig, newConfig) {
  let enabled = 'true'
  if (oldConfig) {
    const match = oldConfig.match(/^\tenable-logging:\n\t\t(.*)$/m)
    if (match[1] && match[1].slice(0, 3) !== '...') {
      enabled = match[1]
    }
  }
  return newConfig.replace(/^\tenable-logging:\n\t\t.*$/m, `\tenable-logging:\n\t\t${enabled}`)
}

function setNameIdentifier (oldConfig, newConfig) {
  if (oldConfig) {
    const match = oldConfig.match(/^\tname-identifier:\n\t\t(.*)$/m)
    if (match[1] && match[1].slice(0, 3) !== '...') {
      return newConfig.replace(/^\tname-identifier:\n\t\t.*$/m, `\tname-identifier:\n\t\t${match[1]}`)
    }
  }
  return newConfig
}

function setUserIdentifier (oldConfig, newConfig) {
  if (oldConfig) {
    const match = oldConfig.match(/^\tuser-identifier:\n\t\t(.*)$/m)
    if (match[1] && match[1].slice(0, 3) !== '...') {
      return newConfig.replace(/^\tuser-identifier:\n\t\t.*$/m, `\tuser-identifier:\n\t\t${match[1]}`)
    }
  }
  return newConfig
}

function setNonSSOUsers (oldConfig, newConfig) {
  let users = `\t\t${p4user}`
  if (oldConfig) {
    const found = extractList(oldConfig, 'non-sso-users')
    if (found) {
      users = found
    }
  }
  return newConfig.replace(/^\tnon-sso-users:\n.*$/m, `\tnon-sso-users:\n${users}`)
}

function setNonSSOGroups (oldConfig, newConfig) {
  if (oldConfig) {
    const found = extractList(oldConfig, 'non-sso-groups')
    if (found) {
      return newConfig.replace(/^\tnon-sso-groups:\n.*$/m, `\tnon-sso-groups:\n${found}`)
    }
  }
  return newConfig
}

function extractList (spec, field) {
  const lines = spec.split('\n')
  const start = lines.findIndex((line) => {
    return line === `\t${field}:`
  })
  if (start) {
    const remainder = lines.slice(start + 1)
    const end = remainder.findIndex((line) => {
      return !line.startsWith('\t\t')
    })
    if (end) {
      const list = remainder.slice(0, end)
      return list.join('\n')
    }
  }
  return undefined
}
