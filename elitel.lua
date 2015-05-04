-- ************************************************************************** --
--  FreePOPs @--put here domain-- webmail interface
-- 
--  $Id: skeleton.lua,v 1.7 2004/09/14 17:08:15 gareuselesinge Exp $
-- 
--  Released under the GNU/GPL license
--  Written by --put Name here-- <--put email here-->
-- ************************************************************************** --

PLUGIN_VERSION = "0.1.6"
PLUGIN_NAME = "elitel.biz"
PLUGIN_REQUIRE_VERSION = "0.0.97"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=elitel.lua"
PLUGIN_HOMEPAGE = "http://matteo1164.interfree.it/"
PLUGIN_AUTHORS_NAMES = {"Matteo Turconi"}
PLUGIN_AUTHORS_CONTACTS = {"matteo.turconi@lombardiacom.it"}
PLUGIN_DOMAINS = {"@lombardiacom.it", "@postino.it"}
PLUGIN_PARAMETERS = { 
	{name="---na---", 
	 description={en="---na---",it=="---na---",}},
}
PLUGIN_DESCRIPTIONS = {
	it="Questo plugin &egrave; per gli account di "..
	   "posta del portale elitel.biz. Per il momento "..
	   "sono supportate le webmail di lombardiacom.it e di "..
	   "postino.it. Utilizzare lo username completo di "..
	   "dominio e l'usuale password. ",
	en="This plugin is for accounts of elitel.biz. For the "..
	   "moment only lombardiacom.it and postino.it are supported. "..
	   "Use username with domain and the usual password.",
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
	stat_done = false,
	login_done = false,
	no_msg = false,
	offset = 0,
	start = 0,
	session_id = nil,
	domain = nil,
	name = nil,
	password = nil,		
	b = nil
}

