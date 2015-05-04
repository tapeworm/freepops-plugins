-- ************************************************************************** --
--  FreePOPs @aruba.it webmail interface
-- 
--  $Id: aruba.lua,v 0.0.3 2010/12/21 13:07:00 helios ciancio Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Helios CIANCIO <info ( at ) eshiol ( dot ) it>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.3"
PLUGIN_NAME = "Aruba.it"
PLUGIN_REQUIRE_VERSION = "0.2.6"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=aruba.lua"
PLUGIN_HOMEPAGE = "http://www.eshiol.it"
PLUGIN_AUTHORS_NAMES = {"Helios Ciancio"}
PLUGIN_AUTHORS_CONTACTS = {"info ( at ) eshiol ( dot ) it"}
PLUGIN_DOMAINS = {"@aruba.it"}
-- list of tables with fields name and description. 
-- description must be in the stle of PLUGIN_DESCRIPTIONS,
-- so something like {it="bla bla bla", en = "bla bla bla"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		it = [[Serve per selezionare la cartella su cui operare (Inbox
&egrave; quella di default). 
Le cartelle standard disponibili sono Inbox, Drafts, Sent, Trash. I nomi delle
cartelle sono case sensitive.
Esempio: foouser@foodomain?folder=Trash]],
		en=[[The folder you want to interact with (default is Inbox).
Standard folders are Inbox, Drafts, Sent, Trash. Folders' name are case 
sensitive.
Example: foouser@foodomain?folder=Trash]],
		}	
	},
	{name = "domain", description = {
		it = [[Parametro usato per comunicare il dominio 
dell'indirizzo email. 
Cos&igrave; facendo si pu&ograve; evitare di aggiungere il mapping a config.lua
per gli account di domini in hosting su aruba.
Esempio: foouser@aruba.it?domain=foodomain]],
		en = [[Parameter is used to override the domain in the email
address.
This is used so that users don't need to add a mapping to config.lua for a 
hosted aruba account.
Example: foouser@aruba.it?domain=foodomain]],
		}	
	},
	{name = "allmsgs", description = {
		it = [[Indica se si devono scaricare tutti i messaggi.
Se il valore &egrave; 1 la funzionalit&agrave; viene attivata.
Esempio: foouser@foodomain?allmsgs=1]],
		en = [[Parameter is used to force plugin to download all 
messages. If the value is 1, the behavior is turned on.
Possible values are onlynew and all.
Example: foouser@foodomain?allmsgs=1]],
		}
	},
	{name = "maxmsgs", description = {
		it = [[Indicare il numero massimo di messaggi da scaricare.
Esempio: foouser@foodomain?maxmsgs=50]],
		en = [[Parameter is used to force the plugin to only
download a maximum number of messages. 
Example: foouser@foodomain?maxmsgs=50]],
		}
	},
}

-- map from lang to strings, like {it="bla bla bla", en = "bla bla bla"}
PLUGIN_DESCRIPTIONS = {
	it=[[Questo plugin consente di scaricare la posta dai domini in hosting su aruba.it.
Per usare questo plugin dovrete usare il vostro indirizzo email completo come 
nome utente e la vostra vera password come password.]],
	en=[[This plugin lets you download mail from domains hosted on aruba.it.
To use this plugin you have to use your full email address as the username
and your real password as the password.]],
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
	b=nil,
	username=nil,
	name=nil,
	domain=nil,
	password=nil,
	session_id=nil,
	folder="Inbox",
	login_done=false,
	stat_done=false,
	allmsgs=false,
	maxmsgs=math.huge,
}

-- ************************************************************************** --
--  strings
-- ************************************************************************** --

