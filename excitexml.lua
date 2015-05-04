-- ************************************************************************** --
--  FreePOPs @excite.com webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Para <para@sci.fi>, based on excite.lua by TheMarco
-- ************************************************************************** --

-- Globals
--
PLUGIN_NAME = "excitexml"
PLUGIN_VERSION = "0.6"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=excitexml.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/en/viewplugin.php?plugin=excitexml.lua"
PLUGIN_AUTHORS_NAMES = {"Para"}
PLUGIN_AUTHORS_CONTACTS = {"para@sci.fi"}
PLUGIN_DOMAINS = {"@excite.com","@myway.com"}
PLUGIN_DESCRIPTIONS = {
	en=[[Excite and My Way webmail plugin. Use your full email address as the username and your real password as the password. 
For support, please post your questions to the <a href="http://www.diludovico.org/forum/">forum</a>.]]
}
PLUGIN_PARAMETERS = {
	{name="folder", description={
		en=[[The folder to interact with. Default is INBOX, other values are: Sent-Mail, Drafts, Trash, Junk-Mail or user defined folder.]]}
	},
	{name="delete", description={
		en=[[On deletion, messages can either be moved to Trash (delete=trash, the default) or deleted permanently (delete=delete).]]}
	},
	{name="ssl", description={
		en=[[By default SSL is enabled, but this parameter allows disabling it for the most part (ssl=0 or ssl=false). Authentication still requires SSL regardless of this parameter.]]}
	}
}


-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {

	-- Server URL
	strEntryUrl = {	["excite.com"]="http://rd.excite.com/sp/em", ["myway.com"]="https://webmail.myway.com" },

	-- Default mailboxes
	strMailbox = "INBOX",
	strTrash   = "Trash",

	-- Sessions cannot be resumed on Windows at the moment because of some SSL problem. Linux users can set this to true
	supportSessions = false
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
	browser        = nil,
	bError         = false,
	bStatDone      = false,
	bLoginDone     = false,
	bSSL           = true,
	bTrashOnDelete = true,
	strBaseUrl     = nil,
	strBaseRegUrl  = nil,
	strFormatDate  = nil,
	strEntryUrl    = nil,
	strDomain      = nil,
	strMBox        = nil,
	strMBoxID      = nil,
	strMBoxTrashID = nil,
	strPassword    = nil,
	strSessionUnm  = nil,
	strSessionID   = nil,
	strUser        = nil
}


-- Plugin Initialization
--
function init(pstate)

	local initstatus = curl.version()..": "

	-- Import the freepops name space allowing for us to use the status messages
	freepops.export(pop3server)

	require("browser")
	internalState.browser = browser.new()

--	if not internalState.browser:ssl_enabled() then
--  -- ??? attempt to call method 'ssl_enabled' (a nil value)
--		log.say("Error: Plugin requires SSL, but it is not supported by this version of FreePOPs.")
--		return POPSERVER_ERR_INTERNAL
--	end
	internalState.browser:ssl_init_stuff()

	--internalState.browser:verbose_mode() -- some traffic logged to stderr

	require("serial")
	require("common")
	require("xml2table")

	-- Run a sanity check
	freepops.set_sanity_checks()

	local ssl = (freepops.MODULE_ARGS or {}).ssl
	if ssl=="false" or ssl=="0" then
		internalState.bSSL = false
		initstatus = initstatus .. "SSL disabled"
	else -- if ssl=="true" or ssl=="1" then -- default
		internalState.bSSL = true
		initstatus = initstatus .. "SSL enabled"
	end

	-- Get the folder
	local folder = (freepops.MODULE_ARGS or {}).folder
	internalState.strMBox = folder or globals.strMailbox
	initstatus = initstatus .. ", using folder " .. internalState.strMBox

	local delete = (freepops.MODULE_ARGS or {}).delete
	if delete == "delete" then
		initstatus = initstatus .. ", messages marked for deletion will be deleted permanently"
	else -- delete=="trash" -- default
		internalState.bTrashOnDelete = true
		initstatus = initstatus .. ", messages marked for deletion will be moved to Trash"
	end

	-- Let the log know that we have initialized ok
	log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") initialized: " .. initstatus)

	-- Everything loaded ok
	return POPSERVER_ERR_OK
end


-- ************************************************************************** --
--  Helper functions
-- ************************************************************************** --

