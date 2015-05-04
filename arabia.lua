-- ************************************************************************** --
--  FreePOPs @arabia.it webmail interface
--  
--  $Id: arabia.lua,v 1.0 2004/09/29 16:56:35 ramik Exp $
--  
--  Released under the GNU/GPL license
--  Written by Rami Kattan <rkattan @ gmailcom>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.2"
PLUGIN_NAME = "Arabia"
PLUGIN_REQUIRE_VERSION = "0.0.15"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=arabia.lua"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/"
PLUGIN_AUTHORS_NAMES = {"Rami Kattan"}
PLUGIN_AUTHORS_CONTACTS = {"rkattan (at) gmail (.) com"}
PLUGIN_DOMAINS = {"@arabia.com", "@algeriamail.com", "@bahrainmail.com",
                  "@cairomail.com", "@desertmail.com", "@dubaimail.com",
			   "@iraqmail.com", "@jerusalem-mail.com", "@jordanmail.com",
			   "@kuwait-mail.com", "@lebanonmail.com", "@libyamail.com",
			   "@moroccomail.com", "@omanmail.com", "@palestinemail.com", 
			   "@qatarmail.com", "@qudsmail.com", "@saudi-mail.com",
			   "@sudanmail.com", "@syriamail.com", "@tunisiamail.com",
			   "@uaemail.com", "@yemenmail.com"} 
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it=[[
Per usare questo plugin dovrete usare il vostro indirizzo email completo come 
nome utente e la vostra vera password come password.<br/>
UN BETA PLUGIN, non funzionante al 100%.
]],
	en=[[
To use this plugin you have to use your full email address as the username
and your real password as the password.<br/>
The messages deleted by the email client will be deleted from the webmail, and
moved to the trash folder.
]]
}


-- Todo:
-- Messages list -> first page only
-- Message mime format -> 80% yes
-- Delete message -> yes
-- Attachment handling	-> maybe
-- Select folder using params -> no
-- Empty trash after delete -> no

-- ************************************************************************** --
--  strings
-- ************************************************************************** --

