//
// Copyright 2020-2021 Perforce Software
//
const createError = require('http-errors')
const express = require('express')

//
// This very basic Express.js application is used for testing the login
// extension. It establishes a set of routes for testing various success and
// failure cases. By configuring the extension with different base URLs we can
// test the behavior of the extension when the service responds with different
// content or HTTP response codes.
//
const app = express()
app.use(express.json())
app.use(express.urlencoded({ extended: false }))

//
// set up routes for all of the test scenarios
//
const router = express.Router()

// mixed letter-case in user identifier
router.get('/pass/case/requests/new/:userId', newRequest)
router.get('/pass/case/requests/status/:requestId', mixedCaseProfile)

// basic OpenID Connect success
router.get('/pass/oidc/requests/new/:userId', newRequest)
router.get('/pass/oidc/requests/status/:requestId', oidcProfile)

// basic SAML 2.0 success
router.get('/pass/saml/requests/new/:userId', newRequest)
router.get('/pass/saml/requests/status/:requestId', samlProfile)

// request status results in a 401
router.get('/fail/401/requests/new/:userId', newRequest)
router.get('/fail/401/requests/status/:requestId', fail401)

// request status results in a 403
router.get('/fail/403/requests/new/:userId', newRequest)
router.get('/fail/403/requests/status/:requestId', fail403)

// request status results in a 408
router.get('/fail/408/requests/new/:userId', newRequest)
router.get('/fail/408/requests/status/:requestId', fail408)

// server error starting a new login request
router.get('/fail/start/requests/new/:userId', serverError)
router.get('/fail/start/requests/status/:requestId', serverError)

// the wrong user logged in to the identity provider
router.get('/fail/mismatch/requests/new/:userId', newRequest)
router.get('/fail/mismatch/requests/status/:requestId', wrongProfile)
app.use('/', router)

// catch 404 and forward to error handler
app.use((req, res, next) => {
  next(createError(404))
})

// error handler
app.use((err, req, res, next) => {
  // set locals, only providing error in development
  res.locals.message = err.message
  res.locals.error = req.app.get('env') === 'development' ? err : {}

  // render the error page
  res.status(err.status || 500)
  console.error(err.message)
  res.send('server error')
})

function newRequest (req, res, next) {
  const port = app.get('port')
  const requestId = 'greenthursday'
  const baseUrl = `http://localhost:${port}`
  const loginUrl = `${baseUrl}/saml/login/${requestId}`
  res.json({
    request: requestId,
    loginUrl,
    baseUrl
  })
}

function oidcProfile (req, res, next) {
  if (req.protocol === 'https') {
    // perform a basic sanity check of the client certs, just to assert that the
    // extension sent certificates to the service, unlike the non-ssl case
    const cert = getClientCert(req)
    if (!isClientAuthorized(req, cert)) {
      if (cert && cert.subject) {
        const msg = `certificates for ${cert.subject.CN} from ${cert.issuer.CN} are not permitted`
        res.status(403).send(msg)
      } else {
        res.status(401).send('client certificate required')
      }
    }
  }
  res.json({
    sub: '00u15xtrad5QDzt1D357',
    name: 'Repo Man',
    locale: 'en-US',
    email: 'repoman@example.com',
    preferred_username: 'repoman',
    given_name: 'Repo',
    family_name: 'Man',
    zoneinfo: 'America/Los_Angeles',
    updated_at: 1566419389,
    email_verified: true
  })
}

function samlProfile (req, res, next) {
  res.json({
    nameID: 'repoman@example.com',
    nameIDFormat: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    sessionIndex: '_443f9b1c4627383b0e42'
  })
}

// user identifier letter-case differs perforce user spec
function mixedCaseProfile (req, res, next) {
  res.json({
    nameID: 'rEpOmAn@example.com',
    nameIDFormat: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    sessionIndex: '_443f9b1c4627383b0e42'
  })
}

function fail401 (req, res, next) {
  res.status(401).send('client certificate required')
}

function fail403 (req, res, next) {
  res.status(403).send('unacceptable client certificates')
}

function fail408 (req, res, next) {
  res.status(408).send('Request Timeout')
}

function serverError (req, res, next) {
  res.status(500).send('Server Error')
}

function wrongProfile (req, res, next) {
  res.json({
    nameID: 'someone.else@example.com',
    nameIDFormat: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    sessionIndex: '_443f9b1c4627383b0e42'
  })
}

function getClientCert (req) {
  if (req.protocol === 'https' && req.connection.getPeerCertificate) {
    return req.connection.getPeerCertificate()
  }
  return null
}

function isClientAuthorized (req, cert) {
  if (req.protocol === 'https' && cert) {
    return req.client.authorized
  } else if (req.protocol === 'http') {
    return true
  }
}

module.exports = app
