--[[
  Authentication extensions for OpenID Connect and SAML 2.0

  Copyright 2021 Perforce Software
]]--
local cjson = require "cjson"
local curl = require "cURL.safe"
package.path = Helix.Core.Server.GetArchDirFileName( "?.lua" )
local utils = require "ExtUtils"

function GlobalConfigFields()
  return {
    -- The leading ellipsis is used to indicate values that have not been
    -- changed from their default (documentation) values, since it is a wildcard
    -- in Perforce and cannot be used for anything else.
    [ "Service-URL" ] = "... The authentication service base URL.",
    [ "Auth-Protocol" ] = "... Authentication protocol, such as 'saml' or 'oidc'.",
    [ "Client-Cert" ] = "... Path to client public key, defaults to ./client.crt",
    [ "Client-Key" ] = "... Path to client private key, defaults to ./client.key",
    [ "Authority-Cert" ] = "... Path to certificate authority public key, defaults to ./ca.crt"
  }
end

function InstanceConfigFields()
  return {
    -- The leading ellipsis is used to indicate values that have not been
    -- changed from their default (documentation) values, since it is a wildcard
    -- in Perforce and cannot be used for anything else.
    [ "sso-users" ] = "... Those users who must authenticate using SSO.",
    [ "sso-groups" ] = "... Those groups whose members must authenticate using SSO.",
    [ "non-sso-users" ] = "... Those users who will not be using SSO.",
    [ "non-sso-groups" ] = "... Those groups whose members will not be using SSO.",
    [ "user-identifier" ] = "... Trigger variable used as unique user identifier.",
    [ "name-identifier" ] = "... Field within IdP response containing unique user identifer.",
    [ "enable-logging" ] = "... Extension will write debug messages to a log if 'true'."
  }
end

function InstanceConfigEvents()
  return {
    [ "auth-pre-sso" ] = "auth",
    [ "auth-check-sso" ] = "auth"
  }
end

-- Set the SSL related options on the curl instance.
local function curlSecureOptions( c )
  c:setopt_useragent( utils.getID() )
  c:setopt( curl.OPT_USE_SSL, true )
  c:setopt( curl.OPT_SSLCERT, utils.clientCertificate() )
  c:setopt( curl.OPT_SSLKEY, utils.clientKey() )
  -- Use a specific certificate authority rather than the default bundle because
  -- we ship with self-signed certificates.
  c:setopt_cainfo( utils.authorityCertificate() )
  -- Ensure the server certificate is valid by checking certificate authority;
  -- verification can be set to true only if the certs are not self-signed.
  c:setopt( curl.OPT_SSL_VERIFYPEER, false )
  -- Ensure host name matches common name in server certificate.
  c:setopt( curl.OPT_SSL_VERIFYHOST, false )
end

local function curlResponseFmt( url, ok, data )
  local msg = "Error getting data from auth service (" .. url .. "):  "
  if not ok then
    return false, url, msg .. tostring( data )
  end
  if data[ "error" ] ~= nil then
    return false, url, msg .. data[ "error" ]
  end
  return true, url, data
end