-- this table contains the realtion between the mail address domain, the
-- webmail domain name and the mailbox domain
local lc_domain = {
	["lombardiacom.it"] = { website=".lombardiacom.it",        choice="lombardiacom" },
	["postino.it"] = { website=".postino.it",        choice="postino" },
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Checks the validity of a domain
--
function check_domain(domain)
	return 	lc_domain[domain] ~= nil
end

-- ************************************************************************** --
-- Webmail functions
-- ************************************************************************** --

-- Is called to initialize the module
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the serialization module
	--if freepops.dofile("serialize.lua") == nil then 
	--	return POPSERVER_ERR_UNKNOWN 
	--end 

	-- the browser module
	if freepops.dofile("browser/browser.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end

	-- the common implementation module
	if freepops.dofile("common.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end
	
	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
	log.dbg("--- function user "..username)
	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)
	-- log information
	log.dbg("*** name@domain "..name.."@"..domain)
	
	-- check if the domain is valid
	if not check_domain(domain) then
		log.error_print("Invalid domain ("..domain..")!")
		return POPSERVER_ERR_AUTH
	end
	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name
	
	log.dbg("--- return user")
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	log.dbg("--- function pass "..password)
	-- save the password
	internal_state.password = password
	-- Some checks before continuing
	if internal_state.login_done then
		log.dbg("*** Login just done!")
		return POPSERVER_ERR_OK
	end
	-- Format Post data and uri
	local user = internal_state.name.."@"..internal_state.domain
	local pwd = internal_state.password
	local login_str = "actionID=105&redirect_url=&mailbox=INBOX&server=lombardiacom&"
		.."folders=INBOX.&imapuser=%s&pass=%s&imapuserf=nome@dominio.it&passf="
	local post = string.format(login_str, user, pwd)
	local uri = "http://www.postino.punto.it/horde_postino/imp/redirect.php"
	log.dbg("*** post "..post)
	log.dbg("*** uri "..uri)
	-- the browser must be preserved
	internal_state.b = browser.new()
	local b = internal_state.b
	-- find string
	local find_str = "name=\"Horde\" value=\"(%w+)\""
	-- functions for do until
	local extract_f = support.do_extract(internal_state,"session_id",find_str)
	local check_f = support.check_fail
	local retrive_f = support.retry_n(3,support.do_post(b,uri,post))
	-- do until can retrive session id
	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end
	-- check if do_extract has correctly extracted the session ID
	if internal_state.session_id == nil then
		log.error_print("Login failed, unable to get session ID!\n")
		return POPSERVER_ERR_AUTH
	end
	-- log current session id
	log.dbg("*** session_id "..internal_state.session_id)
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. 
		"(" .. internal_state.session_id .. ")\n")
	-- update status
	internal_state.login_done = true
	log.dbg("--- return pass")
    return POPSERVER_ERR_OK    
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
	log.dbg("--- function quit")
	log.dbg("--- return quit")
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
	log.dbg("--- function quit_update")
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then 
		log.error_print("*** st not POPSERVER_ERR_OK:"..st)
		return st 
	end
	
	-- no messages, no quit update needed
	if internal_state.no_msg == true then
		log.dbg("*** quit update not needed: no messages!")
		return POPSERVER_ERR_OK
	end
	
	log.dbg("*** updating...")
	-- shorten names, not really important
	local del_str = "http://www.postino.punto.it/horde_postino/imp/mailbox.php?"..
		"Horde=%s&actionID=101&targetMbox=&newMbox=0&flag=";
	local del_msg_str = "&indices%%5B%%5D=%d"
	local session_id = internal_state.session_id
	local b = internal_state.b

	local uri = string.format(del_str,session_id)
	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			uri = uri .. string.format(del_msg_str,get_mailmessage_uidl(pstate,i))
			delete_something = true	
		end
	end

	-- log working uri
	log.dbg("*** uri "..uri)	
	
	if delete_something then
		log.dbg("*** delete_something true")
		-- Build the functions for do_until
		local extract_f = function(s) return true,nil end
		local check_f = support.check_fail
		local retrive_f = support.retry_n(3,support.do_retrive(b,uri))

		if not support.do_until(retrive_f,check_f,extract_f) then
			log.error_print("Unable to delete messages\n")
			return POPSERVER_ERR_UNKNOWN
		end
	end
	
	log.dbg("--- return quit_update")
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	log.dbg("--- function stat")
	-- do it only one time
	if internal_state.stat_done then 
		log.dbg("*** stat just done!")
		return POPSERVER_ERR_OK
	end
	
	local session_id = internal_state.session_id
	local b = internal_state.b
	local page = 1
	
	-- string to get uri
	local get_str = "http://www.postino.punto.it/horde_postino/imp/mailbox.php?"
		.."Horde=%s&mailbox=INBOX&actionID=105&page=%d"
	local uri = string.format(get_str, internal_state.session_id,page)
	log.dbg("*** uri "..uri)
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s)
		log.dbg("--- function action_f")
		-- stat strings
		local statE = ".*<tr>.*<td>.*<input.*value.*=.*[[:digit:]]+.*>[.*]{img}[.*]{img}.*</td>.*<td>.*</td>.*<td>[.*]{b}.*{/b}[.*]</td>"
			..".*<td>.*<a>[.*]{b}.*{/b}[.*]</a>.*</td>.*<td>.*</td>.*<td>.*<a>[.*]{b}.*{/b}[.*]</a>.*</td>.*<td>.*</td>.*</tr>"
			
		local statG = "O<O>O<O>O<X>[O]{O}[O]{O}O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>[O]{O}O{O}[O]"
			.."<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>X<O>O<O>"
		
		-- match in webpage	
		local x = mlex.match(s,statE,statG)	
		log.dbg("*** mlex.match")
		local n = x:count()
		log.dbg("*** x:count "..n)
		
		if n == 0 then
			log.dbg("*** n == 0")
			internal_state["no_msg"] = true
			internal_state["stat_done"] = true
			log.dbg("--- return action_f")
			return true,nil
		end
		
		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		local nmesg_old = get_popstate_nummesg(pstate)
		local nmesg = nmesg_old + n
		set_popstate_nummesg(pstate,nmesg)
		log.dbg("*** set_popstate_nummesg "..nmesg)
		
		for i=1,n do
			local uidl = x:get (0,i-1) 
			local size = x:get (1,i-1)		
			log.dbg("*** uidl "..uidl)
			log.dbg("*** size "..size)
			
			local k = nil
			_,_,k = string.find(size,"([Kk][Bb])")
			_,_,size = string.find(size,"(%d+)")
			_,_,uidl = string.find(uidl,"value=\"(%d+)\"")
			-- kilobytes??
			if k ~= nil then
				size = size * 1024
			end
	
			if not uidl or not size then
				log.dbg("*** Unable to parse page!")
				log.dbg("--- return action_f")
				return true,nil
			end
	
			set_mailmessage_size(pstate,i+nmesg_old,size)
			set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
		end	
		log.dbg("--- return action_f")
		return true,nil
	end

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function check_f (s)  
		log.dbg("--- function check_f")
		local tmp1,tmp2 = string.find(s,"Pagina Successiva")
		if tmp1 ~= nil then
			local get_next_str = "http://www.postino.punto.it/horde_postino/imp/mailbox.php?page=%d"
			page = page + 1			
			-- change retrive behaviour
			uri = string.format(get_next_str,page)
			log.dbg("*** uri "..uri)
			-- continue the loop
			log.dbg("*** return false")
			return false
		else
			log.dbg("*** return true")
			return true
		end
		log.dbg("--- return check_f")
	end

	-- this is simple and uri-dependent
	local function retrive_f ()
		log.dbg("--- function retrive_f")
		local f,err = b:get_uri(uri)
		log.dbg("*** uri "..uri)
		if f == nil then
			log.dbg("*** f nil")
			log.dbg("--- return retrive_f")
			return f,err
		end
		log.dbg("--- return retrive_f")
		return f,err
	end

	-- initialize the data structure
	set_popstate_nummesg(pstate,0)
	log.dbg("*** set_popstate_nummesg 0")

	-- do it
	if not support.do_until(retrive_f,check_f,action_f) then
		log.error_print("Stat failed\n")
		return POPSERVER_ERR_UNKNOWN
	end
	
	-- save status
	internal_state["stat_done"] = true
	internal_state["no_msg"] = false
	internal_state["start"] = 1
	log.dbg("--- return stat")	
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
function top(pstate,msg,lines,pdata)
	log.dbg("--- function top")
	log.dbg("--- return top")
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)	
	log.dbg("--- function retr")
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then
		log.dbg("*** st not POPSERVER_ERR_OK:"..st)
		return st 
	end
	
	-- the callback
	local cb = common.retr_cb(pdata)
	
	-- some local stuff	
	local b = internal_state.b

	local offset = internal_state.offset
	local start = internal_state.start
	local save_str = "http://www.postino.punto.it/horde_postino/imp/download/?"
		.."thismailbox=INBOX&start=%d&index=%d&actionID=112&fn=/message"
	log.dbg("*** msg "..msg)
	if msg == 1 then
		offset = 20
		start = 1
		internal_state.offset = offset
		internal_state.start = start
	end
	if msg > offset then
		start = start + 20
		offset = offset + 20
		internal_state.offset = offset
		internal_state.start = start
	end
	log.dbg("*** start "..internal_state.start)
	log.dbg("*** offset "..internal_state.offset)
	
	-- build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(save_str,start,uidl)
	
	-- tell the browser to pipe the uri using cb
	log.dbg("*** b:pipe_uri "..uri)
	local f,rc = b:pipe_uri(uri,cb)

	if not f then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		-- don't remember if this should be done
		--session.remove(key())
		return POPSERVER_ERR_NETWORK
	end
	
	log.dbg("--- return retr")
	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
