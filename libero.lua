-- --------------------------- READ THIS PLEASE ----------------------------- --
-- This file is not only the libero webmail plugin. It is also a well 
-- documented example of webmail plugin. 
--
-- Before reading this you should learn something about lua. The lua 
-- language is an excellent (at least in my opinion), small and easy 
-- language. You can learn something at http://www.lua.org (the main website)
-- or at http://lua-users.org/wiki/TutorialDirectory (a good and short tutorial)
--
-- Feel free to contact the author if you have problems in understanding 
-- this file
--
-- To start writing a new plugin please use skeleton.lua as the base.
-- -------------------------------------------------------------------------- --


-- ************************************************************************** --
--  FreePOPs @libero.it, @inwind.it, @blu.it, @iol.it webmail interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function and by the website, 
-- fill them in the right way

-- single string, all required
PLUGIN_VERSION = "0.2.30"
PLUGIN_NAME = "Libero.IT"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=libero.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"

-- list of strings, one required, one contact for each author
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge (at) users (.) sourceforge (.) net"}

-- list of strings, one required
PLUGIN_DOMAINS = {"@libero.it","@inwind.it","@iol.it","@blu.it"}

-- list of tables with fields name and description. 
-- description must be in the stle of PLUGIN_DESCRIPTIONS,
-- so something like {it="bla bla bla", en = "bla bla bla"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		it = [[
Serve per selezionare la cartella (inbox &egrave; quella di default)
su cui operare. 
Le cartelle standard disponibili sono draft, inbox, outbox, trash.
Se hai creato delle cartelle dalla webmail allora puoi accedervi usando il
loro nome. Se la cartella non &egrave; al livello principale
puoi accederci usando 
una / per separala dalla cartella padre. Questo &egrave; un esempio di uno
user name per leggere la cartella son, che &egrave;
una sotto cartella della cartella
father: foo@libero.it?folder=father/son]],
		}	
	},
}