-- these are the webmail-dependent strings
--
-- Some of them are incomplete, in the sense that are used as string.format()
-- (read sprintf) arguments, so their %s and %d are filled properly
-- 
-- C, E, G are postfix respectively to Captures (lua string pcre-style 
-- expressions), mlex expressions, mlex get expressions.
-- 
local aruba_string = {
	-- The uri the browser uses when you click the "login" button
	-- login = "http://webmail.%s/cgi-bin/webmail.cgi?cmd=login&selected_tpl=surge%%20_none_&user=%s&pass=%s",
	login = "http://webmaildominiold.aruba.it/cgi-bin/webmail.cgi?cmd=login&selected_tpl=surge%%20_none_&user=%s&pass=%s",
	-- This is the capture to get the session_id from the login-done webpage
	session_id = "utoken=([a-zA-Z0-9%.]+!40[a-zA-Z0-9%.]+!40localhost![%x]+_![%x]+-[%x]+_[%x])",

	-- The uri used by Stat to get the in the list of messages
	-- stat = "http://webmail.%s/cgi-bin/webmail.cgi?cmd=list&selected_tpl=surge%%20_none_&pos=%s&fld=%s&encode_text=fld&utoken=%s",
	stat = "http://webmaildominiold.aruba.it/cgi-bin/webmail.cgi?cmd=reload_mail&selected_tpl=surge%%20_none_&pos=%s&fld=%s&encode_text=fld&utoken=%s",
	-- Pattern used by Stat to get the next page in the list of messages
	stat_next_page = "<a href=\"javascript:G%('list&pos=(%d+)'%)\">Clicca qui per andare alla pagina seguente </a>",
	-- The capture to understand if the session ended
	timeoutC = "Siamo spiacenti non vi siete collegati",
	-- The uri to save a message (read download the message)
	-- save = "http://webmail.%s/cgi-bin/webmail.cgi/email.mail?cmd=msg_save-%d&folder=%s&utoken=%s/email.mail&message_file=true",
	save = "http://webmaildominiold.aruba.it/cgi-bin/webmail.cgi?cmd=msg_save-%d&folder=%s&utoken=%s/email.mail&message_file=true",
	-- The uri and pattern to delete a message
	-- delete = "http://webmail.%s/cgi-bin/webmail.cgi?cmd=delsel&fld=%s&encode_text=fld&utoken=%s",
	delete = "http://webmaildominiold.aruba.it/cgi-bin/webmail.cgi?cmd=delsel&fld=%s&encode_text=fld&utoken=%s",
	delete_next = "&sel_%d=on",

	-- Regular expression to extract the mail data
	statE = ".*<tr.*>.*<td><input.*></td>.*<td>.*</td>.*<td>.*</td>.*<td.*><a class=\"b\".*>.*</a></td>.*<td.*><a.*>.*</a></td>.*<td.*>.*</td>.*<td.*>.*</td>.*<td>.*</td>.*</tr>",
	statAllE = ".*<tr.*>.*<td><input.*></td>.*<td>.*</td>.*<td>.*</td>.*<td.*><a.*>.*</a></td>.*<td.*><a.*>.*</a></td>.*<td.*>.*</td>.*<td.*>.*</td>.*<td>.*</td>.*</tr>",
	statG = "O<O>O<O><X><O>O<O>O<O>O<O>O<O>O<O><O>O<O><O>O<O><O>O<O><O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>",	
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Serialize the internal_state
--
-- serial. serialize is not enough powerful to correcly serialize the 
-- internal state. The field b is the problem. b is an object. This means
-- that it is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the 
-- serial module to know how to serialize this. so we call b:serialize 
-- method by hand hacking a bit on names
--
function serialize_state()
	internal_state.stat_done = false;
	
	return serial.serialize("internal_state",internal_state) ..
		internal_state.b:serialize("internal_state.b")
end


--------------------------------------------------------------------------------
-- The key used to store session info
--
-- This key must be unique for all webmails, since the session pool is one 
-- for all the webmails
--
function key()
	return (internal_state.name or "") ..
		(internal_state.domain or "") ..
		(internal_state.password or "") ..
		(internal_state.folder or "")
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

	require("serial") -- the serialization module
	require("browser") -- the browser module
	require("common") -- the common implementation module
	
	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------
-- Login to the aruba webmaildomini website
--
function aruba_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- shorten names, not really important
	local domain = internal_state.domain
	local username = internal_state.username
	local password = internal_state.password

	-- create the uri to send to
	local uri = string.format(aruba_string.login, username, password)
	local uri_c = string.format(aruba_string.login, username, "********")
	print("login: " .. uri_c)
	
	-- create a new browser and store it
	internal_state.b = browser.new()
	local b = internal_state.b
	--b:verbose_mode() 
	
	-- the functions for do_until
	-- extract_f uses the support function to extract a capture specifyed 
	--   in aruba_string.session_id, and pu ts the result in 
	--   internal_state.session_id
	-- check_f the is the failure funtion, that means that the do_until
	--   will not repeat
	-- retrive_f is the function that do_retrive the uri uri with the
	--   browser b. The function will be retry_n 3 times if it fails
	local check_f = support.check_fail
	local retrive_f = support.retry_n(3, support.do_retrive(b, uri))
	local extract_f = support.do_extract(internal_state, "session_id", aruba_string.session_id) 

	-- maybe implement a do_once
	if not support.do_until(retrive_f, check_f, extract_f) then
		-- not sure that it is a password error, maybe a network error
		-- the do_until will log more about the error before us...
		-- maybe we coud add a sanity_check function to do until to
		-- check if the received page is a server error page or a 
		-- good page.
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end
	
	-- check if do_extract has correctly extracted the session_id
	if internal_state.session_id == nil then
		log.error_print("Login failed, unable to get session_id\n")
		return POPSERVER_ERR_AUTH
	end
		
	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "(" .. 
		"(" .. internal_state.session_id.. ")\n")

	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------
