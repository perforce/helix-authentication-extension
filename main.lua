-- Login hook prototype
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
    -- ["auth-pre-sso"] = "auth",
    ["command"] = "pre-user-login",
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
  c:close()
  return curlResponseFmt( url, ok, ok and cjson.decode( rsp ) or err )
end

function Command()
  utils.init()
  local message = utils.iCfgData[ "message" ]
  Perforce.SetClientMsg( message )
  return true
end

-- function AuthPreSSO()
--   utils.init()
--   local message = utils.iCfgData[ "message" ]
--   -- TODO: not SetClientMsg() but rather print to stdout
--   Perforce.SetClientMsg( message )
--   return true
-- end

function AuthCheckSSO()
  utils.init()
  Perforce.SetClientMsg( "using curl now..." )
  local ok, url, sdata = getData( utils.gCfgData[ "Service-URL" ] .. "/oidc/data" )
  Perforce.SetClientMsg( sdata[ "email" ] )
  return ok
end