-- Serialize the state
--
-- serial. serialize is not enough powerfull to correcly serialize the 
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the 
-- serial module to know how to serialize this. so we call b:serialize 
-- method by hand hacking a bit on names
--
function serialize_state()
  internalState.bStatDone = false;
	
  return serial.serialize("internalState", internalState) ..
		internalState.browser:serialize("internalState.browser")
end

-- Computes the hash of our state.  Concatenate the user, domain and mailbox.
--
function hash()
	return (internalState.strUser or "") .. "~" ..
	       (internalState.strDomain or "") .. "~"  ..
	       (internalState.strMBox or "")
end

-- Formats URLs depending on SSL
--
function checkSSL(url)
	if internalState.bSSL then
		url = string.gsub(url, 'http://', 'https://')
	else
		url = string.gsub(url, 'https://', 'http://')
	end
	return url
end

-- Issue the command to login
--
function login()

	-- Check to see if we've already logged in
	if not internalState.bLoginDone then

		-- Define some local variables
		local username = internalState.strUser
		local password = curl.escape(internalState.strPassword)
		local domain = internalState.strDomain
		local browser = internalState.browser

-- *** LOGIN #1 - Webmail entry page (from globals), redirects to:
--                https://registration.excite.com/excitereg/login.jsp?app=bt&return_url=https://webmail.excite.com/cgi-bin/login_sso.cgi
--                https://registration.myway.com/primary_login.jsp?regarea=email&return_url=https://my.myway.com/email_redir.jsp
--
--                If session is reloaded and SSO is still active, => https://webmail.excite.com/cgi-bin/login_sso.cgi
--                                                                   https://webmail.myway.com/cgi-bin/login_sso_myway.cgi

		local url = internalState.strEntryUrl
		log.dbg("LOGIN Init: GET " .. url)
		local body,err = browser:get_uri(url)

		if not body then
			log.say(err)
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

		if not string.match(browser:whathaveweread(), "^http[^?]-cgi%-bin/[^?]-login_sso") then -- continuing normally
		-- When SSO of loaded session is still active and we were redirected to application without new login, short circuit there
		-- All internalState variables normally filled here will already have been loaded from the session

			local snonce,stime = string.match(body, '<%s-input%s+.-%s+name="?snonce"?.-%s+value="(.-)".-<%s-input%s+.-%s+name="?stime"?.-%s+value="(.-)"')
			local login_process_url, sso_url = string.match(body, '<%s-form%s+name=loginbox%s+[^>]-action="?([^"]+)"?.-<input%s.-name="?return_url"?%s+value="?([^"]+)"?')

			if not snonce or not stime or not login_process_url or not sso_url then
				log.dbg("Error initializing login: snonce/stime/urls not found from " .. browser:whathaveweread())
				internalState.bError = true
				return POPSERVER_ERR_NETWORK
			end

			internalState.strBaseRegUrl = string.match(login_process_url, "^(https?://.+)/" )

			-- seed math.random properly
			math.randomseed(math.fmod(os.time(),37))
			local j = math.random(67)
			math.randomseed((math.fmod((os.time()/j),73)+1)*j)

			-- Now calculate the post data
			local skew,passfiller = 1,string.rep("x", string.len(password))
			local data = skew .. snonce
			-- Excite's HmacMD5
			local rawres = crypto.hmac(data,crypto.md5(string.lower(password)),crypto.ALGO_md5)
			local crep = base64.encode(string.sub(rawres,7))

-- *** LOGIN #2 - https://registration.excite.com/excitereg/login_process.jsp -- https uses html redirects
--             => https://webmail.excite.com/cgi-bin/login_sso.cgi
--         or
--                https://registration.myway.com/login_process.jsp -- https uses html redirects
--             => http://my.myway.com/email_redir.jsp
--             => http://registration.myway.com/login.jsp?app=bt&return_url=https://webmail.myway.com/cgi-bin/login_sso_myway.cgi
--             => https://webmail.myway.com/cgi-bin/login_sso_myway.cgi

			local url = checkSSL(login_process_url)
			local format = "app=bt&return_url=%s&snonce=%s&stime=%s&timeskew=%d&crep=%s&jerror=none&membername=%s&password=%s&gofer=Sign In!&perm=0"
			local post = string.format(format, sso_url, curl.escape(snonce), curl.escape(stime), skew, curl.escape(crep), username, passfiller )
			log.dbg("LOGIN Auth: POST " .. url)
			body, err = browser:post_uri(url, post)

			if not body then
				log.say(err)
				internalState.bError = true
				return POPSERVER_ERR_NETWORK
			end

			if string.match(browser:whathaveweread(), '[?&]err=') then
				log.say("Password incorrect\n");
				internalState.bError = true
				return POPSERVER_ERR_AUTH
			end

