-- ************************************************************************** --
--  FreePOPs @--put here domain-- webmail interface
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
--  Written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.6"
PLUGIN_NAME = "DAVMAIL"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=davmail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@lycos.co.uk","@lycos.ch","@lycos.de","@lycos.es",
	"@lycos.it","@lycos.at","@lycos.nl","@spray.se","@jubii.dk"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		it = [[
La cartella che vuoi utilizzare. Il default &egrave; inbox.
		]], en = [[
The folder you want to read. Default is inbox.
		]]}}}
PLUGIN_DESCRIPTIONS = {
	it="Questo plugin &egrave; per gli account che usano il "..
	   "protocollo HTTPMAIL.<br/>Limitazione per Jubii.dk: Non &egrave; "..
	   "possibile lasciare i messaggi sul server, in quanto dopo la "..
	   "prima lettura non sono pi&ugrave; visibili (ma non vengono "..
	   "cancellati, via web si vedono). Quindi se non vuoi usare la "..
	   "webmail per cancellare i messaggi non scegliere l'opzione "..
	   "&quot;lacia una copia dei messaggi sul server&quot; nella "..
	   "configurazione di questo account.",
	en="This plugin implements the HTTPMAIL protocol.<br/>Limitation for "..
	   "Jubii.dk: it is not possible to &quot;leave a copy of the "..
	   "messages on server&quot; since after they've been seen once they "..
	   "disappear (but are not deleted, since via web you can "..
	   "manage them). So, if you don't want to use the webmail to empty "..
	   "your mailbox, don't mark the &quot;leave a copy...&quot; option "..
	   "in your account configuration."
	   
}



internal_state = {
	b = nil,
	username = nil,
	password = nil,
	folderuri = nil,
	stat_done = false,
	login_done = false,
	stat_done = false,
	login_site = nil,
	domain = nil,
	auth = nil,
}

function login_site_for(domain, name)
	-- $U is expanded to the username (domain is stripped off)
	local login_sites = {
		 -- thanks hotway for these uris :)
		 ["lycos.co.uk"] = "http://webdav.lycos.co.uk/httpmail.asp",
		 ["lycos.ch"] = "http://webdav.lycos.de/httpmail.asp",
		 ["lycos.de"] = "http://webdav.lycos.de/httpmail.asp",
		 ["lycos.es"] = "http://webdav.lycos.es/httpmail.asp",
		 ["lycos.it"] = "http://webdav.lycos.it/httpmail.asp",
		 ["lycos.at"] = "http://webdav.lycos.at/httpmail.asp",
		 ["lycos.nl"] = "http://webdav.lycos.nl/httpmail.asp",
		 ["spray.se"] = "http://webdav.spray.se/httpmail.asp",
		 ["jubii.dk"] = "http://webdav.jubii.dk/$U",
	}
	return string.gsub(login_sites[domain],"$U",name) 
end

-- this is not a plain table since httpmail is loaded during init()
function needed_auth(domain) 
	local t = {
		["lycos.co.uk"] = httpmail.LOGIN_BASIC,
		["lycos.de"] = httpmail.LOGIN_BASIC, 
		["lycos.de"] = httpmail.LOGIN_BASIC,
		["lycos.es"] = httpmail.LOGIN_BASIC,
		["lycos.it"] = httpmail.LOGIN_BASIC,
		["lycos.at"] = httpmail.LOGIN_BASIC,
		["lycos.nl"] = httpmail.LOGIN_BASIC,
		["spray.se"] = httpmail.LOGIN_BASIC,
		["jubii.dk"] = httpmail.LOGIN_BASIC,
	}
	return t[domain]
end

function needed_useragent(domain) 
	local t = {
		["jubii.dk"] = "Lycos-Addin authentication"
	}
	return t[domain]
end

--------------------------------------------------------------------------------
-- The key used to store session info
--
-- This key must be unique for all webmails, since the session pool is one 
-- for all the webmails
--
function key()
	return (internal_state.username or "")..
		(internal_state.password or "")..
		(internal_state.folderuri or "")
end
function serialize_state()
	internal_state.stat_done = false;
	
	return serial.serialize("internal_state",internal_state) ..
		internal_state.b:serialize("internal_state.b")