-- Connect to auth service and convert the JSON response to a table.
local function getData( url )
  --[[
    Lua-cURLv3: https://github.com/Lua-cURL/Lua-cURLv3
    See the API docs for lcurl (http://lua-curl.github.io/lcurl/modules/lcurl.html)
    as that describes much more of the functionality than the Lua-cURLv3 API docs.
    See https://github.com/Lua-cURL/Lua-cURLv3/blob/master/src/lcopteasy.h for all options.
  ]]--
  local c = curl.easy()
  local rsp = ""
  c:setopt( curl.OPT_URL, url )
  -- Store all the data in memory in the 'rsp' variable.
  c:setopt( curl.OPT_WRITEFUNCTION, function( chunk ) rsp = rsp .. chunk end )
  if utils.shouldUseSsl( url ) then
    curlSecureOptions( c )
  end
  utils.debug( { [ "getData" ] = "info: fetching " .. url } )
  local ok, err = c:perform()
  local code = c:getinfo( curl.INFO_RESPONSE_CODE )
  c:close()
  if code == 200 then
    return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
  end
  utils.debug( { [ "getData" ] = "error: HTTP response: " .. tostring( rsp ) } )
  return false, code, err
end

local function validateResponse( url, response )
  local easy = curl.easy()
  local encoded_response = easy:escape( response )
  local c = curl.easy{
    url        = url,
    post       = true,
    httpheader = {
      "Content-Type: application/x-www-form-urlencoded",
    },
    postfields = "SAMLResponse=" .. encoded_response,
  }
  c:setopt_useragent( utils.getID() )
  local rsp = ""
  c:setopt( curl.OPT_WRITEFUNCTION, function( chunk ) rsp = rsp .. chunk end )
  if utils.shouldUseSsl( url ) then
    curlSecureOptions( c )
  end
  local ok, err = c:perform()
  local code = c:getinfo( curl.INFO_RESPONSE_CODE )
  c:close()
  if code == 200 then
    return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
  end
  return false, code, err
end

--[[
  An Extension once loaded, has its runtime persist for the life of the
  RhExtension instance. This means that if you have some variable declared
  outside of your callbacks, that it will be around next time a callback
  is invoked.
]]--
local requestId = nil

function AuthPreSSO()
  -- N.B. auth-pre-sso does not emit messages to the client so calling
  -- Helix.Core.Server.SetClientMsg() does nothing.
  utils.init()
  local user = Helix.Core.Server.GetVar( "user" )
  local ok, isRequired, hasRequired = utils.isRequiredUser( user )
  if not ok then
    return false, "error"
  end
  if hasRequired and not isRequired then
    -- required list exists and this user is not in it, no SSO
    utils.debug( {
      [ "AuthPreSSO" ] = "info: skipping user, SSO not required",
      [ "user" ] = user
    } )
    return true, "unused", "http://example.com", true
  elseif not hasRequired then
    -- without required list, consider skipped list and other special cases
    local ok, isSkipped, _hasSkipped = utils.isSkipUser( user )
    if not ok then
      return false, "error"
    end
    if isSkipped then
      utils.debug( {
        [ "AuthPreSSO" ] = "info: skipping SSO for user",
        [ "user" ] = user
      } )
      return true, "unused", "http://example.com", true
    end
    local ok, authMethod, userType = utils.getAuthMethodAndType( user )
    if not ok then
      return false, "error"
    end
    -- non-'standard' users typically cannot use browser-based auth
    if userType ~= "standard" then
      utils.debug( {
        [ "AuthPreSSO" ] = "info: skipping non-standard user ",
        [ "user" ] = user
      } )
      return true, "unused", "http://example.com", true
    end
    -- LDAP users are expected to authenticate using LDAP
    if authMethod == "ldap" then
      utils.debug( {
        [ "AuthPreSSO" ] = "info: skipping LDAP user ",
        [ "user" ] = user
      } )
      return true, "unused", "http://example.com", true
    end
  end
  -- Get a request id from the service, save it in requestId; do this every time
  -- for every user, in case the same user logs in from multiple systems. We
  -- will use this request identifier to get the status of the user later.
  local userid = utils.userIdentifier()
  local easy = curl.easy()
  local safe_id = easy:escape( userid )
  local ok, url, sdata = getData( utils.requestUrl() .. safe_id )
  if ok then
    requestId = sdata[ "request" ]
  else
    utils.debug( {
      [ "AuthPreSSO" ] = "error: failed to get request identifier",
      [ "http-code" ] = url,
      [ "http-error" ] = tostring( sdata )
    } )
    utils.debug( {
      [ "AuthPreSSO" ] = "info: ensure Service-URL is valid",
      [ "Service-URL" ] = utils.gCfgData[ "Service-URL" ]
    } )
    return false, "error"
  end
  local url = utils.loginUrl( sdata )
  -- For now, use the 1-step procedure for P4PHP clients; N.B. when Swarm is
  -- logging the user into Perforce, the clientprog is P4PHP instead of SWARM.
  local clientprog = Helix.Core.Server.GetVar( "clientprog" )
  if string.find( clientprog, "P4PHP" ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: 1-step mode for P4PHP client" } )
    return true, url
  end
  -- For Helix TeamHub, use the 1-step login procedure.
  if string.find( clientprog, "PilsnerHTHAdapter" ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: 1-step mode for PilsnerHTHAdapter client" } )
    return true, url
  end
  -- If the old SAML integration setting is present, use 1-step procedure.
  local ssoArgs = Helix.Core.Server.GetVar( "ssoArgs" )
  if string.find( ssoArgs, "--idpUrl" ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: 1-step mode for desktop agent" } )
    return true, url
  end
  utils.debug( {
    [ "AuthPreSSO" ] = "info: invoking URL " .. url,
    [ "user" ] = user
  } )
  return true, "unused", url, false
end

local function compareIdentifiers( userid, nameid )
  if nameid == nil then
    utils.debug( {
      [ "AuthCheckSSO" ] = "error: nameid is nil",
      [ "userid" ] = userid
    } )
    return false, "error"
  end
  utils.debug( {
    [ "AuthCheckSSO" ] = "info: comparing user identifiers",
    [ "userid" ] = userid,
    [ "nameid" ] = nameid
  } )
  -- Compare the identifiers case-insensitively for now; if this proves to be a
  -- problem, the sensitivity could be made configurable (e.g. use the server
  -- sensitivity setting).
  local ok = (userid:lower() == nameid:lower())
  if ok then
      utils.debug( { [ "AuthCheckSSO" ] = "info: identifiers match" } )
    else
      utils.debug( {
        [ "AuthCheckSSO" ] = "error: identifiers do not match",
        [ "userid" ] = userid,
        [ "nameid" ] = nameid
      } )
  end
  return ok
end

function AuthCheckSSO()
  utils.init()
  -- Cannot check in auth-pre-sso as p4v does not receive/capture/report the
  -- client messages sent from that trigger hook.
  if utils.isOlderP4V() then
    Helix.Core.Server.SetClientMsg( 'please upgrade P4V for login2 support' )
    return false
  end
  local userid = utils.userIdentifier()
  -- When using the invoke-URL feature, the client never passes anything back,
  -- so in that case, the "token" in AuthCheckSSO is set to the username.
  local user = Helix.Core.Server.GetVar( "user" )
  local token = Helix.Core.Server.GetVar( "token" )
  utils.debug( {
    [ "AuthCheckSSO" ] = "info: checking user",
    [ "user" ] = user
  } )
  if user ~= token then
    utils.debug( {
      [ "AuthCheckSSO" ] = "info: 1-step mode login",
      [ "user" ] = user
    } )
    -- If a password/token has been provided, then this is the 1-step procedure,
    -- and the token is the SAML response coming from the desktop agent or
    -- Swarm. In that case, try to extract the response and send it to the
    -- service for validation. If that does not work, fall back to the normal
    -- behavior.
    local response = utils.getResponse( token )
    if response then
      local ok, url, sdata = validateResponse( utils.validateUrl(), response )
      if ok then
        utils.debug( {
          [ "AuthCheckSSO" ] = "info: 1-step mode user data",
          [ "user" ] = user,
          [ "sdata" ] = sdata
        } )
        local nameid = utils.nameIdentifier( sdata )
        return compareIdentifiers( userid, nameid )
      end
      utils.debug( {
        [ "AuthCheckSSO" ] = "error: 1-step mode validation failed",
        [ "user" ] = user,
        [ "http-code" ] = url,
        [ "http-error" ] = tostring( sdata )
      } )
    end
    -- Do not fall through even though that may be an acceptable solution, it
    -- hides the fact that something is wrong with the Swarm setup and results
    -- in intermittent login failures.
    return false
  end
  -- Commence the usual 2-step procedure, in which we request the authenticated
  -- user data using a long-poll on the auth service. The service request will
  -- time out if the user does not authenticate with the IdP in a timely manner.
  local ok, url, sdata = getData( utils.statusUrl() .. requestId )
  if ok then
    utils.debug( {
      [ "AuthCheckSSO" ] = "info: received user data",
      [ "user" ] = user,
      [ "sdata" ] = sdata
    } )
    local nameid = utils.nameIdentifier( sdata )
    return compareIdentifiers( userid, nameid )
  end
  utils.debug( {
    [ "AuthCheckSSO" ] = "error: auth validation failed",
    [ "user" ] = user,
    [ "http-code" ] = url,
    [ "http-error" ] = tostring( sdata )
  } )
  Helix.Core.Server.SetClientMsg( 'check the loginhook extension logs' )
  return false
end
