-- ************************************************************************** --
--  FreePOPs @gmail.com webmail interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Rami Kattan <rkattan at gmail (single dot) com>
--  Revised by EoinK <eoin.pops at gmail (single dot) com>
--  Revised by Tommaso Colombo <zibo86 at hotmail (single dot) com>
--  Incorporating jbobowski fix posted 26 April 2006
--  Incorporating lowang fix posted 25 Aug 2006
--  Incorporating eoin fix posted 11 Jan 2008
--
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.55"
PLUGIN_NAME    = "GMail.com"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL	= "http://www.freepops.org/download.php?module=gmail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Rami Kattan", "EoinK"}
PLUGIN_AUTHORS_CONTACTS = {"rkattan (at) gmail (.) com", "eoin.pops (at) gmail (.) com"}
PLUGIN_DOMAINS = {"@gmail.com"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		it = [[
Serve per selezionare la cartella (inbox &egrave; quella di default)
su cui operare.<br/>
Le cartelle standard disponibili sono inbox, starred, sent, all, spam, trash.
Questo &egrave; un esempio di uno user name per leggere la cartella starred:<br/>
foo@gmail.com?folder=starred<br/>
<br/>
Se hai creato delle label personalizzate, puoi accedervi usando il parametro ?label=nome]],
		en = [[
Used for selecting the folder to operate on (inbox is the default one).<br/>
The standard folders are: inbox, starred, sent, all, spam, trash.<br/>
Here is an example of a username to get the email from the starred folder:<br/>
foo@gmail.com?folder=starred<br/>
<br/>
If you created custom labels in gmail, you can access them using
the label parameter label=name.]],
		}	
	},
	{name = "maxmsgs", description = {
		en = [[
Parameter is used to force the plugin to only download a maximum number of messages. ]]
		}	
	},
	{name = "enableimap", description = {
		en = [[
Parameter is used to turn on IMAP for the account.  If set to 1, the plugin will enable IMAP access on
the user's account during the QUIT command. ]]
		}	
	},
	{name = "enableforward", description = {
		en = [[
Parameter is turn on forwarding for the account.  If set with an email address, the settings will be updated
to enable the user's settings to forward messages to the supplied address. ]]
		}	
	},
	{name = "label", description = {
		it = [[
Serve per selezionare la label su cui operare.<br/>
Questo &egrave; un esempio di uno user name per leggere la 
cartella personalizzata Amici:<br/>
foo@gmail.com?label=amici]],
		en = [[
Used for selecting the labels to operate on.<br/>
Here is an example of a username to get the email from the label Friends:<br/>
foo@gmail.com?label=Friends]],
		}	
	},
	{name = "act", description = {
		it = [[
Valori possibili:<br/>
- export: esporta la rubrica di gmail in un file chiamato 
gmail_contacts_export.csv che verr&agrave; generato nella vostra home (Unix)
o nella directory Documenti (Windows), 
che pu&ograve; essere importato nel vostro mail client preferito.]],
		en = [[
Possible values:<br/>
- export: Exports your gmail contacts into a file called 
gmail_contacts_export.csv that will be saved in your home (Unix)
or in the My Documents directory (Windows), that can be imported 
into your email client.]],
		}
	},
}
PLUGIN_DESCRIPTIONS = {
	it=[[
Questo plugin vi permette di leggere le mail che avete in una 
mailbox @gmail.com.<br/>
Per usare questo plugin dovete usare il vostro indirizzo email completo come
user name e la vostra password reale come password.<br/>
Aggiungendo dei parametri allo username si pu&ograve; scaricare la posta dalle diverse
cartelle o label, ed anche esportare la rubrica in formato CSV.<br/>
Controllare la sezione &quot;Parametri supportati&quot; per maggiore informazione sui
parametri disponibili.<br/>
<br/>
Nota:<br/>
Quando il client di posta cancella dei messaggi (perche &egrave; stato configurato per
cancellare i messaggi dal server [dopo x giorni]), se avete controllato la cartella inbox
i messaggi saranno spostati nell'archivio (cartella "all"), se avete controllato la cartella
spam i messaggi saranno spostati nel cestino (cartella "trash"), altrimenti saranno solo segnati come letti.]],
	en=[[
This is the webmail support for @gmail.com mailboxes.<br/>
To use this plugin you have to use your full email address as the user name 
and your real password as the password.<br/>
Adding some parameters at the end of the username gives the ability to download
email from different folder and/or labels, and export the contacts in CSV format.
Check "Supported parameters" for more details about the available parameters.<br/>
<br/>
Note:<br/>
When the email client issues the command to delete some messages (because in its
options it is set to delete messages from the server [after x days]), if checked the
inbox folder, the email will be moved to the archive (folder "all"), while if you checked the
spam folder, the email will be moved to the trash folder, else it will only be marked
as read.]]
}

-- ************************************************************************** --
--  strings
-- ************************************************************************** --

-- this are the webmail-dependent strings
--
-- Some of them are incomplete, in the sense that are used as string.format()
-- (read sprintf) arguments, so theyr %s and %d are filled properly
-- 
local globals = {
	-- The uri the browser uses when you click the "login" button
	strLoginUrl = "https://www.google.com/accounts/ServiceLogin",
	strAuthUrl = "https://www.google.com/accounts/ServiceLoginAuth",
	strAuthPostData = "continue=https%%3A%%2F%%2Fmail.google.com%%2Fmail%%3Fui%%3Dhtml%%26zy%%3Dl&"..
			"service=mail&Email=%s&Passwd=%s&null=Sign%%20in&rmShown=1&rm=false&ltmplcache=2&ltmpl=yj_wsad&PersistentCookie=yes&ui=1",
	strLoginCheckcookie_TODO ="https://www.google.com/accounts/CheckCookie?"..
			"continue=http%3A%2F%2Fmail.google.com%2Fmail&"..
			"service=mail&chtml=LoginDoneHtml&ui=1",
	strLoginFailed = "(Username and password do not match)",
	strIDKeyPattern = 'var GLOBALS=%[,,"[^"]+","[^"]+","[^"]+","[^"]+","[^"]+","[^"]+",%d+,"([^"]+)",',

	strHomepage = "http://mail.google.com/mail",

	strViewMessage = "http://mail.google.com/mail?view=om&th=%s&zx=%s&ui=1",
	-- message list (regexp)

	-- strMessageListRegExp = ',%["(%w-)",(%d),(%d),".-","([^"]-)",.-%d%]\n',
	strMessageListRegExp = ',%["(%w-)",(%d),(%d),".-","(.-)",".-",".-",%[',

	-- next 2 lines: link to view a message in html format,
	-- and regexp to extract sub messages.
	strMessageThreadUrl = "http://mail.google.com/mail?"..
		"view=cv&search=%s&th=%s&zx=%s&ui=1",
	strMessageThreadRegExp = 
		'\nD%(%["mi",%d+,%d+,"(%w-)",(%d+),.-,".-",".-","(.-)".-%]\n%);',

	-- This is the capture to get the session ID from the login-done webpage
	strCookieVal = 'cookieVal= "(%w*%-%w*)"',

	-- The uri for the first page with the list of messages
	strCmdMsgList = "http://mail.google.com/mail?"..
		"search=%s&view=tl&start=%s&init=1&zx=%s&ui=1",
	strCmdMsgListChkNext = '\nD%(%["ts",(%d+),(%d+),(%d+),%d.-%]\n%);',

	strCmdMarkMsgUrl = "http://mail.google.com/mail?search=%s&view=tl&start=0&ui=1",
	-- The piece of uri you must append to delete to choose the messages 
	-- to delete
	strCmdMarkMsgPostData = "act=%s&at=%s",
	strCmdMarkMsgNext = "&t=%s",
	
	-- Set account to enable IMAP
	--
	strCmdImapEnable = "http://mail.google.com/mail?ui=2&at=%s&view=up&act=prefs&zx=%s&ik=%s",
	strCmdImapEnablePost = "p_bx_ie=1",
	strSuccessSettingChanged = 'D%(%["a",1,"Your preferences have been saved%."%]',
	
	-- Set account to enable forwarding
	--
	strCmdForwardingEnablePost = "p_sx_em=", 
	
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
	bStatDone = false,
	bLoginDone = false,
	bEnableIMAP = false,
	strUserName = nil,
	strPassword = nil,
	strFolder = nil,
	strActions = nil,
	brBrowser = nil,
	strCookieVal = nil,
	strCookieSID = nil,
	strIDKey = nil,
	statLimit = nil,
	strGmailAt = "",
	strForwardAddress = nil,
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
-- Generates a random number to be added to URLs to avoid caching
--
function RandNum()
	return math.random(0, 1000000000)
end

--------------------------------------------------------------------------------
-- we don't want to break the webmail
--
function check_sanity(name,pass)
	if string.len(name) < 6 or string.len(name) > 30 then
		log.error_print("username must be from 6 to 30 chars")
		return false
	end
	local x = string.match(name,"([^0-9A-Za-z%.%_%-])")
	if x ~= nil then
		log.error_print("username contains invalid character "..x.."\n")
		return false
	end	
	if string.len(pass) < 6 or string.len(pass) > 24 then
		log.error_print("password must be from 6 to 24 chars")
		return false
	end
	local x = string.match(pass,"[^0-9A-Za-z%.%_%-������]")
	if x ~= nil then
		log.error_print("password contains invalid character "..x.."\n")
		return false
	end
	return true
end

function toGMT(d)
	log.say("FIXME: GMT time conversion")
	return os.date("%c",d)
end

function mk_cookie(name,val,expires,path,domain,secure)
	local s = name .. "=" .. val
	if expires then
		s = s .. ";expires=" .. toGMT(expires)
	end
	if path then
		s = s .. ";path=" .. path
	end
	if domain then
		s = s .. ";domain=" .. domain
	end
	if secure then
		s = s .. ";secure"
	end
	return s
end

--------------------------------------------------------------------------------
-- Serialize the internal_state
--
-- serial. serialize is not enough powerfull to correcly serialize the 
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the 
-- serial module to know how to serialize this. so we call b:serialize 
-- method by hand hacking a bit on names
--
function serialize_state()
	internal_state.bStatDone = false;
	
	return serial.serialize("internal_state",internal_state) ..
		internal_state.brBrowser:serialize("internal_state.brBrowser")
end

--------------------------------------------------------------------------------
-- The key used to store session info
--
-- Ths key must be unique for all webmails, since the session pool is one 
-- for all the webmails
--
function key()
	return (internal_state.strUserName or "")..
		("gmail.com")..
		internal_state.strPassword.. -- this asserts strPassword ~= nil
		(internal_state.strFolder or "")..
		(internal_state.strActions or "") .. 
		tostring(internal_state.bEnableIMAP)
end

--------------------------------------------------------------------------------
-- Login to the gmail website
--
function gmail_login()
	if internal_state.bLoginDone then
		return POPSERVER_ERR_OK
	end

	-- Build the login URI and its post data
	-- 
	local password = internal_state.strPassword
	local username = internal_state.strUserName
	local uri = globals.strAuthUrl
	local post = string.format(globals.strAuthPostData,
					username, curl.escape(password))

	-- The browser must be preserved
	internal_state.brBrowser = browser.new()
	local b = internal_state.brBrowser

	-- b:verbose_mode()
	b:ssl_init_stuff()


	-- Connect to gmail login page
	-- 
	local body, err = b:get_uri(globals.strLoginUrl)
	
	-- Find the appropriate GALX value
	local str = string.find(body, "GALX")
	if str ~= nil then
		body = string.sub(body, str)
		local i,j = string.find(body, "value=")
		local GALX = string.sub(body, j+2, j+12)
		post = post .. "&GALX=" .. GALX
		log.dbg("Found GALX value: " .. GALX)
    else
	    log.dbg("Unable to find GALX value.  Login will probably fail.")
	end
	
	-- Connect to gmail auth page
	-- 
	local body, err = b:post_uri(uri, post)
	-- print(body)
	
	-- Checks for login
	-- 
	if body == nil then
		log.error_print(err)
		return POPSERVER_ERR_UNKNOWN
	end

	--
	-- Check for invalid password
	-- 
	local str = string.match(body, globals.strLoginFailed)
	if str ~= nil then
		log.error_print("Login Failed: Invalid Password")
		return POPSERVER_ERR_AUTH
	end

	local str = string.find(body, "<title>Redirecting</title>")
	if str ~= nil then
		body = string.gsub(body, "&#39;", "'")
		local i,j=string.find(body, "url='")
        local k,l=string.find(body, "'\"></head>")
		local URL = string.sub(body,j+1,k-1)
		URL = string.gsub(URL, "&amp;", "&")
		local body2, err2 = b:get_uri(URL)
	end	
	
	-- Extract cookie values
	-- 
	internal_state.strCookieSID = (b:get_cookie("SID")).value
	internal_state.strCookieVal = (b:get_cookie("GX")).value
	
	-- Get the ID Key
	--
	body, err = b:get_uri(globals.strHomepage)
	str = string.match(body, globals.strIDKeyPattern)
	if (str == nil) then
		log.error_print("GMail: Unable to retrieve IDKey.  This will cause issues with IMAP settings toggle.")
	else
		internal_state.strIDKey = str
	end

	-- Save all the computed data
	internal_state.bLoginDone = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.strUserName .. 
		"@gmail.com " .. "(" .. internal_state.strCookieVal .. ")\n")
		
		
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

-- ************************************************************************** --
--  gmail functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	local name = freepops.get_name(username)
	local folder = ""

	internal_state.strUserName = name
	folder = freepops.MODULE_ARGS.folder or "inbox"
	if freepops.MODULE_ARGS.label then
		folder = "cat&cat=" .. freepops.MODULE_ARGS.label
	end
	internal_state.strFolder = folder
	internal_state.strActions = freepops.MODULE_ARGS.act or ""
	internal_state.bEnableIMAP = freepops.MODULE_ARGS.enableimap == "1" or false
	internal_state.strForwardAddress = freepops.MODULE_ARGS.enableforward

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	-- save the password
	internal_state.strPassword = password

	-- check if the domain is valid
	if not check_sanity(internal_state.strUserName,
			internal_state.strPassword) then
		return POPSERVER_ERR_AUTH
	end

	-- eventually load session
	local s = session.load_lock(key())

 	-- check if loaded properly
	if s ~= nil then
		-- "\a" means locked
		if s == "\a" then
			log.say("Session for "..internal_state.strUserName..
				" is already locked\n")
			return POPSERVER_ERR_LOCKED
		end
	
		-- load the session
		local c,err = loadstring(s)
		if not c then
			log.error_print("Unable to load saved session: "..err)
			return gmail_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.strUserName ..
			"@gmail.com " .. 
			"(" .. internal_state.strCookieVal .. ")\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return gmail_login()
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

	local b = internal_state.brBrowser
	local folder = internal_state.strFolder

	local Gmail_at = internal_state.strGmailAt

	-- Enable Imap
	--
	if (internal_state.bEnableIMAP) then
		log.dbg("Enabling IMAP")
		local str = string.format(globals.strCmdImapEnable, Gmail_at, RandNum(), 
			internal_state.strIDKey)
		local body, err = b:post_uri(str, globals.strCmdImapEnablePost)
	end
	
	-- Enable forwarding
	--
	if (internal_state.strForwardAddress ~= nil) then
		log.dbg("Enabling Forwarding")
		local str = string.format(globals.strCmdImapEnable, Gmail_at, RandNum(), 
			internal_state.strIDKey)
		local body, err = b:post_uri(str, globals.strCmdForwardingEnablePost .. internal_state.strForwardAddress)
	end
	
	
	local uri = string.format(globals.strCmdMarkMsgUrl, folder)
	--	    act = [rd|ur|rc_^i|tr]
	--		rd = mark as read
	--		ur = mark as unread
	--	  rc_^i = move to archive
	--		tr = move to trash

	local MarkAction = "rd"
		if folder == "spam" then
			MarkAction = "tr"
	else
		if folder == "inbox" then
			MarkAction = "rc_^i"
		end
	end

	local post=string.format(globals.strCmdMarkMsgPostData, MarkAction, Gmail_at)

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.format(globals.strCmdMarkMsgNext,
				get_mailmessage_uidl(pstate,i))
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
	end
	-- save fails if it is already saved
	session.save(key(),serialize_state(),session.OVERWRITE)
	-- unlock is useless if it have just been saved, but if we save 
	-- without overwriting the session must be unlocked manually 
	-- since it wuold fail instead overwriting
	session.unlock(key())

	log.say("Session saved for " .. internal_state.strUserName .. "@gmail.com" ..
			"(" .. internal_state.strCookieVal .. ")\n")

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)

	-- check if already called
	if internal_state.bStatDone then
		return POPSERVER_ERR_OK
	end

	-- Define some local variables
	--
	local b = internal_state.brBrowser
	local action = internal_state.strActions
	local folder = internal_state.strFolder
	local GetNew = false

	-- If the flag maxmsgs is set,
	-- STAT will limit the number of messages to the flag
	--
	local val = (freepops.MODULE_ARGS or {}).maxmsgs or 0
	if tonumber(val) > 0 then
	log.dbg("Gmail: A max of " .. val .. " messages will be downloaded.")
	internal_state.statLimit = tonumber(val)
	end

	-- Check for action command
	--
	if action == "export" then
		-- Export the gmail contacts
		ExportContacts()
	else 
		if action == "getnew" then
			-- Command the action_f to parse only new messages
			--
			GetNew = true
		end
	end

	-- Build the message list URL
	--
	local uri = string.format(globals.strCmdMsgList, folder, 0, RandNum())

	-- The action for do_until
	--
	local function action_f (s)
		-- variables to hold temp parsing data
		-- variables iPos1, iPos2 hold the last position of the previous search,
		-- to start next loop where we ended the first one
		local iPos1, sUIDL, sFrom, iNew, iStarred
		local iPos2, parentUIDL, sSender
		local myemail = internal_state.strUserName .. "@gmail.com"

		local subThreads
		local body, err

		local MessageList = {}
		local strMessageListRegExp = globals.strMessageListRegExp
		_, iPos1, sUIDL, iNew, iStarred, sFrom = string.find(s, strMessageListRegExp)

		while sUIDL ~= nil do
			if not GetNew or (GetNew and iNew == "1") then
				-- Check for conversations
				--
				subThreads = string.match(sFrom, "%((%d+)%)$")

				-- TODO: before adding message, check also if sender is self
				--	  important for threads...
				-- TODO2: mark message as unread if it was new (GetNew)
				-- log.say(sFrom .. " - " .. myemail .. "\n")
				if string.find(sFrom, "("..myemail..")") == nil then
					table.insert(MessageList, {
							["sUIDL"] = sUIDL, 
							["iSize"] = 1,
							["iNew"]  = iNew, 
							["iStarred"] = iStarred })
				end

				-- If it is a conversation, then get sub messages
				--
				if subThreads ~= nil then
					parentUIDL = sUIDL
					uri = string.format(
						globals.strMessageThreadUrl,
						folder, parentUIDL, RandNum())

					body, err = b:get_uri(uri)

					iPos2 = 0
					_, iPos2, sUIDL, iStarred, sSender = string.find(body,
							globals.strMessageThreadRegExp)

					while sUIDL ~= nil do
						if sUIDL ~= parentUIDL and sSender ~= myemail then
							table.insert(MessageList, {
								["sUIDL"] = sUIDL,
								["iSize"] = 1, 
								["iNew"] = 0, 
								["iStarred"] = iStarred })
						end
						_, iPos2, sUIDL, iStarred, sSender =
							string.find(body,
							globals.strMessageThreadRegExp, iPos2)
					end
				end
			end
			_, iPos1, sUIDL, iNew, iStarred, sFrom = string.find(
				s, strMessageListRegExp, iPos1)
		end

		local n = #MessageList

		if n == 0 then
			return true,nil
		end

		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		local nmesg_old = get_popstate_nummesg(pstate)
		local nmesg = nmesg_old + n
		
		if internal_state.statLimit ~= nil then
			if nmesg >= internal_state.statLimit then
				nmesg = internal_state.statLimit
				n = nmesg - nmesg_old
			end
		end

		set_popstate_nummesg(pstate,nmesg)

		local val
		-- gets all the results and puts them in the popstate structure
		for i = 1,n do
			-- we should leave order newest to oldest, 
			-- since we have more pages to precess
			val = MessageList[i]
			sUIDL = val["sUIDL"]
			if not sUIDL then
				return nil, "Unable to parse page"
			end
			-- set it, size in gmail is unavailable, 
			-- so set to 1 always
			set_mailmessage_size(pstate, i+nmesg_old, 1)
			set_mailmessage_uidl(pstate, i+nmesg_old, sUIDL)
		end
		
		return true,nil
	end

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function check_f (s)
		local iStart, iShow, iTotal = string.match(s, globals.strCmdMsgListChkNext)
		local val=1

		-- val = 0 if we have maxmsgs and we are finished
		if internal_state.statLimit ~= nil then
			val = internal_state.statLimit - get_popstate_nummesg(pstate)
		end

		if (iStart == nil) then iStart = "0" end
		if (iShow  == nil) then iShow  = "0" end
		if (iTotal == nil) then iTotal = "0" end

		if tonumber(iStart)+tonumber(iShow) < tonumber(iTotal) and val > 0 then
		-- TODO: furthur tests with more than 2 pages of emails
			-- change retrive behaviour
			uri = string.format(globals.strCmdMsgList, folder,
				iStart+iShow, RandNum())
			-- continue the loop
			return false
		else
			return true
		end
	end

	-- this is simple and uri-dependent
	local function retrive_f ()
		local f, err = b:get_uri(uri)
		if f == nil then
			return f,err
		end
		return f, err
	end

	-- this to initialize the data structure
	set_popstate_nummesg(pstate, 0)

	-- do it
	if not support.do_until(retrive_f, check_f, action_f) then
		log.error_print("Stat failed\n")
		session.remove(key())
		return POPSERVER_ERR_UNKNOWN
	end

	-- now reverse order to have old to new
	
	local n = get_popstate_nummesg(pstate) / 2
	for i = 1,n do
		local sUIDL = get_mailmessage_uidl(pstate, i)
		set_mailmessage_uidl(pstate, i, get_mailmessage_uidl(pstate, n*2-i+1))
		set_mailmessage_uidl(pstate, n*2-i+1,sUIDL)
	end

	-- store in internal_state GMAIL_AT.value
	internal_state.strGmailAt = (b:get_cookie("GMAIL_AT")).value

	-- save the computed values
	internal_state.bStatDone = true
	
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate, msg)
	return common.uidl(pstate, msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
	return common.uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate, msg)
	return common.list(pstate, msg)
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
function dele(pstate, msg)
	return common.dele(pstate, msg)
end
-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
	return common.noop(pstate)
end

-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function retr(pstate, msg, data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	local returnState = nil

	-- TODO: range checks doesn't work... need fixing... btw, in dele it works....
	if not common.check_range(pstate, msg) then
		log.say("Message index out of range.\n")
		-- log will say the above message, but no error message (-ERR)
		-- will be sent to the client.
		returnState = POPSERVER_ERR_NOMSG
	else	
		-- the callback
		local cb = retr_cb(data)
		
		-- some local stuff
		local b = internal_state.brBrowser
		local folder = internal_state.strFolder

		-- build the uri
		local uidl = get_mailmessage_uidl(pstate,msg)

		local uri = string.format(globals.strViewMessage,uidl,RandNum())

		-- tell the browser to pipe the uri using cb
		local f,rc = b:pipe_uri(uri,cb)
		
		if not f then
			log.error_print("Asking for "..uri.."\n")
			log.error_print(rc.."\n")
			return POPSERVER_ERR_NETWORK
		else
			popserver_callback("\r\n",data)
			
-- TODO: after sending the message to the client, we need to set it as read
--		already done, but check if all is ok....
			uri = string.format(globals.strCmdMarkMsgUrl, folder)
			local Gmail_at = internal_state.strGmailAt
			local post = string.format(globals.strCmdMarkMsgPostData,
				"rd", Gmail_at)
			post = post..string.format(globals.strCmdMarkMsgNext, uidl)
			b:post_uri(uri, post)
		end
		returnState = POPSERVER_ERR_OK
	end

	return returnState
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
--
function top(pstate, msg, lines, data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- some local stuff
	local b = internal_state.brBrowser

	-- build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(globals.strViewMessage,uidl,RandNum())

	-- build the callbacks --
	
	-- this data structure is shared between callbacks
	local global = {
		-- the current amount of lines to go!
		lines = lines, 
		-- the original amount of lines requested
		lines_requested = lines, 
		-- how many bytes we have received
		bytes = 0,
		total_bytes = get_mailmessage_size(pstate,msg),
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
	local cb = top_cb(global,data)
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
--	support.do_until(retrive_f,check_f,action_f)
	if not support.do_until(retrive_f,check_f,action_f) then
		if global.lines ~= -1 then
			log.error_print("Top failed\n")
			session.remove(key())
			return POPSERVER_ERR_UNKNOWN
		end
	end

	return POPSERVER_ERR_OK
end


-- -------------------------------------------------------------------------- --
-- Export the address book from your gmail account to a file
-- on the local machine, in csv format (name,email,notes)
function ExportContacts()
	local b = internal_state.brBrowser

	local uri = string.format("http://mail.google.com/mail/?view=cl"..
						 "&search=contacts&pnl=a&zx=%s", RandNum())
						 
	local body, err = b:get_uri(uri)

	local single_contact = '%["ce","[^"]*","([^"]*)","[^"]*","([^"]*)","([^"]*)".-%]'
	local exportfile

	-- Check user home path in linux
	local UserHome = os.getenv("HOME")
	if UserHome == nil then
		-- If nil, then try the home path variable of a windows system
		UserHome = os.getenv("HOMEPATH")
		if UserHome ~= nil then
			UserHome = os.getenv("HOMEDRIVE")..UserHome..
					"\\My Documents\\"
		else
			-- If still nil, then save in freepops path
			UserHome = ""
		end
	else
		UserHome = UserHome .. "/"
	end
	exportfile = UserHome .. "gmail_contacts_export.csv"

	io.output(io.open(exportfile ,"w"))
	io.write("Name,E-mail Address,Notes\n")
	if body ~= nil then
		local _, iPos, sName, sEmail, sNote = string.find(body, single_contact)
		while email~=nil do
			io.write(sName..","..sEmail..","..sNote.."\n")
			_, iPos, sName, sEmail, sNote = string.find(body, single_contact, iPos)
		end
	end
	io.close()
end

-- -------------------------------------------------------------------------- --
--  This function is called to initialize the plugin.
--  Since we need to use the browser and save sessions we have to use
--  some modules with the dofile function
--
--  We also exports the pop3server.* names to global environment so we can
--  write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
--  
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the serialization module
	require("serial")

	-- the browser module
	require("browser")

	freepops.need_ssl()

	-- the common implementation module
	require("common")
	
	-- checks on globals
	freepops.set_sanity_checks()

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
