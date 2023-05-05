//
// Copyright 2023 Perforce Software
//
import fs from 'fs-extra'
import * as path from 'node:path'
import * as process from 'node:process'
import { exec, spawn } from 'node:child_process'
import getPort from 'get-port'

const defaultConfig = {
  user: 'bruno',
  password: 'p8ssword',
  prog: 'p4api',
  progv: '2023.2.0',
  p4root: './tmp/p4d/nonssl'
}

const defaultSslConfig = {
  user: 'bruno',
  password: 'p8ssword',
  prog: 'p4api',
  progv: '2023.2.0',
  p4root: './tmp/p4d/ssl'
}

function startServerGeneric (config, ssldir) {
  return new Promise((resolve, reject) => {
    let env = process.env
    if (ssldir) {
      env = Object.assign({}, env, { P4SSLDIR: ssldir })
    }
    const args = [
      '-r', config.p4root,
      '-J', 'journal',
      '-L', 'log',
      '-p', config.port,
      '-d'
    ]
    const p4d = spawn('p4d', args, {
      detached: true,
      env
    })
    p4d.on('error', (err) => reject(err))
    p4d.stdout.on('data', (data) => {
      if (data.toString().includes('Perforce Server starting...')) {
        p4d.unref()
        // give the server a little more time before we try connecting,
        // otherwise random tests will intermittently fail on the first call
        setTimeout(() => resolve(config), 100)
      }
    })
    p4d.stderr.on('data', (data) => {
      console.error('p4d:', data.toString())
    })
  })
}

export async function startServer () {
  const portnum = await getPort()
  const port = `localhost:${portnum}`
  const config = Object.assign({}, defaultConfig, { port })
  // ensure an empty test directory exists
  fs.emptyDirSync(config.p4root)
  return startServerGeneric(config, null)
}

export async function startSslServer () {
  const portnum = await getPort()
  const port = `ssl:localhost:${portnum}`
  const config = Object.assign({}, defaultSslConfig, { port })
  // ensure an empty test directory exists
  fs.emptyDirSync(config.p4root)
  // set up everything for the SSL server
  const ssldir = path.join(config.p4root, 'ssl')
  fs.ensureDirSync(ssldir)
  fs.chmodSync(ssldir, 0o700)
  const certfile = path.join(ssldir, 'certificate.txt')
  fs.copyFileSync('test/fixtures/certificate.txt', certfile)
  fs.chmodSync(certfile, 0o600)
  const keyfile = path.join(ssldir, 'privatekey.txt')
  fs.copyFileSync('test/fixtures/privatekey.txt', keyfile)
  fs.chmodSync(keyfile, 0o600)
  // The value of P4SSLDIR needs to either be relative to the P4ROOT or an
  // absolute path; let's go with relative for the sake of simplicity.
  return startServerGeneric(config, path.basename(ssldir))
}

function stopServerGeneric (config) {
  return new Promise((resolve, reject) => {
    const cmd = [
      'p4',
      (config.port ? `-p ${config.port}` : ''),
      (config.user ? `-u ${config.user}` : ''),
      (config.password ? `-P ${config.password}` : ''),
      'admin',
      'stop'
    ]
    exec(cmd.join(' '), (err, stdout, stderr) => {
      if (err) {
        reject(err)
      } else {
        // was expecting output to contain "Perforce Server stopped..." but it
        // seems both stdout and stderr are empty
        resolve()
      }
    })
  })
}

export function stopServer (config) {
  return stopServerGeneric(config)
}
