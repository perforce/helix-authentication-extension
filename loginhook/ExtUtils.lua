--[[
  Copyright 2021 Perforce Software
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
  if cfg[ "Service-URL" ] == nil then
    -- While localhost is unlikely to work, all other settings have defaults, so
    -- for consistency we should provide a default for this setting as well.
    cfg[ "Service-URL" ] = "http://localhost:3000"
  end
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
  -- massage the client groups into easier to evaluate data
  cfg[ "num_client_sso_groups" ] = 0
  if cfg[ "client-sso-groups" ] ~= nil then
    -- only set num_client_sso_groups if we have an explicitly defined set of groups
    if string.match( cfg[ "client-sso-groups" ], "^%.%.%." ) == nil then
      local groups = {}
      local n = 0
      -- Create a table of groups whose members we target.
      for g in string.gmatch( cfg[ "client-sso-groups" ], "%S+" ) do
        groups[ g ] = 1
        n = n + 1
      end
      cfg[ "client_sso_groups_tbl" ] = groups
      cfg[ "num_client_sso_groups" ] = n
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

function ExtUtils.oauthValidateUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  return base .. "/oauth/validate"
end

function ExtUtils.samlValidateUrl()
  local base = ExtUtils.gCfgData[ "Service-URL" ]
  return base .. "/saml/validate"
end

function ExtUtils.shouldUseSsl( url )
  return string.match( url, "^https://" )
end

function ExtUtils.clientCertificate()
  local path = ExtUtils.gCfgData[ "Client-Cert" ]
  if path ~= nil and string.match( path, "^%.%.%." ) == nil then
    return path
  end
  return Helix.Core.Server.GetArchDirFileName( "client.crt" )
end

function ExtUtils.clientKey()
  local path = ExtUtils.gCfgData[ "Client-Key" ]
  if path ~= nil and string.match( path, "^%.%.%." ) == nil then
    return path
  end
  return Helix.Core.Server.GetArchDirFileName( "client.key" )
end

function ExtUtils.authorityCertificate()
  local path = ExtUtils.gCfgData[ "Authority-Cert" ]
  if path ~= nil and string.match( path, "^%.%.%." ) == nil then
    return path
  end
  return Helix.Core.Server.GetArchDirFileName( "ca.crt" )
end

function ExtUtils.verifyPeer()
  local verify_peer = ExtUtils.gCfgData[ "Verify-Peer" ]
  return verify_peer == "true"
end

function ExtUtils.verifyHost()
  local verify_host = ExtUtils.gCfgData[ "Verify-Host" ]
  return verify_host == "true"
end

function ExtUtils.isClientUser( user )
  -- users in the client-sso-users list are required to use P4LOGINSSO
  local required = ExtUtils.iCfgData[ "client-sso-users" ]
  local hasRequired = false
  if required ~= nil and string.match( required, "^%.%.%." ) == nil then
    hasRequired = true
    local items = ExtUtils.splitWords( required )
    for _, v in pairs( items ) do
      if v == user then
        return true, true, hasRequired
      end
    end
  end
  -- users in groups in the client-sso-groups list are required to use P4LOGINSSO
  local ngroups = ExtUtils.iCfgData[ "num_client_sso_groups" ]
  if ngroups > 0 then
    hasRequired = true
    local groups = ExtUtils.iCfgData[ "client_sso_groups_tbl" ]
    local ok, contains = isUserInGroups( user, groups )
    return ok, contains, hasRequired
  end
  return true, false, hasRequired
end

function ExtUtils.isRequiredUser( user )
  -- users in the sso-users list are required to use SSO
  local required = ExtUtils.iCfgData[ "sso-users" ]
  local hasRequired = false
  if required ~= nil and string.match( required, "^%.%.%." ) == nil then
    hasRequired = true
    local items = ExtUtils.splitWords( required )
    for _, v in pairs( items ) do
      if v == user then
        return true, true, hasRequired
      end
    end
  end
  -- users in groups in the sso-groups list are required to use SSO
  local ngroups = ExtUtils.iCfgData[ "num_sso_groups" ]
  if ngroups > 0 then
    hasRequired = true
    local groups = ExtUtils.iCfgData[ "sso_groups_tbl" ]
    local ok, contains = isUserInGroups( user, groups )
    return ok, contains, hasRequired
  end
  return true, false, hasRequired
end

function ExtUtils.isSkipUser( user )
  -- users in the non-sso-users list are excluded from SSO
  local excluded = ExtUtils.iCfgData[ "non-sso-users" ]
  local hasSkipped = false
  if excluded ~= nil and string.match( excluded, "^%.%.%." ) == nil then
    hasSkipped = true
    local items = ExtUtils.splitWords( excluded )
    for _, v in pairs( items ) do
      if v == user then
        -- skipping because user was excluded
        return true, true, hasSkipped
      end
    end
  end
  -- users in groups in the non-sso-groups list are excluded from SSO
  local ngroups = ExtUtils.iCfgData[ "num_non_sso_groups" ]
  if ngroups > 0 then
    hasSkipped = true
    local groups = ExtUtils.iCfgData[ "non_sso_groups_tbl" ]
    local ok, contains = isUserInGroups( user, groups )
    return ok, contains, hasSkipped
  end
  return true, false, hasSkipped
end

function ExtUtils.getAuthMethodAndType( user )
  -- get ClientApi configured for login-less access to the current server
  local ca, err = Helix.Core.Server.GetAutoClientApi()
  if err ~= nil then
    ExtUtils.debug( {
      [ "getAuthMethodAndType" ] = "error: failed getting auto-client",
      [ "user" ] = user,
      [ "cause" ] = tostring( err )
    } )
    return false, nil, nil
  end
  local e = Helix.Core.P4API.Error.new()
  local cu = Helix.Core.P4API.ClientUser.new()
  ca:SetProtocol( "tag", "" )
  ca:SetProg( "P4-Lua" )
  ca:SetVersion( ExtUtils.getID() )
  ca:Init( e )

  if e:Test() then
    ca:Final()
    ExtUtils.debug( {
      [ "getAuthMethodAndType" ] = "error: failed getting user spec",
      [ "user" ] = user,
      [ "cause" ] = e:Fmt()
    } )
    return false, nil, nil
  end

  local method = "perforce"
  local type = "standard"
  cu.Message = function( self, m )
    ExtUtils.debug( {
      [ "getAuthMethodAndType" ] = "info: " .. m:Fmt(),
      [ "user" ] = user
    } )
  end
  cu.HandleError = function( self, m )
    ExtUtils.debug( {
      [ "getAuthMethodAndType" ] = "error: " .. m:Fmt(),
      [ "user" ] = user
    } )
  end
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

  return true, method, type
end

function isUserInGroups( user, groups )
  -- get ClientApi configured for login-less access to the current server
  local ca, err = Helix.Core.Server.GetAutoClientApi()
  if err ~= nil then
    ExtUtils.debug( {
      [ "isUserInGroups" ] = "error: failed getting auto-client",
      [ "user" ] = user,
      [ "cause" ] = tostring( err )
    } )
    return false, nil
  end
  local e = Helix.Core.P4API.Error.new()
  local cu = Helix.Core.P4API.ClientUser.new()
  ca:SetProtocol( "tag", "" )
  ca:SetProg( "P4-Lua" )
  ca:SetVersion( ExtUtils.getID() )
  ca:Init( e )

  if e:Test() then
    ca:Final()
    ExtUtils.debug( {
      [ "isUserInGroups" ] = "error: failed checking group membership",
      [ "user" ] = user,
      [ "cause" ] = e:Fmt()
    } )
    return false, nil
  end

  local gs = {}
  cu.Message = function( self, m )
    ExtUtils.debug( {
      [ "isUserInGroups" ] = "info: " .. m:Fmt(),
      [ "user" ] = user
    } )
  end
  cu.HandleError = function( self, m )
    ExtUtils.debug( {
      [ "isUserInGroups" ] = "error: " .. m:Fmt(),
      [ "user" ] = user
    } )
  end
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

-- Extract the first non-blank line from the response, which could be a SAML
-- response (with optional prefix) or a JWT from a P4LOGINSSO program.
function ExtUtils.getResponse( str )
  for line in string.gmatch(str, "[^\r\n]+") do
    if string.sub( line, 1, 14 ) == "saml-response:" then
      return trim( string.sub( line, 15, #line ) )
    end
    return str
  end
  return nil
end

function ExtUtils.userIdentifier( usingClient )
  local field
  if usingClient then
    field = ExtUtils.iCfgData[ "client-user-identifier" ]
  else
    field = ExtUtils.iCfgData[ "user-identifier" ]
  end
  local userid = Helix.Core.Server.GetVar( field:lower() )
  if userid then
    return userid
  end
  -- default to the email so we match the default for name-identifier
  return Helix.Core.Server.GetVar( "email" )
end

function ExtUtils.nameIdentifier( usingClient, profile )
  local field
  if usingClient then
    field = ExtUtils.iCfgData[ "client-name-identifier" ]
  else
    field = ExtUtils.iCfgData[ "name-identifier" ]
  end
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
