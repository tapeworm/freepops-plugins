-- ************************************************************************** --
--  FreePOPs plugin-check webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russells@despammed.com>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.2.4"
PLUGIN_NAME = "updater"
PLUGIN_REQUIRE_VERSION = "0.2.3"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?module=updater.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russells (at) despammed (.) com"}
PLUGIN_DOMAINS = {"@updater"}
PLUGIN_PARAMETERS = {
	{name="modlist", description = { en = [[The list of modules to update, separated by ','. Example: aaa@updater?modlist=updater,libero,hotmail]], it = [[La lsita di moduli da controllare, separati da ','. Esempio: aaa@updater?modlist=updater,libero,hotmail]]}}
}
PLUGIN_DESCRIPTIONS = {
	it=[[ Questo plugin permette di aggiornare i moduli lua di freepops. Per funzionare correttamente devi configurare l'account @updater in modo che lasci i messaggi sul server. La prima volta che userai l'account @updater tutti i moduli saranno aggiornati.]],
	en=[[
This plugin is used to retrieve updated lua modules for freepops. To use this
plugin correctly, you need to set the settings for the account created for this
to 'leave mail on server'.  The first time, you use this account, all the plugins
will be retrieved.]]
}


-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  browser = nil,
  bClearCache = false,
  excludedPlugins = {},
  pluginsData = {},
  plist = nil,
}

-- the updater_$BACKEND
updater = nil

-- ************************************************************************** --
--  {{{ Helper functions
-- ************************************************************************** --
	
function list2set(s)
	local rc = {}
	for x in string.gmatch(s,'[^,]+') do rx[x]=true end
	return rc
end

-- Build a mail header date string
--
function makeDate()
  return os.date("%a, %d %b %Y %H:%M:%S")
end

-- Build a mail header
--
function makeHeader(plugin, version)
  return 
    "Message-Id: <" .. plugin .. "~" .. version .. ">\r\n"..
    "To: user-of-freepops@donot-reply.org\r\n" ..
    "Date: ".. makeDate() .. "\r\n" ..
    "Subject: FreePOPs module update - "..
    	plugin..", Version "..version.."\r\n" ..
    "From: freepops-plugin-updater@donot-reply.org\r\n"..
    "User-Agent: freepops "..PLUGIN_NAME.." plugin "..PLUGIN_VERSION.."\r\n"
end

-- Build a mail body
--
function makeBody(plugin, data, nStatus, cause)
  local str = "FreePOPs User,\r\n\r\nA new version of the official module " .. 
    plugin .. " (Version: " ..  data.version .. ") has been detected. "

  if nStatus then
    str = str .. "It has been successfully downloaded from "..
      data.url .. " and installed in "..data.local_path.."."
  else
    str = str .. "The plugin cannot be installed: " .. cause
  end

  str = str .. "\r\n\r\nIf you have any questions, please see " ..
    "the FreePOPs home page at http://www.freepops.org" .. 
    "\r\n\r\nThank you for using the program,\r\n\r\n" ..
    "The FreePOPs Team\r\n"

  return str
end

-- ************************************************************************** --
-- }}}
-- ************************************************************************** --