-- map from lang to strings, like {it="bla bla bla", en = "bla bla bla"}
PLUGIN_DESCRIPTIONS = {
	it="Questo plugin &egrave; per gli account di "..
	   "posta del portale libero.it. "..
	   "Utilizzare lo username completo di dominio e l'usuale password. ",
	en="This plugin is for italian users only."
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
local libero_string = {
	-- The uri the browser uses when you click the "login" button
	login_pre = "https://login.libero.it",
	login_url = "https://login.libero.it/logincheck.php",
	login_post = "LOGINID=%s&PASSWORD=%s"..
		"&SERVICE_ID=beta_email&RET_URL=http://mailbeta.libero.it/cp/WindMailPS.jsp",
	-- This is the capture to get the session ID from the login-done webpage
	sessionC = "<[i]?frame name=\"main\" id=\"main\" src=\"(.-)\"",
	-- This is the mlex expression to interpret the message list page.
	-- Read the mlex C module documentation to understand the meaning
	--
	-- This is probably one of the more boaring tasks of the story.
	-- An easy and not so boring way of writing a mlex expression is
	-- to cut and paste the html source and work on it. For example
	-- you could copy a message table row in a blank file, substitute
	-- every useless field with '.*'.
	 
	--statE = ".*<a.*doitMsg.*>[.*]{!--.*--}.*<script>.*IMGEv.*</script>.*</a>.*<script>.*AEv.*</script>[.*]{!--.*--}.*<script>.*</script>.*</a>.*</TD>.*<TD>.*<div>.*</TD>.*<TD>.*<script>.*</script>[.*]{!--.*--}.*<script>.*</script>.*</a>.*</TD>.*<TD>.*<div>.*</TD>.*<script>.*</script>[.*]{b}.*{/b}[.*]</TD>[.*]{!--.*--}.*<TD>.*<div>.*</TD>.*<script>.*</script>[.*]{b}.*{/b}[.*]</TD>[.*]{!--.*--}.*</TR>";
	statE = ".*<tr.*uid.*from.*>.*<td.*>.*<input.*>.*<td.*>.*<td.*>.*<td.*>.*<td>.*<td>.*<td.*>.*</tr>";
	statEAltOld = ".*<tr.*uid.*from.*>.*<td.*>.*<div.*>.*<input.*>.*</div>.*<td.*>.*<img.*>.*<img.*>.*<td.*>.*<span>.*</span><br>.*<td><nobr>.*</nobr>.*<td.*>.*<img.*>.*<td.*>.*<span>.*</span>.*<span.*>.*</span>.*<td.*>.*<img.*>.*</tr>";
	statEAlt = ".*<tr.*id.*uid.*from.*>";
	
	-- This is the mlex get expression to choose the important fields 
	-- of the message list page. Used in combination with statE
	
	--statG = "O<X>[O]{O}O<O>O<O>O<O>O<O>O<O>[O]{O}O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>[O]{O}O<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>[O]{O}O<O>";
	statG = "O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>";
	statGAltOld = "O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>";
	statGAlt = "O<X>";
	
	-- The uri for the first page with the list of messages
	first = "http://%s/cp/ps/Mail/commands/SyncFolder?d=%s&u=%s&t=%s",
	firstpost = "accountName=DefaultMailAccount&folderPath=%s&listPosition=%s"..
			"&sortColumn=SendDateVal&sortDirection=Desc",
	-- The capture to check if there is one more page of message list
	next_checkC = "lastPage:.-([%+%-]?%d+)",
	-- The capture to understand if the session ended
	timeoutC = "(<title>Libero - Login</title>)",
	-- The uri to save a message (read download the message)
	save = "http://%s/cp/ps/Main/Downloader/message.eml?uid=%s"..
		"&d=%s&u=%s&ai=-1&t=%s&c=yes&an=DefaultMailAccount"..
		"&disposition=attachment&fp=%s&dhid=mailDownloader",
	-- The uri to delete some messages
	delete = "http://%s/cp/ps/Mail/commands/DeleteMessage?d=%s&u=%s&t=%s",
	trash = "http://%s/cp/ps/Mail/commands/EmptyFolder?d=%s&u=%s&t=%s"..
		"&an=DefaultMailAccount&fp=trash&recursive=true"
}


-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
	stat_done = false,
	login_done = false,
	session_id = nil,
	server_number = nil,
	domain = nil,
	name = nil,
	password = nil,
	b = nil,
	newMail = false
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Checks if a message number is in range
--
function check_range(pstate,msg)
	local n = get_popstate_nummesg(pstate)
	return msg >= 1 and msg <= n
end

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
	return (internal_state.name or "")..
		(internal_state.domain or "")..
		(internal_state.password or "")..
		(internal_state.folder or "")
end

--------------------------------------------------------------------------------
-- Login to the libero website
--

function libero_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	local user = internal_state.name
	local uri = libero_string.login_url
        log.dbg("Using webserver " .. uri);
	local post= string.format(libero_string.login_post,
		user .. "@" .. domain,password)

	-- the browser must be preserved
	internal_state.b = browser.new()
	local b = internal_state.b
	--b:verbose_mode()
	b:ssl_init_stuff()

	-- load some cookies
	
	-- the functions for do_until
	-- extract_f uses the support function to extract a capture specifyed 
	--   in libero_string.sessionC, and puts the result in 
	--   internal_state["session_id"]
	-- check_f the is the failure funtion, that means that the do_until
	--   will not repeat
	-- retrive_f is the function that do_retrive the uri uri with the
	--   browser b. The function will be retry_n 3 times if it fails
	
	local extract_f = function(s) return true,nil end
	local check_f = support.check_fail
	local retrive_f = support.retry_n(3,support.do_retrive(
		internal_state.b,libero_string.login_pre))

	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Unable to init\n")
		return POPSERVER_ERR_UNKNOWN
	end
	
	retrive_f = support.retry_n(
		3,support.do_post(internal_state.b,uri,post))
	check_f = support.check_fail
	extract_f = support.do_extract(
		internal_state,"session_id",libero_string.sessionC)	

	-- maybe implement a do_once
	if not support.do_until(retrive_f,check_f,extract_f) then
		-- not sure that it is a password error, maybe a network error
		-- the do_until will log more about the error before us...
		-- maybe we coud add a sanity_check function to do until to
		-- check if the received page is a server error page or a 
		-- good page.
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end
	
	local dummy_state = {dummy_string = nil}
	
	extract_f = support.do_extract(
		dummy_state,"dummy_string",".*")
	check_f = support.check_fail
	--"internal_state.session_id" -> Url to retrieve
	retrive_f = support.retry_n(3,support.do_retrive(b,internal_state.session_id))

	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Unable to redirect\n")
		return POPSERVER_ERR_UNKNOWN
	end
	
	dummy_state["dummy_string"] = string.match(dummy_state.dummy_string,"<!DOCTYPE html>")
	
	if dummy_state.dummy_string ~= nil then
		internal_state["newMail"] = true
	end
	
	internal_state["server_number"] = string.match(
		internal_state.session_id,"([a-z]-%d+[a-z]?%.[a-z]-%.libero%.it)")
	internal_state["session_id"] = string.match(internal_state.session_id,"t=([a-z0-9]+)")

	-- check if do_extract has correctly extracted the session ID
	if internal_state.session_id == nil then
		log.error_print("Login failed, unable to get session ID\n")
		return POPSERVER_ERR_AUTH
	end
	if internal_state.server_number == nil then
		log.error_print("Login failed, unable to get server number\n")
		return POPSERVER_ERR_AUTH
	end
	
	-- save all the computed data
	internal_state.login_done = true
	
	 --log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. 
		"(" .. internal_state.session_id ..","..internal_state.server_number.. ")\n")
		
	return POPSERVER_ERR_OK
