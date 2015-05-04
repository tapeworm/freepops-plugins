-- ************************************************************************** --
--  FreePOPs @daee.sp.gov.br, @serhs.sp.gov.br -- webmail interface
-- 
--  $Id: sei.lua,v 0.0.1 2005/02/01 15:00:00 btgig Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Nilson Murai<btgig (at) daee(.)sp(.)gov(.)br>
-- ************************************************************************** --
-- PLUGIN INFO SECTION
-- ************************************************************************** --
PLUGIN_VERSION = "0.0.1"
PLUGIN_NAME = "webmail.sei.sp.gov.br"
PLUGIN_REQUIRE_VERSION = "0.0.025"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/download.php?contrib=sei.lua"
PLUGIN_AUTHORS_NAMES = {"Nilson Murai"}
PLUGIN_AUTHORS_CONTACTS = {"btgig (at) daee (.) sp (.) gov (.) br"}
PLUGIN_DOMAINS = {"@prodesp.sp.gov.br","@sei.sp.gov.br","@daee.sp.gov.br","@serhs.sp.gov.br","@detran.sp.gov.br","@educacao.sp.gov.br","@fazenda.sp.gov.br","@habitacao.sp.gov.br"}
PLUGIN_PARAMETERS = { 
--	{name="---name---", 
--	 description={en="---desc-en---",it=="---desc-it---"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[Soltanto per i brasiliani]],
	en=[[
This plugin is for users of https://webmail.sei.sp.gov.br.<BR>
<BR>
NOTE:<BR>
1. Be sure your username (fulano@domain) and password<BR>
   is correct in your POP3 client!<BR>
2. Works only with INBOX folder.<BR>
3. It was not connecting at first time. I've tried the following command<BR>
   line:<BR>
   freepopsd -b 0.0.0.0 -p 110 -P proxy3.redegov.sp.gov.br:80<BR>
   -b 0.0.0.0  - bind all network (it can be ommitted if localhost only)<BR>
   -p 110      - POP3 servers listens at port TCP 110<BR>
   -P proxy3.redegov.sp.gov.br:80 - the internal proxy must be used!<BR>
4. You must have a unzipper. Try http://www.info-zip.org/UnZip.html <BR>
   Put unzip.exe in the same folder of fpops. You must have read/write rights<BR>
   Any other unzipper that accepts command line will do, but you'll have to<BR>
   change the code. ;)]]
}
-- ************************************************************************** --
-- PLUGIN INFO SECTION END
-- ************************************************************************** --
-- COMMENTS SECTION
-- ************************************************************************** --
-- This is the interface to the external world. These are the functions 
-- that will be called by FreePOPs.
-- param pstate is the userdata to pass to (set|get)_popstate_* functions
-- param username is the mail account name
-- param password is the account password
-- param msg is the message number to operate on (may be decreased dy 1)
-- param pdata is an opaque data for popserver_callback(buffer,pdata) 
-- return POPSERVER_ERR_*
-- ************************************************************************** --
-- COMMENTS SECTION END
-- ************************************************************************** --
-- STRINGS SECTION
-- ************************************************************************** --

