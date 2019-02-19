--[[
  Authentication extensions for OpenID Connect
]]--
local cjson = require "cjson"
local curl = require "cURL.safe"
package.path = Perforce.GetArchDirFileName( "?.lua" )
local utils = require "ExtUtils"

function GetExtGConfigFields()
  return {
    ["Service-URL"] = "http://localhost:3000"
  }
end

function GetExtConfigFields()
  return {
    message = "The message displayed before login."
  }
end

function GetExtConfigHooks()
  return {
    ["auth-pre-sso"] = "auth",
    ["auth-check-sso"] = "auth"
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
  -- c:setopt( curl.OPT_SSL_VERIFYPEER, true );
  -- c:setopt( curl.OPT_SSL_VERIFYHOST, true );
  local ok, err = c:perform()
  local code = c:getinfo(curl.INFO_RESPONSE_CODE)
  c:close()
  if code == 200 then
    return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
  end
  return false, code, err
end

function AuthPreSSO()
  utils.init()
  local user = Perforce.GetTrigVar( "user" )
  if user == "super" then
    return true, "unused", "http://example.com", true
  end
  local url = utils.gCfgData[ "Service-URL" ] .. "/oidc/login"
  return true, "unused", url, false
end

function AuthCheckSSO()
  utils.init()
  local email = Perforce.GetTrigVar( "email" )
  local easy = curl.easy()
  local safe_email = easy:escape( email )
  local retries = 0
  repeat
    local ok, url, sdata = getData( utils.gCfgData[ "Service-URL" ] .. "/oidc/data/" .. safe_email )
    if ok then
      return email == sdata[ "email" ]
    end
    -- retry the request for up to a minute (20 * 3 = 60)
    retries = retries + 1
    utils.sleep( 3 )
  until retries > 20
  return false
end