-- this are the webmail-dependent strings
--
-- Some of them are incomplete, in the sense that are used as string.format()
-- (read sprintf) arguments, so their %s and %d are filled properly
-- 
-- C, E, G are postfix respectively to Captures (lua string pcre-style 
-- expressions), mlex expressions, mlex get expressions.
-- 
local globals = {
	-- The uri the browser uses when you click the "login" button
	login = "http://www.arabia.com/mail/",
	login_post = "Username=%s&a=1&lang=english&domain=%s&Password=%s&"..
                  "Submit=Sign in!",
	session_errorC = "(TIMEOUTISOVER)",

	-- mesage list mlex
	statE = '.*<tr>.*<td><input></td>.*<td>[.*]{img}[.*]{img}</td>.*<td>.*<a>[.*]{b}.*{/b}[.*]</a>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*</tr>.*',
	statG = 'O<O>O<O><O><O>O<O>[O]{O}[O]{O}<O>O<O>O<X>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>O',

	-- The uri for the first page with the list of messages
	-- GUID=%s&
	first = "http://mail.arabia.com/mail/ms_inbox.asp?Current_folder=/INBOX",
	-- The uri to get the next page of messages
	nextC = "message%s(%d+)-(%d+),%stotal:%s(%d+)",
	next = "http://mail.arabia.com/mail/ms_inbox.asp?next page ????",

	-- The capture to understand if the session ended
	timeoutC = '(FIXME)',
	-- The uri to save a message (read download the message)
	save = 'http://mail.arabia.com/mail/ms_message.asp?MsgID=%s&SM=F&FolderName=/Inbox&DisplayHeaders=0',

	headers = '<b>Headers</b>&nbsp;&nbsp;</font></td>%s*<td valign=top><font face="Arial, Helvetica, sans%-serif" size=1 style="font%-size:11px">(.-)</font></td>',
	body= '<base target="_blank">%s*<font face="Arial, Helvetica, sans%-serif" size=2>(.-)<br><br>&nbsp;</font>%s*<base target="main">',

	-- The uri to delete some messages, one by one :(
	-- http://mail.arabia.com/js/ms_inbox.js
	delete = "http://mail.arabia.com/mail/action/deletemessage.asp?"..
	         "CurrentCachedFolder=Inbox&SM=F&FolderName=Inbox&"..
		    "messageaction=folder&MsgID=%s",
--	delete = "http://mail.arabia.com/mail/ms_inbox.asp",
	-- The peace of uri you must append to delete to choose the messages 
	-- to delete
--	delete_next = "MsgID=%s&",

	attachE = '<a.*href.*getFile.*asp.GUID>.*</a>',
	attachG = '<O>X<O>',
   
	html_preamble = [[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD 4.0 Transitional//EN">
<HTML>
<HEAD>
	<META http-equiv="Content-type" content="text/html;charset=iso-8859-1">
	<META content="MSHTML 6.00.2800.1400" name="FPGENERATOR" >
	<STYLE type="text/css">
	<!--
 	body {
	color: #000000;
	font-family: Helvetica;
  	}
	-->
	</STYLE>
</HEAD>
<BODY>]],
	html_conclusion = [[
</BODY>
</HTML>]]

}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {}

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
-- Ths key must be unique for all webmails, since the session pool is one 
-- for all the webmails
--
function key()
	return (internal_state.name or "")..
		(internal_state.domain or "")..
		(internal_state.password or "")
end

--------------------------------------------------------------------------------
-- Login to the arabia website
--

function arabia_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local domain = internal_state.domain
	local uri = globals.login
	local post = string.format(globals.login_post,internal_state.name,domain,internal_state.password)
	--print ( "DEBUG: " .. uri )

	-- the browser must be preserved
	internal_state.b = browser.new()

	local b = internal_state.b
	b:verbose_mode()

	--b.curl:setopt(curl.OPT_VERBOSE,1)
	local f,e = b:post_uri(uri,post)
--	log.say(f)
	if b:whathaveweread() ~= "http://mail.arabia.com:80/main.asp" then
		return POPSERVER_ERR_AUTH
	end
--	internal_state.GUID = (b:get_cookie("GUID")).value
--	log.say("GUID Cookie: "..internal_state.GUID.."\n")

	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "\n")

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Produces a better body to pass to the mimer
--
--
function mangle_body(s)
	local _,_,x = string.find(s,"^%s*(<[Pp][Rr][Ee]>)")
	if x ~= nil then
		local base = "http://" .. internal_state.b:wherearewe()
		s = mimer.html2txtmail(s,base)
		return s,nil
	else
	
	        s = mimer.remove_lines_in_proper_mail_header(s,{"content%-type",
	                "content%-disposition","mime%-version"})				

		-- the webmail damages these tags
		s = mimer.remove_tags(s,
			{"html","head","body","doctype","void","style"})
	
		s = globals.html_preamble .. s .. 
			globals.html_conclusion

		return nil,s
	end
end

-- -------------------------------------------------------------------------- --
-- Parse the message an returns head + body + attachments list
--
--
function arabia_parse_webmessage(pstate,msg)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local b = internal_state.b
	
	-- body handling: build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(globals.save,uidl)

	-- get the main mail page
	local f,rc = b:get_uri(uri)

	local _,_,headers = string.find(f,globals.headers)
	headers = string.gsub(headers,"<br>","\r\n")
	headers = string.gsub(headers,"&lt;","<")
	headers = string.gsub(headers,"&gt;",">")
	headers = string.gsub(headers,"&quot;",'"')