sei_string = {
	-- Where is the webmail?
	webmail="webmail.sei.sp.gov.br",
	-- USER and PASS
	-- Where the login happens
	redir="https://%s/src/redirect.php",
	-- What is post to login
	redir_post="login_username=%s&secretkey=%s",
	-- QUIT and QUIT_UPDATE
	-- logout
	logout="https://%s/src/signout.php",
	-- STAT
	-- The 1st web where we're redirected in case a true login. This page builds the frame
	framess="https://%s/src/webmail.php",
	-- Page where the messages are listed, most recent first, and list all msgs!
	msglist="https://%s/src/right_main.php?PG_SHOWALL=1&sort=1&startMessage=1&mailbox=INBOX",
	-- Message list mlex
	statE = ".*<TR>"
			.. ".*<TD>.*<INPUT>.*</TD>"
			.. ".*<TD>[.*]{B}[.*]{FONT}.*{/FONT}[.*]{/B}[.*]</TD>"
			.. ".*<TD>[.*]{B}[.*]{FONT}.*{/FONT}[.*]{/B}[.*]</TD>"
			.. ".*<TD>.*<SMALL>[.*]{FONT}.*{/FONT}[.*]</SMALL>.*</B>.*</TD>"
			.. ".*<TD>[.*]{B}[.*]{FONT}"
			.. ".*<A>"
			.. "[.*]{FONT}.*{/FONT}[.*]</A>.*{/FONT}[.*]{/B}[.*]</TD>"
			.. ".*<TD>[.*]{B}[.*]{FONT}.*<SMALL>.*</SMALL>.*{/FONT}[.*]{/B}[.*]</TD>.*</TR>",
	-- Input size and k|m
	statG = "O<O>"
			.. "O<O>O<X>O<O>"
			.. "O<O>[O]{O}[O]{O}O{O}[O]{O}[O]<O>"
			.. "O<O>[O]{O}[O]{O}O{O}[O]{O}[O]<O>"
			.. "O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>"
			.. "O<O>[O]{O}[O]{O}"
			.. "O<O>"
			.. "[O]{O}O{O}[O]<O>O{O}[O]{O}[O]<O>"
			.. "O<O>[O]{O}[O]{O}X<O>X<O>O{O}[O]{O}[O]<O>O<O>",
			
	-- DELE QUIT_UPDATE
	-- The uri to delete some messages
	delete="https://%s/src/move_messages.php",
	delete_post="mailbox=INBOX&targetMailbox=INBOX&delete=Apagar&location=/src/right_main.php&",
	-- The piece of uri you must append to delete to choose the messages to delete
	delete_next="msg[%d]=%d&",
	-- RETR and TOP
	-- The url to archive a msg
	arquive="https://%s/src/move_messages.php",
	arquive_post="mailbox=INBOX&archiveButton=Arquivar&location=src/right_main.php&",
	arquive_next="msg[%d]=%d&",
	-- Where eml is zipped
	arquivezip="INBOX.zip",
	-- Where we'll to unzip eml in INBOX.ZIP
	arquiveunzip="EMAIL.eml",
	-- Command to unzip used here: (U can use any one that accepts a command line!)
	-- funzip INBOX.zip > EMAIL.eml
	-- funzip/unzip is from http://www.info-zip.org/UnZip.html (Great Job!)
	arquivecmdunzip="funzip %s > %s"
}

-- ************************************************************************** --
-- STRINGS SECTION END
-- ************************************************************************** --
-- STATE SECTION
-- ************************************************************************** --
-- this is the internal state of the plugin. This structure will be serialized
-- and saved to remember the state.

internal_state = {
}

-- ************************************************************************** --
-- STATE SECTION END
-- ************************************************************************** --
-- HELPERS FUNCTIONS SECTION
-- ************************************************************************** --
-- -------------------------------------------------------------------------- --
-- Serialize the internal_state
-- serial. serialize is not enough powerfull to correcly serialize the 
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
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
		(internal_state.password or "")
end
-- ************************************************************************** --
-- HELPERS FUNCTIONS SECTION END
-- ************************************************************************** --
-- SEI WEBMAIL FUNCTIONS SECTION
-- ************************************************************************** --
-- -------------------------------------------------------------------------- --
-- webmail login
--
function sei_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end
	
	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	-- user = name@domain alias btgig@daee.sp.gov.br alias btgig%40daee.sp.gov.br
	local user = internal_state.name.."%40"..internal_state.domain
	
	local uri = string.format(sei_string.redir,sei_string.webmail)
	local post = string.format(sei_string.redir_post,user,password)
	-- 	Checking value creation
	--	log.dbg("uri: '"..uri.."' \n")
	--	log.dbg("post: '"..post.."' \n")

	-- the browser must be preserved
	internal_state.b = browser.new()
	local b = internal_state.b
	--
	-- b:verbose_mode()
	--
	b:ssl_init_stuff()
	
	local f,e = b:post_uri(uri,post)
	if f == nil then
		log.error_print(e)
		local ind = string.find(e,"Connection Refused")
		if ind == nil then		
			return POPSERVER_ERR_UNKNOWN
			else
			return POPSERVER_ERR_AUTH
		end
	end
	-- f now contains cookies info I want? NO
	-- the post response set the cookies:
	-- print (f) :prints a blank line
	-- log.dbg ("file do post: "..f.." \n")  :idem
	-- from now I can access any page!
	-- cookies are managed automatically and any get_uri works!
	
	-- try to access the page that create frames!
	local uri = string.format(sei_string.framess,sei_string.webmail)
	local f,e = b:get_uri(uri)
	if f == nil then
		log.error_print(e)
		return POPSERVER_ERR_UNKNOWN
	end
	-- log.dbg ("get webmail.php: "..f.." \n") 
	
	-- get the cookie value
	--internal_state.cookie_key = (b:get_cookie("key")).value
	--internal_state.cookie_SQMSESSID = (b:get_cookie("SQMSESSID")).value
	--internal_state.cookie_squirrel_language = (b:get_cookie("squirrel_language")).value
	--log.dbg ("internal state key '"..internal_state.cookie_key.."' \n")
	--log.dbg ("internal state SQMSESSID '"..internal_state.cookie_SQMSESSID.."' \n")
	--log.dbg ("internal state squirrel_language '"..internal_state.squirrel_language.."' \n")

	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "\n")

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Logout the webmail after quit and quit_update
--
function logout()
	local b = internal_state.b
	local uri = string.format(sei_string.logout,sei_string.webmail)
	local f,e = b:get_uri(uri)
	local logo = true
	if f == nil then
		-- return false if logout fails
		logo = false
   		log.error_print(e)
		log.error_print("Unable to logout correctly. Wait for the next logon. \n")
		return POPSERVER_ERR_UNKNOWN
	end	
	return logo