-- The callbach factory for retr
--

function auto_learn(s)
	local correction = ""
	
	local x = string.match(s,"[^\r\n](\r\n)[^\r\n]")
	if x ~= nil then
		-- no correction
		correction = nil
		--print("correnction nil")
	end
	local x = string.match(s,"[^\r\n](\r)[^\r\n]")
	if x ~= nil then
		-- \r -> \r\n 
		correction = "\r"
		--print("correnction \\r")
	end
	local x = string.match(s,"[^\r\n](\n)[^\r\n]")
	if x ~= nil then
		-- \n -> \r\n
		correction = "\n"
		--print("correnction \\n")
	end
	return correction
end

function retr_cb(data)
	local a = stringhack.new()
	local FirstBlock = true

	-- set in the First Block
	local correction = ""
	
	return function(s,len)
		if FirstBlock then
			--try to understand the correction
			correction = auto_learn(s)
						
			if correction ~= nil then
				 s = string.gsub(s,correction,"\r\n")
			end
			
			s = string.gsub(s,"^%s*","")
			FirstBlock = false
		else
			if correction ~= nil then
				 s = string.gsub(s,correction,"\r\n")
			end
		end
		-- may be smarter
		s = string.gsub(s,"\r\r\n","\r\n")
		s = string.gsub(s,"\r\n\n","\r\n")
		s = string.gsub(s,"\n\n","\r\n")
		s = string.gsub(s,"\r\r","\r\n")
		
		s = a:dothack(s).."\0"
		popserver_callback(s,data)
		
		-- dump to file, debug only
		--local f = io.open("dump.txt","a")
		--f:write(s)
		--f:close()
		
		return len,nil
	end
end

-- -------------------------------------------------------------------------- --
-- The callback for top is really similar to the retr, but checks for purging
-- unwanted data and sets globals.lines to -1 if no more lines are needed
--
function top_cb(global,data)
	local purge = false
	local FirstBlock = true
	local correction = ""
	
	return function(s,len)
		if purge == true then
			return len,nil
		end
		
		if FirstBlock then
			correction = auto_learn(s)
			
			s = string.gsub(s,"^%s*","")
			if correction ~= nil then
				 s = string.gsub(s,correction,"\r\n")
			end
			
			FirstBlock = false
		else
			if correction ~= nil then
				 s = string.gsub(s,correction,"\r\n")
			end
		end
		-- may be smarter 
		s = string.gsub(s,"\r\r\n","\r\n")
		s = string.gsub(s,"\r\n\n","\r\n")
		s = string.gsub(s,"\n\n","\r\n")
		s = string.gsub(s,"\r\r","\r\n")
	
		s = global.a:tophack(s,global.lines_requested)
		s = global.a:dothack(s).."\0"
			
		popserver_callback(s,data)

		global.bytes = global.bytes + len

		-- check if we need to stop (in top only)
		if global.a:check_stop(global.lines_requested) then
			purge = true
			global.lines = -1
			if(string.sub(s,-2,-1) ~= "\r\n") then
				popserver_callback("\r\n",data)
			end
			-- trucate it!
			return 0,nil
		else
			global.lines = global.lines_requested - 
				global.a:current_lines()
			return len,nil
		end
	end
end