-- *** LOGIN #2.5 - case of no redirect - https://webmail.excite.com/cgi-bin/login_sso.cgi
--                                        http://my.myway.com/email_redir.jsp etc

			if not string.match(browser:whathaveweread(), "cgi%-bin/.-login_sso") then
				local url = sso_url -- no SSL for Myway's redirector to login_sso, trusting redirects
				log.dbg("LOGIN Single sign-on: GET " .. url)
				body, err = browser:get_uri(url)

				if not body then
					log.say(err)
					internalState.bError = true
					return POPSERVER_ERR_NETWORK
				elseif string.match(browser:whathaveweread(), 'logout') then
					log.say("Error logging in: redirected to " .. browser:whathaveweread() .. "\n")
					internalState.bError = true
					return POPSERVER_ERR_NETWORK
				end
			end

		end -- SSO short circuit from #1

-- *** LOGIN #2 continues

		local full_application_url = string.match(body, '"(https?://.-)"')

		if not full_application_url then
			log.say("Error finishing login: Application URL not found\n")
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

		-- stripping get parameters, if any
		local application_url = string.match(full_application_url, '^([^?]+)%??')

		internalState.strBaseUrl = string.match(application_url, "^(https?://[^/]+)")

		internalState.strSessionUnm = string.match(full_application_url, 'unm=([^&]+)')
		internalState.strSessionID = string.match(full_application_url, 'sid=(%w+)')

		if not internalState.strSessionUnm or not internalState.strSessionID then
			log.say("Error finishing login: unm/sid not found\n")
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

-- *** LOGIN #3 - https://webmail.excite.com/672e7aee/gds/index_rich.php
--                https://webmail.myway.com/672e7aee/gds/index_rich.php

		local url = checkSSL(application_url)
		local post = string.format("sid=%s&unm=%s&save_unm=0&sec=0&status=1", internalState.strSessionID, internalState.strSessionUnm )
		log.dbg("LOGIN Application init: POST " .. url)
		local body, err = browser:post_uri(url, post)

		if not body then
			log.say(err)
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

-- *** LOGIN #4 - https://webmail.excite.com/main/user_iframe.asp
--                https://webmail.myway.com/main/user_iframe.asp
-- Referred to in a Javascript function in /672e7aee/gds/index_rich.php, but trying to parse it from there is as volatile as using a direct url
		local url = checkSSL(internalState.strBaseUrl .. "/main/user_iframe.asp")
		local post = string.format("unm=%s&sid=%s", internalState.strSessionUnm, internalState.strSessionID)
		log.dbg("LOGIN Application config: POST " .. url)
		local body, err = browser:post_uri(url, post)

		if not body then
			log.say(err)
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

		-- Excite applies the user's regional preferences at the database backend and not the interface
		if string.match(body, 'mUserCacheData.date_prefs%s*=%s*"?%%d/%%m/%%Y"?') then
			internalState.strFormatDate = "dmy"
		else --Excite default "%m%/%d/%Y"
			internalState.strFormatDate = "mdy"
		end

		if string.match(body, 'mUserCacheData.time_prefs%s*=%s*"?%%H:%%M"?') then
			internalState.strFormatTime = "24h"
		else --Excite default "%I:%M %p"
			internalState.strFormatTime = "12h"
		end

		-- We have logged in successfully
		internalState.bLoginDone = true

  end

  return POPSERVER_ERR_OK
end

-- Ending the session
function logout()
	
	local browser = internalState.browser
	
	-- https://webmail.excite.com/logout.asp and https://webmail.myway.com/logout.asp
	-- redirects to
	-- https://registration.excite.com/excitereg/logout.jsp and https://registration.myway.com/logout.jsp
	local url = checkSSL(internalState.strBaseUrl.."/logout.asp")
	local post = string.format("unm=%s&sid=%s&msg=0&top=true", internalState.strSessionUnm, internalState.strSessionID )
	log.dbg("LOGOUT: POST " .. url)
	local body, err = browser:post_uri(url, post)

	if not body then
		log.say(err)
		internalState.bError = true
		return POPSERVER_ERR_NETWORK
	end

	internalState.bLoginDone = false
	if globals.supportSessions then
		session.remove(hash())
		log.say("Session ended for " .. internalState.strUser ..  "@" .. internalState.strDomain .. "\n")
	end
	log.say("Logged out " .. internalState.strUser ..  "@" .. internalState.strDomain .. "\n")
	
	return POPSERVER_ERR_OK