end
-- -------------------------------------------------------------------------- --
-- Retrieve a msg and return the data received
-- If lines == "all", all lines will be returned.
-- If lines == integer, n lines will be returned.
--
function sei_retr(pstate,msg,lines,data)
	-- we need the stat
	local st = stat(pstate)
	
	if st ~= POPSERVER_ERR_OK then 
		return st 
	end
	
	local uidl = get_mailmessage_uidl(pstate,msg)
	
	-- shorten names, not really important
	local b = internal_state.b
	local uri = string.format(sei_string.arquive,sei_string.webmail)
	local post = sei_string.arquive_post
				.. string.format(sei_string.arquive_next,msg-1,uidl)

	-- Opening a zip file (INBOX.zip)
	local fz = assert(io.open(sei_string.arquivezip,"wb"))

	-- Get the msg page
	local f,e = b:post_uri(uri,post)
	
	-- Write contents received in zip file
	local t = fz:write(f)

	if f == nil then
		log.error_print(e)
		local ind = string.find(e,"Connection Refused")
		if ind == nil then		
			return POPSERVER_ERR_UNKNOWN
			else
			return POPSERVER_ERR_AUTH
		end
	end

	-- Save any data written to zip file and close file
	fz:flush()
	fz:close()

	-- Command to unzip used here:
	-- funzip INBOX.zip > EMAIL.eml
	-- Unzip first file (the eml file) in EMAIL.eml
	-- You can use any unzipper that accepts a command line and do this!
	-- Info-zip worked here!
	-- funzip/unzip is from http://www.info-zip.org/UnZip.html (Great Job!)
	local cmd = string.format(sei_string.arquivecmdunzip,sei_string.arquivezip,sei_string.arquiveunzip)
	os.execute(cmd)
	
	-- Reading the data EMAIL.eml
	-- If using r (now rb) I read as text and \r\n makes a \r invisible
	-- Thanks Stephen - flabdablet
	--
	local fz = assert(io.open(sei_string.arquiveunzip,"rb"))
	local data1 = fz:read("*all")
	fz:close()

	if lines == "all" then
		-- it's a pop3 command 'retr msg#'
		-- Assuming my limit is 3Mb and my connection is fast enough.
		-- I can send it all, line by line!
		-- print ("All data!\n")
	else
		-- it's a pop3 command 'top msg# lines'
		-- must return headers, blank line separating the headers from the body, and the
		-- number of lines of the indicated msg's body.
		local boundary = 'boundary=%".-%"'
		local header,body = nil,nil 		
		local i,j = string.find(data1,boundary)
		if i ~= nil and j~= nil then
			boundary = "------="
			-- header
			local de,para = string.find(data1,"\r\n\r\n" .. boundary)
			header = string.sub(data1,1,de-1)

			-- body - all lines
			body = string.sub (data1,para+1,-1)
			local de,para = string.find (body,"text%/plain%;")
			body = string.sub (body,para+1,-1)
			boundary = "%-%-%-%-%-%-%="
			local de,para = string.find (body,boundary)
			body = string.sub (body,1,de-1)
			local de,para = string.find(body,"\r\n\r\n")
			body = string.sub (body, para+1,-1)
					
		else
			-- there's no boundary!
		
			-- headers + blank line
			local de,para = string.find(data1,"\r\n\r\n")
			header = string.sub(data1,1,de-1)
			
			-- body - all lines
			body = string.sub (data1,para+1,-1)	
			
		end
		-- print ("header: " .. header .. "\n")
		-- print ("body all lines: " .. body .. "\n")
		
		-- count body lines to retrieve only txt-plain msg lines
		local _,lc = string.gsub (body,"\n","\n")
		if lines > lc then
			lines = lc
		end
		lc = 1
		-- msg body
		local start,cut = 1,nil
		while lc <= lines do
			local de,para = string.find (body, "\n", start)
			if cut ~= nil then
				cut = cut .. string.sub(body,start,para)
			else
				cut = string.sub(body,start,para)
			end
			start = para + 1
			lc = lc +1
		end
		-- header extracted + crlfcrlf + cut: we have header and msg body text plain
		data1 = header .. "\r\n\r\n" .. cut
		-- print (lc-1 .. " lines retrieved")
	end

	-- Remove zip and eml	
	os.remove(sei_string.arquivezip)
	os.remove(sei_string.arquiveunzip)

	-- Correcting the .EML file
	-- No need replacing \n.\n for \n..\n
	-- No need adding \r\n.\r\n at the end of the .eml
	-- POP3 response may be up 512 chars long including crlf(\r\n)
	-- Sends all with only one popserver_callback (data1,data) doesn't work!!
	-- print("data1: \n" .. data1 .. "\n")
	
	-- We must send line per line
	-- Counting data lines
	local _,lc = string.gsub(data1,"\n","\n")
	
	-- Where starts the search of eol = \n
	local start = 1
	
	-- Cutting each line and sending back!
	for i =1, lc do
		local de,para = string.find (data1,"\n",start)	
		local pline = string.sub (data1,start,para)
	
		-- send line
		popserver_callback (pline,data)
	
		-- next line
		start = para + 1
	end
	return
