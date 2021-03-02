--[[
  Copyright 2020 Perforce Software
]]--
local ExtUtils = {}
local cjson = require "cjson"

function getManifest()
  local fn = Helix.Core.Server.GetArchDirFileName( "manifest.json" )
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
  for k, v in pairs( Helix.Core.Server.GetGlobalConfigData() ) do
    cfg[ k ] = trim( v )
  end
  -- assert certain settings at least appear to be valid
  assert( string.match( cfg[ "Service-URL" ], "^http" ), "Service-URL must start with 'http'" )
  -- remove any trailing slash from the URL
  cfg[ "Service-URL" ] = (cfg[ "Service-URL" ]:gsub("^(.-)/?$", "%1"))
  return cfg
end

function getICfg()
  local cfg = {}
  for k, v in pairs( Helix.Core.Server.GetInstanceConfigData() ) do
    cfg[ k ] = trim( v )
  end
  -- massage the required groups into easier to evaluate data
  cfg[ "num_sso_groups" ] = 0
  if cfg[ "sso-groups" ] ~= nil then
    -- only set num_sso_groups if we have an explicitly defined set of groups
    if string.match( cfg[ "sso-groups" ], "^%.%.%." ) == nil then
      local groups = {}
      local n = 0
      -- Create a table of groups whose members we target.
      for g in string.gmatch( cfg[ "sso-groups" ], "%S+" ) do
        groups[ g ] = 1
        n = n + 1
      end
      cfg[ "sso_groups_tbl" ] = groups
      cfg[ "num_sso_groups" ] = n
    end
  end
  -- massage the excluded groups into easier to evaluate data
  cfg[ "num_non_sso_groups" ] = 0
  if cfg[ "non-sso-groups" ] ~= nil then
    -- only set num_non_sso_groups if we have an explicitly defined set of groups
    if string.match( cfg[ "non-sso-groups" ], "^%.%.%." ) == nil then
      local groups = {}
      local n = 0
      -- Create a table of groups whose members we target.
      for g in string.gmatch( cfg[ "non-sso-groups" ], "%S+" ) do
        groups[ g ] = 1
        n = n + 1
      end
      cfg[ "non_sso_groups_tbl" ] = groups
      cfg[ "num_non_sso_groups" ] = n
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
    Helix.Core.Server.log( data )
  end
end

function ExtUtils.loginUrl( sdata )
  -- if auth protocol is defined, use that to assemble a login URL
  local protocol = ExtUtils.gCfgData[ "Auth-Protocol" ]
  if string.len(protocol) > 0 and string.match( protocol, "^%.%.%." ) == nil then
    local base = sdata[ "baseUrl" ]
    local request = sdata[ "request" ]
    return base .. "/" .. protocol .. "/login/" .. request
  end
  -- otherwise use what the authentication service returned
  return sdata[ "loginUrl" ]
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

function ExtUtils.shouldUseSsl( url )
  return string.match( url, "^https://" )
end

function ExtUtils.isSkipUser( user )
  -- users in the sso-users list are required to authenticate using SSO
  local required = ExtUtils.iCfgData[ "sso-users" ]
  if required ~= nil and string.match( required, "^%.%.%." ) == nil then
    local items = ExtUtils.splitWords( required )
    for _, v in pairs( items ) do
      if v == user then
        -- not skipping because user is required
        return false
      end
    end
    -- skipping because user was _not_ in the required list
    return true
  end
  -- users in the non-sso-users list are excluded from SSO authentication
  local excluded = ExtUtils.iCfgData[ "non-sso-users" ]
  if excluded ~= nil and string.match( excluded, "^%.%.%." ) == nil then
    local items = ExtUtils.splitWords( excluded )
    for _, v in pairs( items ) do
      if v == user then
        -- skipping because user was excluded
        return true
      end
    end
  end
  -- in all other cases authenticate using SSO
  return false
end