end


function unxml(text)
	local result = string.gsub(text, "&lt;", "<")
	result = string.gsub(result, "&gt;", ">")
	result = string.gsub(result, "&quot;", '"')
	result = string.gsub(result, "&amp;", "&")
	return result
end


-- ************************************************************************** --
--  Pop3 functions that must be defined
-- ************************************************************************** --

-- Extract the user, domain and mailbox from the username
--
function user(pstate, username)
	-- Get the user, domain, and mailbox
	local domain = freepops.get_domain(username)
	local user = freepops.get_name(username)
  
	internalState.strDomain = domain
	internalState.strUser = user

	if globals.strEntryUrl[domain] then
		internalState.strEntryUrl = globals.strEntryUrl[domain]
	else
		internalState.strEntryUrl = "https://webmail." .. domain
	end

	return POPSERVER_ERR_OK
end


-- Perform login functionality
--
function pass(pstate, password)

	internalState.strPassword = password

	-- Get a session
	local sessID = nil
	if globals.supportSessions then
		sessID = session.load_lock(hash())
	end

	-- See if we already have a session.  We want to prevent multiple sessions for a given account.
	if sessID ~= nil then
	
		-- Check to see if it is locked
		if sessID == "\a" then
			log.say("Error: Session locked - Account: " .. internalState.strUser .. "@" .. internalState.strDomain .. "\n")
			internalState.bError = true
			return POPSERVER_ERR_LOCKED
		end

		-- Load the session which looks to be a function pointer
		local func, err = loadstring(sessID)
		if not func then
			log.error_print("Unable to load saved session (Account: " ..
				internalState.strUser .. "@" .. internalState.strDomain .. "): ".. err)
			return login()
		end

		log.say("Session loaded for " .. internalState.strUser .. "@" .. internalState.strDomain .. "\n")

		-- Execute the function saved in the session
		func()

		return POPSERVER_ERR_OK
	else
		-- Create a new session by logging in
		return login()
	end
end


