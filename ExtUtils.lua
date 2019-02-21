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

function ExtUtils.splitLines( str )
  lines = {}
  for s in str:gmatch( "%S+" ) do
      table.insert( lines, s )
  end
  return lines
end

function ExtUtils.sleep( s )
  local ntime = os.time() + s
  repeat until os.time() > ntime
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

function ExtUtils.dataUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  local method = ExtUtils.gCfgData[ "Auth-Protocol" ]
  return base .. "/" .. method .. "/data/"
end

function ExtUtils.isSkipUser( user )
  local items = ExtUtils.splitLines( ExtUtils.iCfgData[ "non-sso-users" ] )
  for _, v in pairs(items) do
    if v == user then
      return true
    end
  end
  return false
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