function ExtUtils.isLdapOrNonStandard( user )
  local e = Helix.Core.P4API.Error.new()
  local cu = Helix.Core.P4API.ClientUser.new()
  local ca = Helix.Core.Server.GetAutoClientApi()
  ca:SetProtocol( "tag", "" )
  ca:SetProg( "P4-Lua" )
  ca:SetVersion( ExtUtils.getID() )
  ca:Init( e )

  if e:Test() then
    ca:Final()
    return false, e:Fmt()
  end

  local method = "perforce"
  local type = "standard"
  cu.OutputStat = function ( self, dict )
    for k, v in dict:pairs() do
      if k == "AuthMethod" then
        method = v
      elseif k == "Type" then
        type = v
      end
    end
  end

  ca:SetVar( ca:Null(), "-o" )
  ca:SetVar( ca:Null(), user )
  ca:Run( "user", cu )
  ca:Final()

  return true, method == "ldap" or type ~= "standard"
end

function isUserInGroups( user, groups )
  local e = Helix.Core.P4API.Error.new()
  local cu = Helix.Core.P4API.ClientUser.new()
  local ca = Helix.Core.Server.GetAutoClientApi()
  ca:SetProtocol( "tag", "" )
  ca:SetProg( "P4-Lua" )
  ca:SetVersion( ExtUtils.getID() )
  ca:Init( e )

  if e:Test() then
    ca:Final()
    return false, e:Fmt()
  end

  local gs = {}
  cu.OutputStat = function( self, dict )
    gs[ dict[ "group" ] ] = 1
  end

  ca:SetVar( ca:Null(), "-u" )
  ca:SetVar( ca:Null(), "-i" )
  ca:SetVar( ca:Null(), user )
  ca:Run( "groups", cu )
  ca:Final()

  for k, v in rawpairs( groups ) do
    if gs[ k ] ~= nil then
      return true, true
    end
  end

  return true, false
end

function ExtUtils.isUserInSkipGroup( user )
  -- users in groups in the sso-groups list are required to use SSO
  local ngroups = ExtUtils.iCfgData[ "num_sso_groups" ]
  if ngroups > 0 then
    local groups = ExtUtils.iCfgData[ "sso_groups_tbl" ]
    -- skipping because user was excluded by group
    local ok, inGroup = isUserInGroups( user, groups )
    if not ok then
      -- there was an error checking the group membership
      return false, false
    end
    if inGroup then
      -- not skipping because user is required
      return true, false
    end
    -- skipping because user was _not_ in the required groups list
    return true, true
  end
  -- users in groups in the non-sso-groups list are excluded
  local ngroups = ExtUtils.iCfgData[ "num_non_sso_groups" ]
  if ngroups > 0 then
    local groups = ExtUtils.iCfgData[ "non_sso_groups_tbl" ]
    -- skipping because user was excluded by group
    return isUserInGroups( user, groups )
  end
  -- in all other cases authenticate using SSO
  return true, false
end

-- Return true if the client appears to be an older P4V release. This logic only
-- works for P4V, as both the clientprog and clientversion strings are entirely
-- in the control of the client, meaning there is no convention for these
-- values.
function ExtUtils.isOlderP4V()
  --
  -- prompts for password, does not launch browser
  -- info: clientprog: P4V/MACOSX1011X86_64/2017.1/1491634
  -- info: clientversion: v81
  --
  -- prompts for password and opens browser
  -- info: clientprog: Helix P4V/MACOSX1013X86_64/2019.1/1865170
  -- info: clientversion: v86
  --
  -- opens browser
  -- info: clientprog: Helix P4V/MACOSX1015X86_64/2020.1/1966006
  -- info: clientversion: v87
  --
  local clientprog = Helix.Core.Server.GetVar( "clientprog" )
  -- Check against P4V/ string because P4VS could match too
  if string.find( clientprog, "P4V/" ) then
    -- strip the leading 'v' and trailing potential brokered string then check P4V's client version number
    local clientversion = Helix.Core.Server.GetVar( "clientversion" )
    local version = tonumber( string.match( clientversion, "%d+" ) )
    if version < 86 then
      return true
    end
  end
  return false
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
  local userid = Helix.Core.Server.GetVar( field:lower() )
  if userid then
    return userid
  end
  -- default to the email so we match the default for name-identifier
  return Helix.Core.Server.GetVar( "email" )
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