-- Stat command - Get the number of messages and their size
--
function stat(pstate)

	-- Have we done this already?  If so, we've saved the results
	if internalState.bStatDone then
		return POPSERVER_ERR_OK
	end

	local browser = internalState.browser
	local nMsgs = 0

	-- Initialize our state as 0, in case of errors before the end.
	set_popstate_nummesg(pstate, nMsgs)

	-- List of mailboxes
	local url = checkSSL(internalState.strBaseUrl.."/cgi-bin/emailGetFolderTree.fcg")
	local post = string.format("unm=%s&sid=%s&gds=1", internalState.strSessionUnm, internalState.strSessionID )
	log.dbg("GetFolderTree: POST " .. url)
	local xml, err = browser:post_uri(url, post)

	if not xml then
		log.say(err)
		internalState.bError = true
		return POPSERVER_ERR_NETWORK
	end

	local mailboxesxml = xml2table.xml2table(xml)
	if type(mailboxesxml)~='table' or type(mailboxesxml.mboxes)~='table' then
		-- Session has expired and we received something unexpected, retrying clean login
		-- Could also check if we were redirected to /gds/invalidSession.xml, but there may be other cases too...
		log.say("Session expired: logging in again\n")
		logout()
 		local status = login()

		if status ~= POPSERVER_ERR_OK then
			internalState.bError = true
			return status
		end

		post = string.format("unm=%s&sid=%s&gds=1", internalState.strSessionUnm, internalState.strSessionID )
		log.dbg("GetFolderTree: POST " .. url)
		xml, err = browser:post_uri(url, post)

		if not xml then
			log.say(err)
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end
	end

	local mailboxesxml = xml2table.xml2table(xml)

	local mboxempty = false
	local mboxsize = 0

	-- Folder id of used POP box
	if type(mailboxesxml)=='table' and type(mailboxesxml.mboxes)=='table' then
		for k,v in pairs(mailboxesxml.mboxes) do
			if type(v)=='table' and type(v.dname)=='table' and string.len(v.id)>0 and v.t then
				if v.dname._content==globals.strMailbox then
					if v.t=="0" then
						mboxempty = true
					else
						mboxsize = math.max(math.ceil(v.t/10)*10, 100)
					end
				internalState.strMBoxID = v.id
				end
				if v.dname._content==globals.strTrash then internalState.strMBoxTrashID = v.id end
			end
		end
		if internalState.strMBoxID==nil or internalState.strMBoxTrashID==nil then
				log.dbg("Error: Mailboxes not found in foldertree")
				internalState.bError = true
				return POPSERVER_ERR_NETWORK
		end
	else
		log.dbg("Error: FolderTree from ".. browser:whathaveweread() .." invalid")
		internalState.bError = true
		return POPSERVER_ERR_NETWORK
	end

	-- Mailbox contents
	if not mboxempty then
		local url = checkSSL(internalState.strBaseUrl.."/cgi-bin/emailGetMsgList.fcg")
		local post = string.format("unm=%s&sid=%s&gds=1&act=2&fid=%s&index=1&count=%d&srtc=1&srto=1&client_ts=0", internalState.strSessionUnm, internalState.strSessionID, internalState.strMBoxID, mboxsize )
		log.dbg("GetMsgList: POST " .. url)
		local xml, err = browser:post_uri(url, post)

		if not xml then
			log.say(err)
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

		local boxml = xml2table.xml2table(xml)

		if type(boxml)=='table' and type(boxml.msgs)=='table' then
			-- Messages are listed newest first: processing in reverse order
			local i = #boxml.msgs
			while i>0 do
				if type(boxml.msgs[i])=='table' and type(boxml.msgs[i].id)=='table' and string.len(boxml.msgs[i].id._content)>0 then
					nMsgs = nMsgs + 1
					set_popstate_nummesg(pstate, nMsgs)
					set_mailmessage_uidl(pstate, nMsgs, boxml.msgs[i].id._content)
					set_mailmessage_size(pstate, nMsgs, boxml.msgs[i].z._content)
				end
				i=i-1
			end
		else
			log.dbg("Error: MsgList from ".. browser:whathaveweread() .. " invalid")
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end
	end

	internalState.bStatDone = true

	return POPSERVER_ERR_OK
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

-- Do nothing
--
function noop(pstate)
  return common.noop(pstate)
end

-- Retrieve the message
--
function retr(pstate, msg, data)
	return downloadMsg(pstate, msg, data)
end

-- Top Command
--
function top(pstate, msg, nLines, data)
	return downloadMsg(pstate, msg, data, nLines)
end

