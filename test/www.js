//
// Copyright 2020 Perforce Software
//
const http = require('http')
const app = require('./app')

//
// Spawned via child_process.fork() and output is hidden. Note that it seems to
// be spawned twice, once with the desired environment and another time with the
// parent's environment. That process's output is not hidden, so to avoid
// cluttering the test output, this module prints nothing at all.
//

const port = normalizePort(getPort())
app.set('port', port)

const server = http.createServer(app)
server.listen(port)
server.on('error', (_err) => {
  process.exit(1)
})

function getPort () {
  if (process.env.PORT) {
    return process.env.PORT
  }
  return '3000'
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