-- ************************************************************************** --
--  {{{ Pop3 functions that must be defined
-- ************************************************************************** --

-- Create a browser
--
function user(pstate, username, foo)
  -- {{{
  -- Create a browser to do the dirty work
  --
  internalState.browser = browser.new()

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true

  -- Check to see if we need to clear the cache
  --
  local val = (freepops.MODULE_ARGS or {}).clearcache or 0
  if val == "1" then
    log.dbg("Updater: Clearing cache -- no updates will take place "..
      "in this operation.")
    internalState.bClearCache = true
  end

  local mlist = (freepops.MODULE_ARGS or {}).modlis
  if mlist ~= nil then
	  internalState.plist = list2set(mlist)
  else
	  internalState.plist = nil -- all plugins	
  end

  -- Add any excluded plugins
  --
  internalState.excludedPlugins["freepops.lua"] = true

  return POPSERVER_ERR_OK
  -- }}}
end

-- Perform login functionality
--
function pass(pstate, password)
  return POPSERVER_ERR_OK
end

-- Quit abruptly
--
function quit(pstate)
  return POPSERVER_ERR_OK
end

-- Update the mailbox status and quit
--
function quit_update(pstate)
  return POPSERVER_ERR_OK
end

-- Stat command - Get the number of messages and their size
--
function stat(pstate)
  -- {{{
  local nMsgs = 0
  -- Have we done this already?  If so, we've saved the results.
  --
  if internalState.bStatDone then
    return POPSERVER_ERR_OK
  end

  -- We end early if we are looking to clear the cache.  By returning a stat
  -- count of zero, the mail client will clear out its cache.
  --
  if internalState.bClearCache == true then
    set_popstate_nummesg(pstate, 0)
    return POPSERVER_ERR_OK
  end

  -- Local variables
  -- 
  local browser = internalState.browser
  
  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  local pdata = {}
  local data, err = updater.fetch_modules_metadata("official",browser)
  if data == nil then
	log.error_print(err)
	return POPSERVER_ERR_NETWORK
  end
  for _,plugin in ipairs(data) do 
	  if internalState.plist == nil or internalState.plist[name] then
	  	pdata[plugin.module_name]=plugin 
          end
  end

  for plugin, data in pairs(pdata) do
    local size = 10240  -- Hard coded for 10k
    local uidl = plugin .. "~" .. data.version

    if internalState.excludedPlugins[plugin] ~= true then
      -- Save the information
      --
      nMsgs = nMsgs + 1
      log.dbg("Processed Plugin - Filename: "..plugin..", Ver: "..data.version)
      set_popstate_nummesg(pstate, nMsgs)
      set_mailmessage_size(pstate, nMsgs, size)
      set_mailmessage_uidl(pstate, nMsgs, uidl)
      internalState.pluginsData[plugin] = data
    end
  end

  -- Update our state
  --
  internalState.bStatDone = true

  -- Return that we succeeded
  --
  return POPSERVER_ERR_OK
  -- }}}
end 

-- Fill msg uidl field
--
function uidl(pstate,msg) 
  return common.uidl(pstate, msg)
end 

-- Fill all messages uidl field
--
function uidl_all(pstate) 
  return common.uidl_all(pstate)
end 

-- Fill msg size
--
function list(pstate,msg)
  return common.list(pstate, msg)
end 

-- Fill all messages size
--
function list_all(pstate)
  return common.list_all(pstate)
end

-- Unflag each message marked for deletion
--
function rset(pstate)
  return common.rset(pstate)
end

-- Mark msg for deletion
--
function dele(pstate,msg)
  return common.dele(pstate, msg)
end

-- Do nothing
--
function noop(pstate)
  return common.noop(pstate)
end

-- Retrieve the message
--
function retr(pstate, msg, data)
  -- Make sure we aren't jumping the gun
  --
  local retCode = stat(pstate)
  if retCode ~= POPSERVER_ERR_OK then 
    return retCode 
  end
  -- Local Variables
  --
  local browser = internalState.browser
  local uidl = get_mailmessage_uidl(pstate, msg)
  local plugin = string.match(uidl, "([^~]+)~") 
  local version = string.match(uidl, "~(.*)")
  local metadata = internalState.pluginsData[plugin]
  local nStatus = metadata.can_update and metadata.should_update
  local cause = metadata.why_cannot_update
  
  -- Replace the plugin
  --
  if nStatus then
    nStatus,cause = updater.fetch_module(plugin,"true","official",browser)
  end

  -- Alert the user -- XXX move away
  --
  mimer.pipe_msg(
    makeHeader(plugin, version), 
    makeBody(plugin, metadata, nStatus,cause), 
    nil, 
    "http://www.freepops.org/", 
    nil, browser, 
    function(s)
      popserver_callback(s, data)
    end, {})
    return POPSERVER_ERR_OK
end

-- Top Command (like retr)
--
function top(pstate, msg, nLines, data)
  return retr(pstate, msg, data)
end

-- Plugin Initialization - Pretty standard stuff.  Copied from the manual
--  XXX reduce the number of require
function init(pstate)
  -- {{{
  -- Let the log know that we have been found
  --
  log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") found!\n")

  -- Import the freepops name space allowing for us to use the status messages
  --
  freepops.export(pop3server)
	
  -- Load dependencies
  --

  -- Browser
  --
  require("browser")
	
  -- MIME Parser/Generator
  --
  require("mimer")

  -- Common module
  --
  require("common")

  -- xml2table module
  --
  require("xml2table")

  -- table2xml module
  --
  require("table2xml")

  -- plugins2xml module
  --
  require("plugins2xml")
	
  -- version comparer module
  --
  require("version_comparer")

  -- the updater engine
  --
  updater = require "updater_php"

  -- Run a sanity check
  --
  freepops.set_sanity_checks()

  -- Let the log know that we have initialized ok
  --
  log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") initialized!\n")

  -- Everything loaded ok
  --
  return POPSERVER_ERR_OK
  -- }}}
end

-- ************************************************************************** --
-- }}}
-- ************************************************************************** --

