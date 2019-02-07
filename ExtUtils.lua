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

function ExtUtils.getID()
  return ExtUtils.manifest[ "name" ] .. "/" .. ExtUtils.manifest[ "key" ] .. "/" ..
         ExtUtils.manifest[ "version_name" ]
end

function ExtUtils.msgHeader()
  return ExtUtils.getID() .. ":  "
end

ExtUtils.manifest = {}
ExtUtils.gCfgData = {}
ExtUtils.iCfgData = {}

function ExtUtils.init()
  if ExtUtils.gCfgData[ "Service-URL" ] == nil then
    ExtUtils.gCfgData = getGCfg()
  end
  if ExtUtils.iCfgData[ "message" ] == nil then
    ExtUtils.iCfgData = getICfg()
  end
  if ExtUtils.manifest[ "key" ] == nil then
    ExtUtils.manifest = getManifest()
  end
end

return ExtUtils
