//
// Copyright 2020 Perforce Software
//
const http = require('http')
const app = require('../app')

const port = normalizePort(getPort())
app.set('port', port)

const server = http.createServer(app)
server.listen(port)
server.on('error', (error) => {
  if (error.syscall !== 'listen') {
    throw error
  }
  const bind = typeof port === 'string' ? 'Pipe ' + port : 'Port ' + port
  // handle specific listen errors with friendly messages
  switch (error.code) {
    case 'EACCES':
      console.error('%s requires elevated privileges', bind)
      process.exit(1)
    case 'EADDRINUSE':
      console.error('%s is already in use', bind)
      process.exit(1)
    default:
      throw error
  }
})
server.on('listening', () => {
  const addr = server.address()
  const bind = typeof addr === 'string'
    ? 'pipe ' + addr
    : 'port ' + addr.port
  console.debug('Listening on %s', bind)
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
