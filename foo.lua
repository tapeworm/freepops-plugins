-- ************************************************************************** --
--  FreePOPs @foo.xx webmail interface, the plugin made in the tutorial,
--  see the manal for more infos about this simple example
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
--  Written by Me <Me@myhouse>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.5"
PLUGIN_NAME = "Foo web mail"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/"
PLUGIN_HOMEPAGE = "http://www.freepops.org"
PLUGIN_AUTHORS_NAMES = {"FP tutorial"}
PLUGIN_AUTHORS_CONTACTS = {"-----"}
PLUGIN_DOMAINS = {"@..."}
PLUGIN_REGEXES = {"@..."}
PLUGIN_PARAMETERS = { 
	{name="--name--", description={en="--desc--",it=="--desc--"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[----]],
	en=[[----]]
}



foo_globals= {
	username="nothing",
	password="nothing"
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

	-- the browser module
	require("browser")

	-- the common module
	require("common")

	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
	foo_globals.username = username
	--print("*** the user wants to login as '"..username.."'")
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	foo_globals.password = password
	--print("*** the user inserted '"..password..
	--	"' as the password for '"..foo_globals.username.."'")
	
	-- create a new browser
	local b = browser.new()
	-- store the browser object in globals
	foo_globals.browser = b
-- 	b:verbose_mode()


	-- create the data to post
	local post_data = string.format("username=%s&password=%s",
		foo_globals.username,foo_globals.password)
	-- the uri to post to
	local post_uri = "http://localhost:3000/"

	-- post it
	local file,err = nil, nil
	file,err = b:post_uri(post_uri,post_data)

	--print("we received this webpage: ".. file)

	-- search the session ID
	local id = string.match(file,"session_id=(%w+)")

	if id == nil then 
		return POPSERVER_ERR_AUTH
	end

	foo_globals.session_id = id

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- shorten names, not really important
	local b = foo_globals.b
	local post_uri = b:wherearewe() .. "/delete.php"
	local session_id = foo_globals.session_id
	local post_data = "session_id=" .. session_id .. "&"

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post_data = post_data .. "check_" ..
				get_mailmessage_uidl(pstate,i).. "=on&"
			delete_something = true	
		end
	end

	if delete_something then
		b:post_uri(post_uri,post_data)
	end

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	if foo_globals.stat_done == true then return POPSERVER_ERR_OK end
	
	local file,err = nil, nil
	local b = foo_globals.browser
	file,err = b:get_uri("http://localhost:3000/inbox.php?session_id="..
		foo_globals.session_id)

	local e = ".*<tr>.*<td>[.*]{b}.*{/b}[.*]</td>.*<td>"..
		"[.*]{b}.*<a>.*</a>.*{/b}[.*]</td>.*"..
		"<td>[.*]{b}.*{/b}[.*]</td>.*<td>[.*]{b}.*{/b}[.*]</td>.*"..
		"<td>.*<input>.*</td>.*</tr>"
	local g = "O<O>O<O>[O]{O}O{O}[O]<O>O<O>[O]{O}O<O>O<O>O{O}[O]<O>O"..
		"<O>[O]{O}X{O}[O]<O>O<O>[O]{O}O{O}[O]<O>O"..
		"<O>O<X>O<O>O<O>"
	local x = mlex.match(file,e,g)
	
	--debug print
	--x:print()

	set_popstate_nummesg(pstate,x:count())

	for i=1,x:count() do
		local size = string.match(x:get(0,i-1),"(%d+)")
		local size_mult_k = string.match(x:get(0,i-1),"([Kk][Bb])")
		local size_mult_m = string.match(x:get(0,i-1),"([Mm][Bb])")
		local uidl = string.match(x:get(1,i-1),"check_(%d+)")

		if size_mult_k ~= nil then
			size = size * 1024
		end
		if size_mult_m ~= nil then
			size = size * 1024 * 1024
		end
		set_mailmessage_size(pstate,i,size)
		set_mailmessage_uidl(pstate,i,uidl)
	end
	
	foo_globals.stat_done = true
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate,msg)
	return common.uidl(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
	return common.uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate,msg)
	return common.list(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages size
function list_all(pstate)
	return common.list_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Unflag each message merked for deletion
function rset(pstate)
	return common.rset(pstate)
end
-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
function dele(pstate,msg)
	return common.dele(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
	return common.noop(pstate)
end

--------------------------------------------------------------------------------
-- The callbach factory for retr
--
function retr_cb(data)
	local a = stringhack.new()
	
	return function(s,len)
		s = a:dothack(s).."\0"
			
		popserver_callback(s,data)
			
		return len,nil
	end
end

-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata)
	return POPSERVER_ERR_OK

end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
		-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- the callback
	local cb = retr_cb(data)
	
	-- some local stuff
	local session_id = foo_globals.session_id
	local b = internal_state.b
	local uri = b:wherearewe() .. "/download.php?session_id="..session_id..
		"&message="..get_mailmessage_uidl(pstate,msg)
	
	-- tell the browser to pipe the uri using cb
	local f,rc = b:pipe_uri(uri,cb)

	if not f then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		return POPSERVER_ERR_NETWORK
	end
end

-- EOF
-- ************************************************************************** --
