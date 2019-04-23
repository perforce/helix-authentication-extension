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

local function rawpairs( t )
  return next, t, nil
end

function trim( s )
  return s:gsub( "^%s*(.-)%s*$", "%1" )
end

function getGCfg()
  local cfg = {}
  for k, v in pairs( Perforce.GetGlobalConfigData() ) do
    cfg[ k ] = trim( v )
  end
  -- assert certain settings at least appear to be valid
  assert( string.match( cfg[ "Service-URL" ], "^http" ), "Service-URL must start with 'http'" )
  if string.match( cfg[ "Auth-Protocol" ], " " ) ~= nil then
    error( "Auth-Protocol must not contain spaces" )
  end
  return cfg
end

function getICfg()
  local cfg = {}
  for k, v in pairs( Perforce.GetInstanceConfigData() ) do
    cfg[ k ] = trim( v )
  end
  -- massage the excluded groups into easier to evaluate data
  cfg[ "ngroups" ] = 0
  if cfg[ "non-sso-groups" ] ~= nil then
    -- only set ngroups if we have an explicitly defined set of groups
    if string.match( cfg[ "non-sso-groups" ], "^%.%.%." ) == nil then
      local groups = {}
      local n = 0
      -- Create a table of groups whose members we target.
      for g in string.gmatch( cfg[ "non-sso-groups" ], "%S+" ) do
        groups[ g ] = 1
        n = n + 1
      end
      cfg[  "groups" ] = groups
      cfg[ "ngroups" ] = n
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

function ExtUtils.debug( data )
  local log_enabled = ExtUtils.iCfgData[ "enable-logging" ]
  if log_enabled == "true" then
    Perforce.log( data )
  end
end

function ExtUtils.loginUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  local method = ExtUtils.gCfgData[ "Auth-Protocol" ]
  return base .. "/" .. method .. "/login/"
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
  local users = ExtUtils.iCfgData[ "non-sso-users" ]
  if string.match( users, "^%.%.%." ) == nil then
    local items = ExtUtils.splitWords( users )
    for _, v in pairs( items ) do
      if v == user then
        return true
      end
    end
  end
  return false
end

function isUserInGroups( user, groups )
  -- copied from login_motd example code...
  local e = Perforce.Error.new()
  local cu = Perforce.ClientUser.new()
  -- This function automatically logs the P4USER specified in the
  -- Extension's global config into the server running the Extension.
  -- Note that this doesn't help configure an SSL/Unicode server.
  local ca = Perforce.GetAutoClientApi()

  ca:SetProtocol( "tag", "" )
  ca:SetProg( "P4-Lua" )

  ca:Init( e )

  if e:Test() then
    ca:Final()
    return true, e:Fmt()
  end

  ca:SetVersion( ExtUtils.getID() )

  local gs = {}

  -- Override the ClientUser::OutputStat function to record the
  -- list of groups.  This API mirrors the C++ P4API:
  -- https://www.perforce.com/perforce/doc.current/manuals/p4api/

  cu.OutputStat = function( self, dict )
    gs[ dict[ "group" ] ] = 1
  end

  ca:SetVar( ca:Null(), "-u" )
  ca:SetVar( ca:Null(), "-i" )
  ca:SetVar( ca:Null(), user )
  ca:Run( "groups", cu );
  ca:Final()

  for k, v in rawpairs( groups ) do
    if gs[ k ] ~= nil then
      return false, true
    end
  end

  return false, false
end

function ExtUtils.isUserInSkipGroup( user )
  local ngroups = ExtUtils.iCfgData[ "ngroups" ]
  if ngroups > 0 then
    local groups = ExtUtils.iCfgData[ "groups" ]
    return isUserInGroups( user, groups )
  end
  return false, false
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

function ExtUtils.userIdentifier()
  local field = ExtUtils.iCfgData[ "user-identifier" ]
  local userid = Perforce.GetVar( field:lower() )
  if userid then
    return userid
  end
  -- default to the email so we match the default for name-identifier
  return Perforce.GetVar( "email" )
end

function ExtUtils.nameIdentifier( profile )
  local field = ExtUtils.iCfgData[ "name-identifier" ]
  local nameid = profile[ field ]
  if nameid then
    return nameid
  end
  -- default to email which is likely to work most of the time
  return profile[ "email" ]
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