-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)

	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	local dom = (freepops.MODULE_ARGS or {}).domain or nil
	if dom ~= nil then
		log.say(PLUGIN_NAME .. ": Using overridden domain: " .. dom .. "\r\n")
		domain = dom
	end

	if not user or not domain then
		-- dead code
		return POPSERVER_ERR_AUTH
	end

	internal_state.name = name
	internal_state.domain = domain
	internal_state.username = name .. "@" .. domain
	
	-- Get the folder
	--
	local folder = (freepops.MODULE_ARGS or {}).folder or nil
	if folder ~= nil then
		folder = curl.unescape(folder)
		internal_state.folder = folder
		log.say(PLUGIN_NAME .. ": Using Custom mailbox set to: " .. folder .. "\r\n")
	end

	-- If the flag allmsgs=1 is set, then the plugin download all messages, unread and read ones
	--
	local allmsgs = (freepops.MODULE_ARGS or {}).allmsgs or 0
	if allmsgs == "1" then
		internal_state.allmsgs = true
		log.say(PLUGIN_NAME .. ": Download already read messages: yes.\r\n")
	end

	-- If the flag maxmsgs is set, STAT will limit the number of messages to the flag
	--
	local maxmsgs = (freepops.MODULE_ARGS or {}).maxmsgs or 0
	if tonumber(maxmsgs) > 0 then
		log.say(PLUGIN_NAME .. ": A max of " .. maxmsgs .. " messages will be downloaded.")
		internal_state.maxmsgs = tonumber(maxmsgs)
	end
  
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
			log.say("Session for " .. internal_state.name .. "@" .. 
				internal_state.domain .. "(" .. 
				" is already locked\n")
			return POPSERVER_ERR_LOCKED
		end
	
		-- load the session
		local c,err = loadstring(s)
		if not c then
			log.error_print("Unable to load saved session: "..err)
			return aruba_login()
		end
		
		-- exec the code loaded from the session string
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "(" .. 
			"(" .. internal_state.session_id .. ")\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return aruba_login()
	end
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
	session.unlock(key())
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
	local domain = internal_state.domain
	local folder = internal_state.folder
	local session_id = internal_state.session_id

	local uri = string.format(aruba_string.delete, domain, folder, session_id)

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			uri = uri .. string.format(aruba_string.delete_next, 
				get_mailmessage_uidl(pstate,i))
			delete_something = true	
		end
	end

	if delete_something then
		-- Build the functions for do_until
		local extract_f = function(s) return true,nil end
		local check_f = support.check_fail
		local retrive_f = support.retry_n(3,support.do_retrive(b,uri))

		if not support.do_until(retrive_f,check_f,extract_f) then
			log.error_print("Unable to delete messages\n")
			return POPSERVER_ERR_UNKNOWN
		end
	end

	-- save fails if it is already saved
	session.save(key(),serialize_state(),session.OVERWRITE)
	-- unlock is useless if it have just been saved, but if we save 
	-- without overwriting the session must be unlocked manually 
	-- since it would fail instead overwriting
	session.unlock(key())

	log.say("Session saved for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "(" .. 
		internal_state.session_id .. ")\n")

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end
	
	-- shorten names, not really important
	local b = internal_state.b
	local domain = internal_state.domain
	local folder = internal_state.folder
	local session_id = internal_state.session_id

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later
	local uri = string.format(aruba_string.stat, "1", folder, session_id)
	print("stat: " .. uri)
	
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
		local x
		if internal_state.allmsgs then
			x = mlex.match(s, aruba_string.statAllE, aruba_string.statG)
		else
			x = mlex.match(s, aruba_string.statE, aruba_string.statG)
		end
		--x:print()
		
		-- the number of results
		local n = x:count()

		if n == 0 then
			return true,nil
		end

		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		local nmesg_old = get_popstate_nummesg(pstate)
		local nmesg = nmesg_old

		-- gets all the results and puts them in the popstate structure
		for i = 1,n do
			local _, _, uidl = string.find(x:get(0, i-1), "sel_(%d+)")
			local _, _, size = string.find(x:get(1, i-1), "(%d+)")
			local _, _, size_mult_k = string.find(x:get(1, i-1), "([Kk])")
			local _, _, size_mult_m = string.find(x:get(1, i-1), "([Mm])")

			-- arrange message size
			if size_mult_m ~= nil then
				size = size * 1024 * 1024
			end
			
			if size_mult_k ~= nil then
				size = size * 1024
			end

			if not uidl or not size then
				return nil, "Unable to parse page"
			end

			if nmesg >= internal_state.maxmsgs then 
				-- if a limit was set, stop
				return true 
			else
				-- set it
				nmesg = nmesg + 1
				set_popstate_nummesg(pstate, nmesg)
				set_mailmessage_uidl(pstate, nmesg, uidl)
				set_mailmessage_size(pstate, nmesg, size)
			end
		

			print("uidl: " .. uidl .. " - size " .. size)
		end
		
		return true,nil
	end

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function check_f (s) 
		local _, _, stat_next_page = string.find(s, aruba_string.stat_next_page)

		if stat_next_page == nil then
			return true
		else
			-- change retrive behaviour
			uri = string.format(aruba_string.stat, stat_next_page, folder, session_id)
			-- continue the loop
			return false
		end
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		local f,err = b:get_uri(uri)
		if f == nil then
			return f,err
		end
		--print(f)
		
		local c = string.match(f, aruba_string.timeoutC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = aruba_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,--{
					--error=
					"Session ended,unable to recover"
					--} hope it is ok now
			end
			
			b = internal_state.b
			folder = internal_state.folder
			session_id = internal_state.session_id
			
			uri = string.format(aruba_string.stat, "1", folder, session_id)
			return b:get_uri(uri)
		end
		
		return f,err
	end

	-- initialize the data structure
	set_popstate_nummesg(pstate,0)

	-- do it
	if not support.do_until(retrive_f,check_f,action_f) then
		log.error_print("Stat failed\n")
		session.remove(key())
		return POPSERVER_ERR_UNKNOWN
	end

	-- save the computed values
	internal_state.stat_done= true
	
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
-- Unflag each message marked for deletion
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
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- some local stuff
	local b = internal_state.b
	local domain = internal_state.domain
	local folder = internal_state.folder
	local session_id = internal_state.session_id
	local size = get_mailmessage_size(pstate,msg)

	-- build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(aruba_string.save, uidl, folder, session_id)

	-- build the callbacks --
	
	-- this data structure is shared between callbacks
	local global = {
		-- the current amount of lines to go!
		lines = lines, 
		-- the original amount of lines requested
		lines_requested = lines, 
		-- how many bytes we have received
		bytes = 0,
		total_bytes = tot_bytes,
		-- the stringhack (must survive the callback, since the 
		-- callback doesn't know when it must be destroyed)
		a = stringhack.new(),
		-- the first byte
		from = 0,
		-- the last byte
		to = 0,
		-- the minimum amount of bytes we receive 
		-- (compensates the mail header usually)
		base = 2048,
	}
	-- the callback for http stram
	local cb = top_cb(global,data,truncate)
	-- retrive must retrive from-to bytes, stores from and to in globals.
	local retrive_f = function()
		global.to = global.base + global.from + (global.lines + 1) * 100
		global.base = 0
		local extra_header = {
			"Range: bytes="..global.from.."-"..global.to
		}
		local f,err = b:pipe_uri(uri,cb,extra_header)
		global.from = global.to + 1
		--if f == nil --and rc.error == "EOF" 
		--	then
		--	return "",nil
		--end
		return f,err
	end
	-- global.lines = -1 means we are done!
	local check_f = function(_)
		return global.lines < 0 or global.bytes >= global.total_bytes
	end
	-- nothing to do
	local action_f = function(_)
		return true
	end

	-- go! 
	if not support.do_until(retrive_f,check_f,action_f) and 
	   not truncate then
		log.error_print("Top failed\n")
		-- don't remember if this should be done
		--session.remove(key())
		return POPSERVER_ERR_UNKNOWN
	end

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- the callback
	local cb = retr_cb(data)
	
	-- some local stuff
	local b = internal_state.b
	local domain = internal_state.domain
	local folder = internal_state.folder
	local session_id = internal_state.session_id
	
	-- build the uri
	local uidl = get_mailmessage_uidl(pstate, msg)
	local uri = string.format(aruba_string.save, uidl, folder, session_id)
	
	-- tell the browser to pipe the uri using cb
	local f,rc = b:pipe_uri(uri, cb)

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