function interactive()
	local err, fltk = pcall(require,"updater_fltk")
	
	if err == false or fltk == nil or 
	   type(fltk) ~= "table" or fltk.run == nil 
	then
		return nil,[[
The fltk updater is not instealled or cannot be loaded.

Note that our distribution may split the freepops package, separating the fltk
updater, that requires the X windows system, from the simple freepopsd daemon,
that doesn't.

The error message reported by the loader follows:
]]..(fltk or "no message")
	end

	-- run the interactive fltk updater
	fltk.run()

	return ""
end

function batch(...)
	local b = browser.new()	
	local report = {}
	-- arg parsing
	local plist = nil
	if select("#",...) > 0 then
		if select(1,...) == 'only' then
			plist = list2set(select(2,...))
		else
			return updater_usage(select(1,...))
		end
	end

	-- local shortcuts
	local get_mdata = updater.fetch_modules_metadata
	local get_data = updater.fetch_module
	local log = function(msg)
		log.say(msg..'\n')
	end
	local type = "official"

  	local pdata, err =  nil, nil
    	pdata, err = get_mdata(type,b)
	if pdata == nil then
		log("Error: metadata: "..(err or ""))
		return nil, "Error: metadata: "..(err or "")
	end

	for _,mod in ipairs(pdata) do
		local name = mod.module_name
		if plist ~= nil and not plist[name] then
			log("Skip "..name..": not selected for update")
		elseif mod.can_update and mod.should_update then
			local rc, err = get_data(name,"true",type,b)
			if rc == nil then
				log("Error: data for "..name..": "..(err or ""))
			else
			 	log("Updated "..name)
			end
		else
			log("Skip "..name..": "..mod.why_cannot_update)
		end
	end

	return ""
end

function updater_usage(op)
	updater_common.common_usage(nil,nil,op)
	updater_common.print_err([[

Extra operations:

Operation: batch
parameters:
	only string : a comma separated list of modules / default all modules

answer:
	a human readable report

Operation: interactive
parameters:

answer:

Examples:
	freepopsd -e updater.lua php fetch_modules_metadata
	freepopsd -e updater.lua php interactive
	freepopsd -e updater.lua php batch only hotmail,updater
]])
end

-- main is called only by freepopsd -e, in that case the pop3 interface is not
-- used, but updater.cvs or updater.php are.
function main(args)
	require "updater_common"

	local backend = args[1]
	if not backend then
		updater_usage()
		return 1
	end
	table.remove(args,1)

	local err
	err, updater = pcall(require,"updater_"..backend)
	if err == false then
		log.error_print("Unable to load the updater_"..backend.." module.")
		log.error_print(updater)
		return 1
	end

	local op = args[1]
	local local_ops = {
		["interactive"] = interactive, 
		["batch"] = batch
	}

	local fun = local_ops[op] or updater[op] or updater_common[op]
	if fun == nil then
		updater_usage(op)
		return 2
	end
	table.remove(args,1)

	local printer = updater_common.mangler[op] or 
		function(s,...)
			if not s then
				print(...)
				return 1
			else
				print(s,...)
				return 0
			end
		end

	return printer(fun(unpack(args)))
end
