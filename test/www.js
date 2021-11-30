//
// Copyright 2020-2021 Perforce Software
//
import * as fs from 'node:fs'
import * as http from 'node:http'
import * as https from 'node:https'
import app from 'helix-auth-extension/test/app.js'

const port = normalizePort(getPort())
app.set('port', port)

const server = createServer(app)
server.listen(port)
server.on('error', (err) => {
  console.error(`error: ${err}`)
  process.exit(1)
})

function getPort () {
  if (process.env.PORT) {
    return process.env.PORT
  }
  return '3300'
}

function normalizePort (val) {
  const port = parseInt(val, 10)
  if (isNaN(port)) {
    return val
  }
  if (port >= 0) {
    return port
  }
  return false
}

function createServer (app) {
  if (process.env.USE_SSL) {
    const options = {
      key: fs.readFileSync('test/fixtures/server.key'),
      cert: fs.readFileSync('test/fixtures/server.crt'),
      requestCert: true,
      rejectUnauthorized: false,
      ca: fs.readFileSync('test/fixtures/ca.crt')
    }
    return https.createServer(options, app)
  } else {
    return http.createServer(app)
  }
}