-- Download message (or nLines of it)
--
function downloadMsg(pstate, msg, data, nLines)
	-- Make sure we aren't jumping the gun
	local retCode = stat(pstate)
	if retCode ~= POPSERVER_ERR_OK then 
		internalState.bError = true
		return retCode 
	end
	
	local browser = internalState.browser
	local uidl = get_mailmessage_uidl(pstate, msg)

	local url = checkSSL(internalState.strBaseUrl.."/cgi-bin/emailGetMsg.fcg")
	local post = string.format("act=3&gds=1&unm=%s&sid=%s&emid=%s&msgid=%s&fid=%s", internalState.strSessionUnm, internalState.strSessionID, uidl, uidl, internalState.strMBoxID )
	log.dbg("GetMsg: POST " .. url)
	local xml, err = browser:post_uri( url, post)

	if not xml then
		log.say(err)
		internalState.bError = true
		return POPSERVER_ERR_NETWORK
	end

	local headers, body, attachments = '', '', ''

	xml = xml2table.xml2table(xml)

	if type(xml)=='table' and type(xml.rhs)=='table' then

		-- From:
		if type(xml.dfs)=='table' and type(xml.dfs.df)=='table' then
			local addr = xml.dfs.df.addr._content
			local from
			if xml.dfs.df.dname then
				from = html2txt(xml.dfs.df.dname._content) .. " <" .. addr .. ">"
			else
				from = html2txt(addr) -- name <addr> may not be split
			end

			headers = "From: " .. from .. "\r\n" -- first header
		end

		-- To:
		if type(xml.recs)=='table' then
			local n = 0
			local tos = ''
			for k,v in pairs(xml.recs) do
				if type(v)=='table' then
					n = n+1
					local to
					if v.dname then
						to = html2txt(v.dname._content) .. " <" .. v.addr._content .. ">"
					else
						to = html2txt(v.addr._content) -- name <addr> may not be split
					end

					if n==1 then
						tos = to
					else
						tos = tos .. ", " .. to
					end
				end
			end
			headers = headers .. "To: " .. tos .. "\r\n"
		end

		-- Date:
		if type(xml.d)=='table' then
			-- 18/12/2008 17:33 or 12/18/2008 05:33 pm to Thu, 18 Dec 2008 17:33:00 -0000
			local day, month, year, hour, min, ampm = string.match(xml.d._content, "(%d+)/(%d+)/(%d+) (%d+):(%d+)%s-(%w-)")

			if (internalState.strFormatDate == 'mdy') then
				day, month = month, day
			end

			if (internalState.strFormatTime == '12h' and string.lower(ampm) == 'pm') then
				hour = hour+12
			end

			local timestamp = os.time( { year=year, month=month, day=day, hour=hour, min=min } )
			local date = os.date("%a, %d %b %Y %H:%M:%S -0000", timestamp)
			headers = headers .. "Date: " .. date .. "\r\n"
		end

		-- Subject:
		if type(xml.s)=='table' then
			headers = headers .. "Subject: ".. html2txt(xml.s._content) .."\r\n"
		end

		-- Other headers
		local multiboundary
		local hascontenttype
		for k,v in pairs(xml.rhs) do
			if type(v)=='table' and type(v.name)=='table' and type(v.value)=='table' then
				local header = v.name._content
				local value = v.value._content
				if value~=nil then
					value = unxml(value)
					value = string.gsub(value, "([^\r])\n", "%1\r\n") -- some headers may be folded
					-- Excite mangles message bodies so that content types have nothing to do with the message anymore: substituting with a default
					if string.lower(header)=="content-type" then
						hascontenttype = 1
						value = string.gsub(value, '[Cc][Hh][Aa][Rr][Ss][Ee][Tt]="?[^" ]+"?', 'charset="ISO-8859-1"')
						value = string.gsub(value, "[Tt][Ee][Xx][Tt]/[Pp][Ll][Aa][Ii][Nn]", "text/html")
						if type(xml.messagebody)=='table' and string.match(xml.messagebody._content, '<img src="https?://[^"]-.bluetie.com/cgi%-bin/emailGetAttachment.cgi%?.-cid=') then
							value = string.gsub(value, "[Mm][Uu][Ll][Tt][Ii][Pp][Aa][Rr][Tt]/%w+", "multipart/related")
						else
							value = string.gsub(value, "[Mm][Uu][Ll][Tt][Ii][Pp][Aa][Rr][Tt]/%w+", "multipart/mixed")
						end
						multiboundary = string.match(value, '^[Mm][Uu][Ll][Tt][Ii][Pp][Aa][Rr][Tt].-[Bb][Oo][Uu][Nn][Dd][Aa][Rr][Yy]="?([^"]+)"?')
					end

					if not string.match(string.lower(header), "^content%-transfer%-encoding") then
						headers = headers .. header .. ": " .. value .. "\r\n"
					end
				end
			end
		end

		if not hascontenttype then
			headers = 'Content-Type: text/html; charset="ISO-8859-1"\r\n' .. headers
		end


		-- Body
		if type(xml.messagebody)=='table' then
			body = xml.messagebody._content

			-- Excite adds a prefix to some HTML tags: remove
			body = string.gsub(body, "<btf", "<")
			body = string.gsub(body, "</btf", "</")

			body = string.gsub(body, "([^\r])\n", "%1\r\n") -- xml may have various line endings

			if multiboundary then
				body = '--' .. multiboundary .. '\r\nContent-Type: text/html; charset="ISO-8859-1"\r\n\r\n' .. body

				-- Attachments (TOP won't get any)
				if not nLines and type(xml.das)=='table' then

					-- Get filename for each cid, to link the attachments with cid links in the body
					local attachmentcids = {}
					local function cidmatch(match)
						local url = checkSSL(internalState.strBaseUrl.."/cgi-bin/emailGetAttachment.cgi")
						local query = string.format("act=11&unm=%s&fid=%s&msgid=%s&sid=%s&cid=%s", internalState.strSessionUnm, internalState.strMBoxID, uidl, internalState.strSessionID, match )
						log.dbg("GetAttachment: HEAD " .. url)
						local httphead, err = browser:get_head(url .. "?" .. query)

						if not httphead then
							log.say(err)
							internalState.bError = true
							return POPSERVER_ERR_NETWORK
						end

						local filename = string.match(httphead, 'Content%-Disposition:.-filename="([^"]-)"')
						attachmentcids[filename] = match

						return '<img src="cid:'..match..'"'
					end

					-- Excite replaces links to attached images on the server side with a URL that isn't mentioned anywhere in the XML.
					-- Currently the links lead to bluetie.com and the filename<->cid link can be found, but it may change!
					body = string.gsub(body, '<img src="https?://[^"]-.bluetie.com/cgi%-bin/emailGetAttachment.cgi%?.-cid=([^"]+)"', cidmatch )

					-- Process attachment list from xml
					for k,v in pairs(xml.das) do
						if type(v)=='table' then
							local id = v.id._content
							local name = v.dname._content
							local size = v.z._content
							local contenttype = v.y._content

							local url = checkSSL(internalState.strBaseUrl.."/cgi-bin/emailGetAttachment.cgi")
							local post = string.format("act=11&unm=%s&sid=%s&msgid=%s&fid=%s&attemid=&attid=%s", internalState.strSessionUnm, internalState.strSessionID, uidl, internalState.strMBoxID, id )
							log.dbg("GetAttachment: POST " .. url)
							local filebody, err = browser:post_uri(url, post)

							if not filebody then
								log.say(err)
								internalState.bError = true
								return POPSERVER_ERR_NETWORK
							end

							local dobase64 = true
							if contenttype=='message/rfc822' then dobase64 = false end

							local ctrow = '\r\nContent-Type: '..contenttype..'; name="'..name..'"\r\n'
							if dobase64 then ctrow = ctrow .. 'Content-Transfer-Encoding: base64\r\n' end
							if attachmentcids[name] then ctrow = ctrow .. 'Content-ID: <'.. attachmentcids[name] ..'>\r\n' end
							ctrow = ctrow .. '\r\n'

							attachments = attachments .. '--' .. multiboundary .. ctrow
	
							if dobase64 then
								local base64file = base64.encode(filebody)
								local i=1
								while i<string.len(base64file) do
									attachments = attachments .. string.sub(base64file,i,i+75) .. "\r\n"
									i = i+76
								end
							else
								attachments = attachments .. filebody .. "\r\n"
							end
						end
					end
				end
			end
	
			if string.len(attachments)>0 then
				body = body .. attachments
			end

		else
			log.dbg("Error: Message "..uidl.." has no body")
			internalState.bError = true
			return POPSERVER_ERR_NETWORK
		end

	else
		log.dbg("Error: Headers not found for message "..uidl)
		internalState.bError = true
		return POPSERVER_ERR_NETWORK
	end

	if nLines then
		local top = ''
		local i=1
		for line in string.gmatch(body, '.-\r\n') do
			top = top .. line
			if i==nLines then break end
			i = i+1
		end
		
		body = top
	end

	if string.sub(body, -2)~='\r\n' then
		body = body .. '\r\n'
	end

	popserver_callback(headers .. "\r\n" .. body, data)

	return POPSERVER_ERR_OK

end

-- Mark msg for deletion
--
function dele(pstate,msg)
	return common.dele(pstate, msg)
end

-- Unflag each message marked for deletion
--
function rset(pstate)
	return common.rset(pstate)
end

-- Non-update quit
--
function quit(pstate)
	-- Invalidating session after an error
	if internalState.bLoginDone and (internalState.bError or not globals.supportSessions) then
		return logout()
	else
		session.unlock(hash())
		return POPSERVER_ERR_OK
	end
end

-- Update the mailbox status and quit
--
function quit_update(pstate)
	-- Make sure we aren't jumping the gun
	local retCode = stat(pstate)
	if retCode ~= POPSERVER_ERR_OK then 
		internalState.bError = true
		return retCode 
	end

	if internalState.strMBox ~= 'Trash' then
		-- Cycle through the messages and see if we need to delete any of them
		local sourcefolder = internalState.strMBoxID
		local deletequeue = {}
		local browser = internalState.browser
		local messagecount = get_popstate_nummesg(pstate)
		for i = 1, messagecount do
		    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
		    	local uidl=get_mailmessage_uidl(pstate, i)
		    	if internalState.bTrashOnDelete then
					uidl = sourcefolder..':'..uidl
		    	end
				table.insert(deletequeue, uidl)
			end
		end

		if (#deletequeue>0) then
			local targetfolder = internalState.strMBoxTrashID
			local deletelist = ''

			if internalState.bTrashOnDelete then
				deletelist = table.concat(deletequeue, '|')
			else
				deletelist = table.concat(deletequeue, ',')
			end

			local url, post
			if internalState.bTrashOnDelete then
				url = internalState.strBaseUrl.."/cgi-bin/emailMoveMsg.cgi"
				post = string.format("gds=1&act=6&reloadurl=&cb=&cbtarget=&tf=%s&unm=%s&sid=%s&srdata=%s", targetfolder, internalState.strSessionUnm, internalState.strSessionID, deletelist )
			else
				url = internalState.strBaseUrl.."/cgi-bin/emailDeleteMsg.cgi"
				post = string.format("gds=1&unm=%s&sid=%s&act=5&deleteall=5&reloadurl=&msgid=%s&fid=%s", internalState.strSessionUnm, internalState.strSessionID, deletelist, internalState.strMBoxID )
			end

			url = checkSSL(url)
			log.dbg("DeleteMsg: POST " .. url)
			local xml, err = browser:post_uri(url, post)

			if not xml then
				log.say(err)
				internalState.bError = true
				return POPSERVER_ERR_NETWORK
			end

			if not string.match(xml, '<actionStatus>.-<code>.-1.-</code>.-</actionStatus>') then
				log.dbg("Error: Failed deleting messages")
				internalState.bError = true
				return POPSERVER_ERR_NETWORK
			end
		end
	end

	if globals.supportSessions then
		session.save(hash(), serialize_state(), session.OVERWRITE)
		log.say("Session saved for " .. internalState.strUser ..  "@" .. internalState.strDomain .. "\n")
		session.unlock(hash())
	else
		return logout()
	end

	return POPSERVER_ERR_OK
end


-- from mimer.lua function Private.html2txt
function html2txt(s)
	s = string.gsub(s,"&(%a-);",function(c)
		c = string.lower(c)
		return html_coded[c] or ("["..c.."]")
	end)
	s = string.gsub(s,"&#(%d-);", function(c)
		if tonumber(c) < 256 then
			return string.char(c)
		end
		-- FIXME: handle unicode characters?
		return "?"
	end)
	return s
end

html_coded = {

	["szlig"]	= "ß",
	["Ntilde"]	= "Ñ",
	["ntilde"]	= "ñ",
	["Ccedil"]	= "Ç",
	["ccedil"]	= "ç",
	
	["auml"]	= "ä",
	["euml"]	= "ë",
	["iuml"]	= "ï",
	["ouml"]	= "ö",
	["uuml"]	= "ü",
	["Auml"]	= "Ä",
	["Euml"]	= "Ë",
	["Iuml"]	= "Ï",
	["Ouml"]	= "Ö",
	["Uuml"]	= "Ü",
	["aacute"]	= "á",
	["eacute"]	= "é",
	["iacute"]	= "í",
	["oacute"]	= "ó",
	["uacute"]	= "ú",
	["Aacute"]	= "Á",
	["Eacute"]	= "É",
	["Iacute"]	= "Í",
	["Oacute"]	= "Ó",
	["Uacute"]	= "Ú",
	["acirc"]	= "â",
	["ecirc"]	= "ê",
	["icirc"]	= "î",
	["ocirc"]	= "ô",
	["ucirc"]	= "û",
	["Acirc"]	= "Â",
	["Ecirc"]	= "Ê",
	["Icirc"]	= "Î",
	["Ocirc"]	= "Ô",
	["Ucirc"]	= "Û",
	["agrave"]	= "à",
	["igrave"]	= "ì",
	["egrave"]	= "è",
	["ograve"]	= "ò",
	["ugrave"]	= "ù",
	["Agrave"]	= "À",
	["Igrave"]	= "Ì",
	["Egrave"]	= "È",
	["Ograve"]	= "Ò",
	["Ugrave"]	= "Ù",

	["euro"]	= '€',
	["pound"]	= '£',
	["yen"]		= '¥',
	["cent"]	= '¢',
	["iquest"]	= '¿',
	["iexcl"]	= '¡',
	["quot"]	= '"',
	["lt"]		= '<',
	["gt"]		= '>',
	["nbsp"]	= ' ',
	["amp"]		= '&',
}


-- EOF
-- ************************************************************************** --
