-- ************************************************************************** --
--  FreePOPs @--put here domain-- webmail interface
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
--  Written by --put Name here-- <--put email here-->
-- ************************************************************************** --

PLUGIN_VERSION = "---put_version_here---"
PLUGIN_NAME = "---put name here---"
PLUGIN_REQUIRE_VERSION = "---fill---"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org"
PLUGIN_HOMEPAGE = "http://www.freepops.org/download.php?module=skeleton.lua"
PLUGIN_AUTHORS_NAMES = {"---fill--- "}
PLUGIN_AUTHORS_CONTACTS = {"---fill---"}
PLUGIN_DOMAINS = {"@..."}
PLUGIN_REGEXES = {"@..."}
PLUGIN_PARAMETERS = { 
	{name="---name---", 
	 description={en="---desc-en---",it=="---desc-it---"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[---desc-it---]],
	en=[[---desc-en---]]
}

-- ************************************************************************** --
-- 
-- This is the interface to the external world. These are the functions 
-- that will be called by FreePOPs.
--
-- param pstate is the userdata to pass to (set|get)_popstate_* functions
-- param username is the mail account name
-- param password is the account password
-- param msg is the message number to operate on (may be decreased dy 1)
-- param pdata is an opaque data for popserver_callback(buffer,pdata) 
-- 
-- return POPSERVER_ERR_*
-- 
-- ************************************************************************** --

-- Is called to initialize the module
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the serialization module
	--require("serial")
	--	return POPSERVER_ERR_UNKNOWN 
	--end 

	-- the browser module
	--require("browser")
	--	return POPSERVER_ERR_UNKNOWN 
	--end
	
	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)

end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages size
function list_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Unflag each message merked for deletion
function rset(pstate)
end
-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
function dele(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
end
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata)
end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
end

-- EOF
-- ************************************************************************** --