end

-- ************************************************************************** --
--  Libero functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	-- default is @libero.it (probably useless)
	if not domain then
		-- default domain
		domain = "libero.it"
	end

	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name
	local f = (freepops.MODULE_ARGS or {}).folder or "inbox"
	local f64 = base64.encode(f)
	local f64u = base64.encode(string.upper(f))
	internal_state.folder = f 
	internal_state.folder_uppercase = f64u
	
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
			log.say("Session for "..internal_state.name..
				" is already locked\n")
			return POPSERVER_ERR_LOCKED
		end
	
		-- load the session
		local c,err = loadstring(s)
		if not c then
			log.error_print("Unable to load saved session: "..err)
			return libero_login()
		end
		
		-- exec the code loaded from the session string
		c()


		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. 
			"(" .. internal_state.session_id .. ","..internal_state.server_number..")\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return libero_login()
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
	local popserver = internal_state.server_number
	local domain = internal_state.domain
	local user = internal_state.name
	local session_id = internal_state.session_id
	local b = internal_state.b

	local uri = string.format(libero_string.delete,popserver,domain,
		user,session_id)
	local post = "selection="

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.match(
				get_mailmessage_uidl(pstate,i),";([0-9a-f]+)")..","
			delete_something = true	
		end
	end

	if delete_something then
		-- Build the functions for do_until
		local extract_f = function(s) return true,nil end
		local check_f = support.check_fail
		local retrive_f = support.retry_n(3,support.do_post(b,uri,post))

		if not support.do_until(retrive_f,check_f,extract_f) then
			log.error_print("Unable to delete messages\n")
			return POPSERVER_ERR_UNKNOWN
		end
		
		uri = string.format(libero_string.trash,popserver,domain,user,session_id)
		
		local extract_f = function(s) return true,nil end
		local check_f = support.check_fail
		local retrive_f = support.retry_n(3,support.do_retrive(b,uri))

		if not support.do_until(retrive_f,check_f,extract_f) then
			log.error_print("Unable to empty trash\n")
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
		internal_state.domain .. 
		"(" .. internal_state.session_id ..","..internal_state.server_number.. ")\n")

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
	local popserver = internal_state.server_number
	local domain = internal_state.domain
	local user = internal_state.name
	local session_id = internal_state.session_id
	local b = internal_state.b
	local msgpoint = 1

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later
	local uri = string.format(libero_string.first,popserver,domain,user,session_id)
	local post = string.format(libero_string.firstpost,internal_state.folder,msgpoint)

	--this is temporary solution to retrive message sizes
	local sizes = {}
	local page = 1
	local sGet = "http://m.mailbeta.libero.it/m/wmm/folder/INBOX/%s"
	local sUri = string.format(sGet,page)
	
	if internal_state.newMail == true then
	local function action_s (s)
		local x = mlex.match(s,"<div.*row_mail_date.*>.*</div>","<O>X<O>")
		local n = x:count()
		if n == 0 then
			return true,nil
		end
		for i = 0,n-1 do
			local size = x:get (0,i)
			-- arrange message size
			local k,m = nil
			k = string.match(size,"([Kk][Bb])")
			m = string.match(size,"([Mm][Bb])")
			size = string.match(size,"- (%d+%.?%d*)")
			size = tonumber(size)
			if k ~= nil then
				size = size * 1024
			elseif m ~= nil then
				size = size * 1024 * 1024
			end
			if not size then
				return nil,"Unable to parse size"
			end
			sizes[i+1+15*(page-1)] = size
		end
		return true,nil
	end

	local function check_s (s)
		local tmp1 = string.match(s,"<img src=.*/wmm/img/ico_next_off.*png")
		if tmp1 == nil then
			page = page + 1
			sUri = string.format(sGet,page)
			return false
		else
			return true
		end
	end
	
	local function retrive_s ()
		local f,err = b:get_uri(sUri)
		if f == nil then
			return f,err
		end
		local c = string.match(f,libero_string.timeoutC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = libero_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,--{
					--error=
					"Session ended,unable to recover"
					--} hope it is ok now
			end
			return b:get_uri(sUri)
		end
		return f,err
	end
	
	if not support.do_until(retrive_s,check_s,action_s) then
		log.error_print("Stat sizes failed\n")
		session.remove(key())
		return POPSERVER_ERR_UNKNOWN
	end
	end

	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
		--print(s)
		--local temp = string.gsub(s,"<tr","</tr><tr")
		--temp = string.gsub(temp,"</tbody>","</tr></tbody>")
		local x
		if internal_state.newMail == true then
			x = mlex.match(s,libero_string.statEAlt,libero_string.statGAlt)
		else
			x = mlex.match(s,libero_string.statE,libero_string.statG)
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
		local nmesg = nmesg_old + n
		set_popstate_nummesg(pstate,nmesg)

		-- gets all the results and puts them in the popstate structure
		for i = 0,n-1 do
			local uidl = x:get (0,i)
			uidl = string.match(uidl,"uid=\"(%d+)\"")..";"..string.match(
					uidl,"id=\"([0-9a-f]+)\"")
			local size
			if internal_state.newMail == true then
				--local param = string.match(uidl,"(%d+);")
				--local uri = string.format(libero_string.save,popserver,param,
				--	domain,user,session_id,internal_state.folder)
				--local array = {size = nil}
				--local retrive_f = support.retry_n(
				--	3,support.do_retrive(internal_state.b,uri))
				--local check_f = support.check_fail
				--local extract_f = support.do_extract(
				--	array,"size",".*")	
				--if not support.do_until(retrive_f,check_f,extract_f) then
				--	log.error_print("Unable to retrieve message size\n")
				--	return POPSERVER_ERR_NETWORK
				--end
				--size = array.size:len()
				size=sizes[i+1+nmesg_old]
			else
				size = x:get (1,i)
			-- arrange message size
				local k,m = nil
				k = string.match(size,"([Kk][Bb])")
				m = string.match(size,"([Mm][Bb])")
				size = string.match(size,"(%d+%.?%d*)")
				size = tonumber(size) -- + 2
				if k ~= nil then
					size = size * 1024
				elseif m ~= nil then
					size = size * 1024 * 1024
				end
			end
			
				

			if not uidl or not size then
				return nil,"Unable to parse page"
			end

			-- set it
			set_mailmessage_size(pstate,i+1+nmesg_old,size)
			set_mailmessage_uidl(pstate,i+1+nmesg_old,uidl)
		end
		
		return true,nil
	end

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function check_f (s)  
		local tmp1 = tonumber(string.match(s,libero_string.next_checkC))
		local tmp2 = tonumber(string.match(s,"currentPage:.-(%d+)"))
		local tmp3 = tonumber(string.match(s,"numberToShow:.-(%d+)"))
		
		if tmp1 > tmp2 then
			-- change retrive behaviour
			msgpoint = msgpoint+tmp3
			post = string.format(libero_string.firstpost,internal_state.folder,msgpoint)
			-- continue the loop
			return false
		else
			return true
		end
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		local f,err = b:post_uri(uri,post)
		if f == nil then
			return f,err
		end

		local c = string.match(f,libero_string.timeoutC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = libero_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,--{
					--error=
					"Session ended,unable to recover"
					--} hope it is ok now
			end
			
			popserver = internal_state.server_number
			session_id = internal_state.session_id
			b = internal_state.b
			
			uri = string.format(libero_string.first,popserver,domain,user,session_id)
			return b:post_uri(uri,post)
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
	internal_state["stat_done"] = true
	
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
function retr(pstate,msg,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- the callback
	local cb = common.retr_cb(data)
	
	-- some local stuff
	local popserver = internal_state.server_number
	local domain = internal_state.domain
	local user = internal_state.name
	local session_id = internal_state.session_id
	local b = internal_state.b
	
	-- build the uri
	local uidl = string.match(get_mailmessage_uidl(pstate,msg),"(%d+);")
	local uri = string.format(libero_string.save,popserver,uidl,
		domain,user,session_id,internal_state.folder)
	
	-- tell the browser to pipe the uri using cb
	local f,rc = b:pipe_uri(uri,cb)

	if not f then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		-- don't remember if this should be done
		--session.remove(key())
		return POPSERVER_ERR_NETWORK
	end

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- some local stuff
	local popserver = internal_state.server_number
	local domain = internal_state.domain
	local user = internal_state.name
	local session_id = internal_state.session_id
	local b = internal_state.b
	local size = get_mailmessage_size(pstate,msg)

	-- build the uri
	local uidl = string.match(get_mailmessage_uidl(pstate,msg),"(%d+);")
	local uri = string.format(libero_string.save,popserver,uidl,
		domain,user,session_id,internal_state.folder)

	return common.top(b,uri,key(),size,lines,data,false)
end

-- -------------------------------------------------------------------------- --
--  This function is called to initialize the plugin.
--  Since we need to use the browser and save sessions we have to use
--  some modules with the dofile function
--
--  We also export the pop3server.* names to global environment so we can
--  write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
--  
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

-- EOF
-- ************************************************************************** --
