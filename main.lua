--[[
  Authentication extensions for OpenID Connect and SAML 2.0

  Copyright 2019 Perforce Software
]]--
local cjson = require "cjson"
local curl = require "cURL.safe"
package.path = Perforce.GetArchDirFileName( "?.lua" )
local utils = require "ExtUtils"

function GlobalConfigFields()
  return {
    -- The leading ellipsis is used to indicate values that have not been
    -- changed from their default (documentation) values, since it is a wildcard
    -- in Perforce and cannot be used for anything else.
    [ "Service-URL" ] = "... The authentication service base URL.",
    [ "Auth-Protocol" ] = "... Authentication protocol, such as saml or oidc."
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
  c:setopt( curl.OPT_SSLCERT, Perforce.GetArchDirFileName( "client.crt" ) )
  c:setopt( curl.OPT_SSLKEY, Perforce.GetArchDirFileName( "client.key" ) )
  -- verification can be set to true only if the certs are not self-signed
  c:setopt_cainfo( Perforce.GetArchDirFileName( "cacert.pem" ) )
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
    See https://github.com/Lua-cURL/Lua-cURLv3/src/lcopteasy.h for all options.
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
  local user = Perforce.GetVar( "user" )
  -- skip any individually named users
  if utils.isSkipUser( user ) then
    utils.debug( { [ "AuthPreSSO" ] = "skipping user " .. user } )
    return true, "unused", "http://example.com", true
  end
  -- skip any users belonging to a specific group
  local err, inGroup = utils.isUserInSkipGroup( user )
  if err then
    Perforce.SetClientMsg( utils.msgHeader() .. err )
    return false, "error"
  end
  if inGroup then
    utils.debug( { [ "AuthPreSSO" ] = "group-based skipping user " .. user } )
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
    utils.debug( { [ "AuthPreSSO" ] = "failed to get request identifier" } )
    return false
  end
  local url = utils.loginUrl() .. requestId
  -- For now, use the old behavior for P4PHP/Swarm clients; N.B. when Swarm is
  -- logging the user into Perforce, the clientprog is P4PHP instead of SWARM.
  local clientprog = Perforce.GetVar( "clientprog" )
  if string.find( clientprog, "P4PHP" ) then
    utils.debug( { [ "AuthPreSSO" ] = "legacy mode for P4PHP client" } )
    return true, url
  end
  -- if old SAML integration setting is present, use old behavior
  local ssoArgs = Perforce.GetVar( "ssoArgs" )
  if string.find( ssoArgs, "--idpUrl" ) then
    utils.debug( { [ "AuthPreSSO" ] = "legacy mode for desktop agent" } )
    return true, url
  end
  utils.debug( { [ "AuthPreSSO" ] = "invoking URL " .. url } )
  return true, "unused", url, false
end

function AuthCheckSSO()
  utils.init()
  local userid = utils.userIdentifier()
  -- When using the invoke-URL feature, the client never passes anything back,
  -- so in that case, the "token" in AuthCheckSSO is set to the username.
  local user = Perforce.GetVar( "user" )
  local token = Perforce.GetVar( "token" )
  utils.debug( { [ "AuthCheckSSO" ] = "checking user " .. user } )
  if user ~= token then
    utils.debug( { [ "AuthCheckSSO" ] = "legacy mode login for user " .. user } )
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
        utils.debug( { [ "AuthCheckSSO" ] = "legacy mode user data", [ "sdata" ] = sdata } )
        return userid == utils.nameIdentifier( sdata )
      end
      utils.debug( { [ "AuthCheckSSO" ] = "legacy mode validation failed for user " .. user } )
    end
  end
  -- Commence so-called normal behavior, in which we request the authenticated
  -- user data using a long-poll on the auth service. The service request will
  -- time out if the user does not authenticate with the IdP in a timely manner.
  local ok, url, sdata = getData( utils.statusUrl() .. requestId )
  if ok then
    utils.debug( { [ "AuthCheckSSO" ] = "received user data", [ "sdata" ] = sdata } )
    return userid == utils.nameIdentifier( sdata )
  end
  utils.debug( { [ "AuthCheckSSO" ] = "auth validation failed for user " .. user } )
  return false
end