end

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
	require("serial")

	-- the browser module
	require("browser")

	-- lod these in this order
	require("xml2table")
	require("table2xml")
	require("httpmail")

	-- the common module
	require("common")
	
	
	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)

	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)
	local login_site = login_site_for(domain, name)
	local auth = needed_auth(domain)

	if login_site == nil then
		log.error_print("Unknown domain "..(domain or "nil"))
		return POPSERVER_ERR_AUTH
	end

	internal_state.login_site = login_site
	internal_state.domain = domain
	internal_state.auth = auth
	internal_state.username = name .. "@" .. domain
	
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	-- save the password
	internal_state.password = password

	-- eventually load session
	local s = session.load_lock(key())

 	-- check if loaded properly
	if s ~= nil then
		-- "\a" means locked
		if s == "\a" then
			log.say("Session for "..internal_state.username..
				" is already locked\n")
			return POPSERVER_ERR_LOCKED
		end
	
		-- load the session
		local c,err = loadstring(s)
		if not c then
			log.error_print("Unable to load saved session: "..err)
			return owa_login()
		end
		
		-- exec the code loaded from the session string
		c()

		log.say("Session loaded for " .. internal_state.username .."\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return owa_login()
	end
	
end

function owa_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- jubii.dk needs a specia useragent
	internal_state.b = browser.new(needed_useragent(internal_state.domain))
	
	local b = internal_state.b
	--b:verbose_mode()
	
	local uri,err = httpmail.login(b,
		internal_state.login_site,
		internal_state.username,
		internal_state.password,
		internal_state.auth)

	if not uri then
		log.error_print(err)
		return POPSERVER_ERR_AUTH
	end

	local folder_list,err = httpmail.folderlist(b,uri)
	if not folder_list then
		log.error_print(err)
		return POPSERVER_ERR_AUTH
	end

	local folder = (freepops.MODULE_ARGS or {}).folder or "inbox"
	
	internal_state.folderuri = table.foreach(folder_list,function(_,k)
		if k.name == folder then
			return k.uri
		end
	end)
		
	if internal_state.folderuri ~= nil then
		log.say("Session started for " .. internal_state.username.."\n")
		return POPSERVER_ERR_OK
	end
	
	local list = {}
	table.foreach(folder_list,function(_,k)
		table.insert(list,k.name.." -> "..k.uri.. "\n")
	end)
	log.error_print("Unable to find "..folder.." uri in this list:\n"..
		table.concat(list))
	return POPSERVER_ERR_AUTH
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
	local b = internal_state.b

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = {};
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			table.insert(delete_something,
				get_mailmessage_uidl(pstate,i))
		end
	end

	-- FIXME XXX maybe you can delete all removin /inbox
	table.foreachi(delete_something,function(_,u)
		httpmail.delete(b,u)
	end)
	
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end

	local b = internal_state.b
	local  uri = internal_state.folderuri
	
	local msglist,err = httpmail.stat(b,uri)
	if msglist == nil then
		log.error_print(err)
		return POPSERVER_ERR_UNKNOWN
	end
	
	set_popstate_nummesg(pstate,#msglist)
	for i,t in ipairs(msglist) do
		local size = t.size
		local uidl = t.uri
		set_mailmessage_size(pstate,i,size)
		set_mailmessage_uidl(pstate,i,uidl)
	end
	
	internal_state.stat_done = true

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
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- some local stuff
	local b = internal_state.b
	local size = get_mailmessage_size(pstate,msg)
	local uri = get_mailmessage_uidl(pstate,msg)

	return common.top(b,uri,key(),size,lines,data,false)

end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- check the range
	if not common.check_range(pstate,msg) then
		return POPSERVER_ERR_NOMSG	
	end
	
	-- the callback
	local cb = common.retr_cb(data)
	
	-- some local stuff
	local popserver = internal_state.popserver
	local session_id = internal_state.session_id
	local b = internal_state.b
	
	-- build the uri
	local uri = get_mailmessage_uidl(pstate,msg)
	
	-- tell the browser to pipe the uri using cb
	local f,rc = httpmail.pipe(b,uri,cb)

	if not f then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		-- don't remember if this should be done
		--session.remove(key())
		return POPSERVER_ERR_NETWORK
	end

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
