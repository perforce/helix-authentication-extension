--[[
  Authentication extensions for OpenID Connect and SAML 2.0

  Copyright 2020 Perforce Software
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
    [ "Auth-Protocol" ] = "... Authentication protocol, such as 'saml' or 'oidc'."
  }
end

function InstanceConfigFields()
  return {
    -- The leading ellipsis is used to indicate values that have not been
    -- changed from their default (documentation) values, since it is a wildcard
    -- in Perforce and cannot be used for anything else.
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
  c:setopt( curl.OPT_SSLCERT, Helix.Core.Server.GetArchDirFileName( "client.crt" ) )
  c:setopt( curl.OPT_SSLKEY, Helix.Core.Server.GetArchDirFileName( "client.key" ) )
  -- verification can be set to true only if the certs are not self-signed
  c:setopt_cainfo( Helix.Core.Server.GetArchDirFileName( "ca.crt" ) )
  c:setopt( curl.OPT_SSL_VERIFYPEER, false )
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
  curlSecureOptions( c )
  local ok, err = c:perform()
  local code = c:getinfo( curl.INFO_RESPONSE_CODE )
  c:close()
  if code == 200 then
    return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
  end
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
  curlSecureOptions( c )
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
  utils.init()
  local user = Helix.Core.Server.GetVar( "user" )
  -- skip any individually named users
  if utils.isSkipUser( user ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: skipping user " .. user } )
    return true, "unused", "http://example.com", true
  end
  -- skip any users belonging to a specific group
  local ok, inGroup = utils.isUserInSkipGroup( user )
  if not ok then
    Helix.Core.Server.SetClientMsg( utils.msgHeader() .. inGroup )
    return false, "error"
  end
  if inGroup then
    utils.debug( { [ "AuthPreSSO" ] = "info: group-based skipping user " .. user } )
    return true, "unused", "http://example.com", true
  end
  -- skip any users whose AuthMethod is set to ldap
  local ok, isLdap = utils.isUserLdap( user )
  if not ok then
    Helix.Core.Server.SetClientMsg( utils.msgHeader() .. isLdap )
    return false, "error"
  end
  if isLdap then
    utils.debug( { [ "AuthPreSSO" ] = "info: skipping LDAP user " .. user } )
    return true, "unused", "http://example.com", true
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
    return false
  end
  local url = utils.loginUrl( sdata )
  -- For now, use the old behavior for P4PHP/Swarm clients; N.B. when Swarm is
  -- logging the user into Perforce, the clientprog is P4PHP instead of SWARM.
  local clientprog = Helix.Core.Server.GetVar( "clientprog" )
  -- utils.debug( { [ "clientprog" ] = clientprog } )
  -- local clientversion = Helix.Core.Server.GetVar( "clientversion" )
  -- utils.debug( { [ "clientversion" ] = clientversion } )
  if string.find( clientprog, "P4PHP" ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: legacy mode for P4PHP client" } )
    return true, url
  end
  -- if old SAML integration setting is present, use old behavior
  local ssoArgs = Helix.Core.Server.GetVar( "ssoArgs" )
  if string.find( ssoArgs, "--idpUrl" ) then
    utils.debug( { [ "AuthPreSSO" ] = "info: legacy mode for desktop agent" } )
    return true, url
  end
  utils.debug( { [ "AuthPreSSO" ] = "info: invoking URL " .. url } )
  return true, "unused", url, false
end

local function compareIdentifiers( userid, nameid )
  if nameid == nil then
    utils.debug( {
      [ "AuthCheckSSO" ] = "error: nameid is nil",
      [ "userid" ] = userid
    } )
    return false
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
  local userid = utils.userIdentifier()
  -- When using the invoke-URL feature, the client never passes anything back,
  -- so in that case, the "token" in AuthCheckSSO is set to the username.
  local user = Helix.Core.Server.GetVar( "user" )
  local token = Helix.Core.Server.GetVar( "token" )
  utils.debug( { [ "AuthCheckSSO" ] = "info: checking user " .. user } )
  if user ~= token then
    utils.debug( { [ "AuthCheckSSO" ] = "info: legacy mode login for user " .. user } )
    -- If a password/token has been provided, then perhaps this is the legacy
    -- support scenario, and the token is the SAML response coming from the
    -- desktop agent or Swarm. In that case, try to extract the response and
    -- send it to the service for validation. If that works, we're done,
    -- otherwise fall back to the normal behavior.
    local response = utils.getResponse( token )
    if response then
      -- send SAML response to auth service for validation
      local ok, url, sdata = validateResponse( utils.validateUrl(), response )
      if ok then
        utils.debug( { [ "AuthCheckSSO" ] = "info: legacy mode user data", [ "sdata" ] = sdata } )
        local nameid = utils.nameIdentifier( sdata )
        return compareIdentifiers( userid, nameid )
      end
      utils.debug( {
        [ "AuthCheckSSO" ] = "error: legacy mode validation failed for user " .. user,
        [ "http-code" ] = url,
        [ "http-error" ] = tostring( sdata )
      } )
    end
  end
  -- Commence so-called normal behavior, in which we request the authenticated
  -- user data using a long-poll on the auth service. The service request will
  -- time out if the user does not authenticate with the IdP in a timely manner.
  local ok, url, sdata = getData( utils.statusUrl() .. requestId )
  if ok then
    utils.debug( { [ "AuthCheckSSO" ] = "info: received user data", [ "sdata" ] = sdata } )
    local nameid = utils.nameIdentifier( sdata )
    return compareIdentifiers( userid, nameid )
  end
  utils.debug( {
    [ "AuthCheckSSO" ] = "error: auth validation failed for user " .. user,
    [ "http-code" ] = url,
    [ "http-error" ] = tostring( sdata )
  } )
  return false
end
