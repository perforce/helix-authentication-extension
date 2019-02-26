--[[
  Authentication extensions for OpenID Connect and SAML 2.0

  Copyright 2019 Perforce Software
]]--
local cjson = require "cjson"
local curl = require "cURL.safe"
package.path = Perforce.GetArchDirFileName( "?.lua" )
local utils = require "ExtUtils"

function GetExtGConfigFields()
  return {
    [ "Service-URL" ] = "The authentication service base URL.",
    [ "Auth-Protocol" ] = "Authentication protocol, such as saml or oidc."
  }
end

function GetExtConfigFields()
  return {
    [ "non-sso-users" ] = "Those users who will not be using SSO."
  }
end

function GetExtConfigHooks()
  return {
    [ "auth-pre-sso" ] = "auth",
    [ "auth-check-sso" ] = "auth"
  }
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

-- Connect to a auth service and convert the JSON response to a table.
local function getData( url )
  --[[
    Lua-cURLv3: https://github.com/Lua-cURL/Lua-cURLv3
    See the API docs for lcurl (http://lua-curl.github.io/lcurl/modules/lcurl.html)
    as that describes much more of the functionality than the Lua-cURLv3 API docs.
  ]]--
  local c = curl.easy()
  local rsp = ""
  c:setopt( curl.OPT_URL, url )
  -- Store all the data in memory in the 'rsp' variable.
  c:setopt( curl.OPT_WRITEFUNCTION, function( chunk ) rsp = rsp .. chunk end )
  -- https://curl.haxx.se/docs/caextract.html
  -- c:setopt_cainfo( Perforce.GetArchDirFileName( "cacert.pem" ) )
  c:setopt_useragent( utils.getID() )
  -- verification can be set to true only if the certs are not self-signed
  c:setopt( curl.OPT_SSL_VERIFYPEER, false )
  c:setopt( curl.OPT_SSL_VERIFYHOST, false )
  local ok, err = c:perform()
  local code = c:getinfo( curl.INFO_RESPONSE_CODE )
  c:close()
  if code == 200 then
    return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
  end
  return false, code, err
end

function AuthPreSSO()
  utils.init()
  local user = Perforce.GetTrigVar( "user" )
  if utils.isSkipUser( user ) then
    return true, "unused", "http://example.com", true
  end
  local url = utils.loginUrl()
  return true, "unused", url, false
end

function AuthCheckSSO()
  utils.init()
  local email = Perforce.GetTrigVar( "email" )
  local easy = curl.easy()
  local safe_email = easy:escape( email )
  -- use a long-poll request that will eventually timeout
  local ok, url, sdata = getData( utils.dataUrl() .. safe_email )
  if ok then
    return email == sdata[ "email" ]
  end
  return false
end
