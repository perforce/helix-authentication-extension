--[[
  Copyright 2019 Perforce Software
]]--
local ExtUtils = {}
local cjson = require "cjson"

function getManifest()
  local fn = Perforce.GetArchDirFileName( "manifest.json" )
  local fh = assert( io.open( fn, "r" ) )
  local m = cjson.decode( fh:read( "*all" ) )
  fh:close()
  return m
end

function trim( s )
   return ( s:gsub( "^%s*(.-)%s*$", "%1" ) )
end

function getGCfg()
  local cfg = {}
  for k, v in pairs( Perforce.GetGConfigData() ) do
    cfg[ k ] = trim( v )
  end
  return cfg
end

function getICfg()
  local cfg = {}
  for k, v in pairs( Perforce.GetIConfigData() ) do
    if string.len( v ) > 0 then
      cfg[ k ] = trim( v )
    end
  end
  return cfg
end

function ExtUtils.splitWords( str )
  lines = {}
  for s in str:gmatch( "%S+" ) do
      table.insert( lines, s )
  end
  return lines
end

function ExtUtils.getID()
  return ExtUtils.manifest[ "name" ] .. "/" .. ExtUtils.manifest[ "key" ] .. "/" ..
         ExtUtils.manifest[ "version_name" ]
end

function ExtUtils.msgHeader()
  return ExtUtils.getID() .. ":  "
end

function ExtUtils.loginUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  local method = ExtUtils.gCfgData[ "Auth-Protocol" ]
  return base .. "/" .. method .. "/login"
end

function ExtUtils.requestUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  return base .. "/requests/new/"
end

function ExtUtils.statusUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  return base .. "/requests/status/"
end

function ExtUtils.validateUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  return base .. "/saml/validate"
end

function ExtUtils.isSkipUser( user )
  local items = ExtUtils.splitWords( ExtUtils.iCfgData[ "non-sso-users" ] )
  for _, v in pairs( items ) do
    if v == user then
      return true
    end
  end
  return false
end

function ExtUtils.isLegacy( ssoArgs )
  return string.find( ssoArgs, "--idpUrl" )
end

-- Extract SAML response from the given string (presumably from the desktop
-- agent), returning just the base64-encoded response value.
function ExtUtils.getResponse( str )
  for line in string.gmatch(str, "[^\r\n]+") do
    if string.sub( line, 1, 14 ) == "saml-response:" then
      return trim( string.sub( line, 15, #line ) )
    end
  end
  return nil
end

ExtUtils.manifest = {}
ExtUtils.gCfgData = {}
ExtUtils.iCfgData = {}

function ExtUtils.init()
  if ExtUtils.gCfgData[ "Service-URL" ] == nil then
    ExtUtils.gCfgData = getGCfg()
  end
  if ExtUtils.iCfgData[ "non-sso-users" ] == nil then
    ExtUtils.iCfgData = getICfg()
  end
  if ExtUtils.manifest[ "key" ] == nil then
    ExtUtils.manifest = getManifest()
  end
end

return ExtUtils