-- remove 2 headers that will be added later with the FP Mimer
	headers = string.gsub(headers,"\r\nMIME%-Version:.-\r\n",'\r\n')
	headers = string.gsub(headers,"\r\nMime%-Version:.-\r\n",'\r\n')
	headers = string.gsub(headers,"\r\nContent%-Type:.-\r\n",'\r\n')
	headers = headers .. "\r\n"

	local _,_,body = string.find(f,globals.body)
	body = string.gsub(body, "<br>.<br>$", "")


	-- extracts the attach list
	local x = mlex.match(f,globals.attachE,globals.attachG)
	
	local n = x:count()
	local attach = {}
	
	for i = 1,n do
		--print("addo fino a " .. n)
		local url = "http://mail.arabia.com/tools/getFile.asp?MsgID="..uidl.."&name=X*"..i
		local fname = x:get(0,i-1)
		attach[fname] = url
		table.setn(attach,table.getn(attach) + 1)
	end
	
	-- mangles the body
	local body_html = body
	return headers,nil,body_html,attach
end

-- ************************************************************************** --
--  arabia functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name
	
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
			return arabia_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return arabia_login()
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
	local uri = globals.delete
	local DelUri

	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			DelUri = string.format(uri, get_mailmessage_uidl(pstate,i))
			_,_ = b:get_uri(DelUri)
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

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later
	local uri = globals.first
		
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
	    	local x = mlex.match(s,globals.statE,globals.statG)
		-- x:print()

		-- the number of results
		local n = x:count()

		log.say("Total number of messages is: "..n.."<<<<<\n")

		if n == 0 then
			return true,nil
		end 

		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		local nmesg_old = get_popstate_nummesg(pstate)
		local nmesg = nmesg_old + n
		set_popstate_nummesg(pstate,nmesg)

		-- gets all the results and puts them in the popstate structure
		for i = 1,n do
			local uidl = x:get (0,i-1) 
			local size = x:get (1,i-1)

			-- arrange message size
			local k,m = nil,nil
			_,_,k = string.find(size,"([Kk])&nbsp;")
			_,_,m = string.find(size,"([Mm])&nbsp;")
			_,_,size = string.find(size,"&nbsp;([%.%d]+)")
			_,_,uidl = string.find(uidl,'MsgID=([%w%-]+)&')

			if not uidl or not size then
				return nil,"Unable to parse page"
			end

			-- arrange size
			size = math.max(tonumber(size),2)
			if k ~= nil then
				size = size * 1024
			elseif m ~= nil then
				size = size * 1024 * 1024
			end

			-- set it
			set_mailmessage_size(pstate,i+nmesg_old,size)
			set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
		end
		return true,nil
	end 

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function check_f (s) 
	-- i removed all the checks here RRR
		return true
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		--print("getting "..uri)
		local f,err = b:get_uri(uri)
		if f == nil then
			return f,err
		end

		local _,_,c = string.find(f,globals.session_errorC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = arabia_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,"Session ended,unable to recover"
			end
			
			b = internal_state.b
			-- popserver has not changed
			
			uri = string.format(globals.first,internal_state.name,internal_state.password)

			return b:get_uri(uri)
		end
		
		return f,err
	end

	-- this to initialize the data structure
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
function retr(pstate,msg,data)
	local head,body,body_html,attach = arabia_parse_webmessage(pstate,msg)
	local b = internal_state.b
	
	mimer.pipe_msg(
		head,body,body_html,
		"http://" .. b:wherearewe(),attach,b,
		function(s)
			popserver_callback(s,data)
		end)

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	local head,body,body_html,attach = arabia_parse_webmessage(pstate,msg)
	local e = stringhack.new()
	local purge = false
	local b = internal_state.b

	mimer.pipe_msg(
		head,body,body_html,
		"http://" .. b:wherearewe(),attach,b,
		function(s)
			if not purge then
				s = e:tophack(s,lines)
				
				popserver_callback(s,data)
				if e:check_stop(lines) then 
					purge = true
					return true 
				end
			end
		end)

	return POPSERVER_ERR_OK
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