end
-- ************************************************************************** --
-- SEI WEBMAIL FUNCTIONS SECTION END
-- ************************************************************************** --
-- POP3 commands with init function
-- ************************************************************************** --
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)

	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name
	-- name=btgig  domain = daee.sp.gov.br

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
			return sei_login()
		end
		
		-- exec the code loaded from the session string
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "\n")
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return sei_login()
	end
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
    session.unlock(key())
    local logo = logout()
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
--
function quit_update(pstate)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- shorten names, not really important
	local b = internal_state.b
	local uri = string.format(sei_string.delete,sei_string.webmail)
	local post = sei_string.delete_post

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.format(sei_string.delete_next,i-1,get_mailmessage_uidl(pstate,i))
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

	log.say("Session saved for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "\n")
		
	local logo=logout()
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size	OK
-- 
function stat(pstate)
	-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end
	
	-- shorten names, not really important
	local b = internal_state.b

	local uri = string.format(sei_string.msglist,sei_string.webmail)
	local f,e = b:get_uri(uri)
	if f == nil then
		log.error_print(e)
		log.error_print("Unable to open msg list page \n")
		return POPSERVER_ERR_UNKNOWN
	end
	local e = sei_string.statE
	local g = sei_string.statG
	local x = mlex.match(f,e,g)
	
	-- x:print()
	-- Stays like this 3x (*)
	-- {'input type=checkbox name="msg[0]" value="129"','8,1','&nbsp;k'}
	-- {'input type=checkbox name="msg[1]" value="128"','8,1','&nbsp;MByte'}	
	
	-- initialize data structure    
	set_popstate_nummesg(pstate,x:count())
	
	-- store uidl and size in set_mailmessage_size and set_mailmessage_uidl
	for i=1,x:count() do
		-- initialize local vars in appearence order as above (*)
		local uidl = x:get (0,i-1)
		local size = x:get (1,i-1)
		local unik = x:get (2,i-1)
		-- Get only what I want: uidl, size and unit (kbytes or mbytes) -- just value
		_,_,uidl = string.find(uidl,'value=\"(%d+)\"')  
		
		-- size format: 99,99
		--if size == nil then
		--	size = "vazio"
		--end
		-- whe must substitute comma with point! Brazilian number format 9,99!
		size = string.gsub(size,"%p",".")
		
		-- k or mbytes??
		_,_,unik=string.find(unik,'&nbsp;(%a+)')
		
		-- print("uidl: "..uidl.." Size:"..size.." Unik:"..unik.." \n")
		 
		if not uidl or not size then
			log.error_print("Unable to parse page \n")
			log.error_print("Stat failed\n")
			session.remove(key())
			return nil,"Unable to parse page"
		end

		-- arrange size
		size = math.max(tonumber(size),2)
		if unik == "K" or unik=="k" then
			size = size * 1024
		else                             
--		if it's not k its Mbyte!
--      else if unik == "M" or unik =="m" then
			size = size * 1024 * 1024
		end

		-- set it
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
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	-- retrieve msg sends the msg to email client
	sei_retr(pstate,msg,"all",data)
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	-- retrieve lines from the msg and sends lines of the msg to email client
	sei_retr(pstate,msg,lines,data)
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
--  This function is called to initialize the plugin.	OK
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
	if freepops.dofile("serialize.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end 

	-- the browser module
	if freepops.dofile("browser.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end
	
	-- the MIME mail generator module
	if freepops.dofile("mimer.lua") == nil then 
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
-- EOF
-- ************************************************************************** --
