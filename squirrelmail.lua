-- ************************************************************************** --
--  FreePOPs @squirrelmail webmail interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Eddi De Pieri <dpeddi@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.4"
PLUGIN_NAME = "SquirrelMail"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=squirrelmail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Eddi De Pieri"}
PLUGIN_AUTHORS_CONTACTS = {"dpeddi (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@..."}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it=[[
Questo plugin vi permette di leggere le mail in una webmail fatta con
squirrelmail. Il plugin &egrave; molto beta e bisogna modificarlo a mano
per adattarlo al proprio sito. Per ora supporta solo la versione 1.2
di squirrelmail.
]],
	en=[[
This plugin supports webmails made with squirrelmail. You have to hack
by hand the plugin to make it work with your website. since now it
supports only version 1.2.]]
}

-- Tested with debian woody + apache (not ssl) + squirrelmail 1.2.6-1.3
-- To get this plugin working you have to add size to "Options/Index Order" 
-- 	 as last column
-- To avoid to get INBOX.Trash wasting space of your account you should change:
-- 	"Options/Folder Preferences/Trash Folder" -> "Do not use Trash"

-- To do: Automatic recognition of squirrelmail version
-- 	  Automatic recognition of record position (size/object/etc) in list
-- 	  Directly downloading of raw message in newest version of Squirrel
--        Testing with other squirrelmail versions

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
local squirrelmail_string = {
	partial_path = "/squirrelmail";
	-- The uri the browser uses when you click the "login" button
	login = "http://%s%s/src/redirect.php",
	login_post= "login_username=%s&secretkey=%s&"..
		    "js_autodetect_results=0&just_logged_in=1",
	login_failC="(Unknown user or password incorrect.)",
	session_errorC = "(http://[^/]+/squirrelmail/src/redirect.php)",
	loginC = '.*<FRAME.*SRC="(.*)".*NORESIZE.*',
	-- mesage list mlex

	statE = '.*<TR>.*<td><input></TD>.*<td>[.*]{b}.*{/b}[.*]</td>.*<td><center>[.*]{b}.*{/b}[.*]</center></td>.*<td>[.*]{b}<small>.*</small>{/b}[.*]</td>.*<td>[.*]{b}<a>.*</a>{/b}[.*]</td>.*<td>[.*]{b}.*<small>.*</small>{/b}[.*]</td>.*</tr>.*',
	statG = 'O<O>O<O><X><O>O<O>[O]{O}O{O}[O]<O>O<O><O>[O]{O}O{O}[O]<O><O>O<O>[O]{O}<O>O<O>{O}[O]<O>O<O>[O]{O}<O>O<O>{O}[O]<O>O<O>[O]{O}X<O>X<O>{O}[O]<O>O<O>O',

	-- The uri for the first page with the list of messages
	first = "http://%s%s/src/right_main.php",
	-- The uri to get the next page of messages
	nextC ='<A HREF="right_main.php%?use_mailbox_cache=0&amp;startMessage=(%d+)&amp;mailbox=INBOX" TARGET="right">Next</A>',
	next = "http://%s%s/src/right_main.php?use_mailbox_cache=0&startMessage=%d&mailbox=INBOX",

	-- The capture to understand if the session ended
	timeoutC = '(FIXME)',
	-- The uri to save a message (read download the message)
	save = 'http://%s%s/src/read_body.php?mailbox=INBOX&passed_id=%d&startMessage=1&show_more=0',
	save_header = 'http://%s%s/src/read_body.php?mailbox=INBOX&passed_id=%d&startMessage=1&show_more=0&view_hdr=1',
	-- The uri to delete some messages
	delete = "http://%s%s/src/delete_message.php",
	delete_post = "mailbox=INBOX&sort=6&startMessage=1&",
	-- The peace of uri you must append to delete to choose the messages 
	-- to delete
	delete_next = "message=%d&",
	attachE = '.*<TR><TD>.*</TD><TD><A>.*</A>.*</TD><TD><SMALL><b>.*<small>.*</small></b>.*</small></TD><TD><SMALL>.*</SMALL></TD><TD><SMALL>[.*]{b}[.*]{b}[.*]</SMALL></TD><TD><SMALL>.*<a>.*</a>[.*]{a}[.*]{a}[.*]</SMALL></TD></TR>.*',
	attachG = 'O<O><O>O<O><O><X>X<O>O<O><O><O><O>O<O>O<O><O>O<O><O><O><O>O<O><O><O><O>[O]{O}[O]{O}[O]<O><O><O><O>O<O>O<O>[O]{O}[O]{O}[O]<O><O><O>O',	
	attach_begin = '<TABLE%s+WIDTH="100%%"%s+CELLSPACING=0%s+CELLPADDING=2%s+BORDER=0%s+BGCOLOR="#.*"><TR>\n<TH%s+ALIGN="left"%s+BGCOLOR=".*"><B>\nAttachments:</B></TH></TR><TR><TD>\n<TABLE%s+CELLSPACING=0%s+CELLPADDING=1%s+BORDER=0>',
	attach_end = '</TABLE></TD></TR></TABLE></TD></TR></TABLE>',
	body_begin = '<TABLE%s+CELLSPACING=0%s+WIDTH="97%%"%s+BORDER=0%s+ALIGN=CENTER%s+CELLPADDING=0>%s+<TR><TD%s+BGCOLOR=".*"%s+WIDTH="100%%">\n<BR>',
	body_end = '<CENTER><SMALL><A%s+HREF="../src/download.php%?absolute_dl=true&amp;passed_id=%d+&amp;passed_ent_id=%d+&amp;mailbox=INBOX&amp;showHeaders=1">Download%s+this%s+as%s+a%s+file</A></SMALL></CENTER>',
	    
	head_begin= "<table.*width='99%%'.*cellpadding='2'.*cellspacing='0'.*border='0'align=center>\n",
	head_end= '</table>',
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
-- Login to the libero website
--
function mk_cookie(name,val,expires,path,domain,secure)
	local s = name .. "=" .. curl.escape(val)
	if expires then
		s = s .. ";expires=" .. os.date("%c",expires)
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

function squirrelmail_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	local user = internal_state.name
	local uri = string.format(squirrelmail_string.login,domain,squirrelmail_string.partial_path)
	local post = string.format(squirrelmail_string.login_post,user,password)
	
	-- the browser must be preserved
	internal_state.b = browser.new()

	local b = internal_state.b

--	b.curl:setopt(curl.OPT_VERBOSE,1)

	local extract_f = support.do_extract(
		internal_state,"login_url",squirrelmail_string.loginC)
	local check_f = support.check_fail
	local retrive_f = support.retry_n(
		3,support.do_post(internal_state.b,uri,post))
	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end

	if internal_state.login_url == nil then
		log.error_print("unable to get the loginC")
		return POPSERVER_ERR_AUTH
	end

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
	local x = string.match(s,"^%s*(<[Pp][Rr][Ee]>)")
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
	
		s = squirrelmail_string.html_preamble .. s .. 
			squirrelmail_string.html_conclusion

		return nil,s
	end
end

-- -------------------------------------------------------------------------- --
-- Produces a hopefully standard header
--
--
function mangle_head(s)
	local base = "http://" .. internal_state.b:wherearewe()
	s = mimer.html2txtplain(s,base)
	
	local subst = 1
	while subst > 0 do
		s,subst = string.gsub(s,"\n\n","\n")
	end

        s = mimer.remove_tags(s,
		{"tt","nobr","a"})
				       
        s = mimer.remove_lines_in_proper_mail_header(s,{"content%-type",
                "content%-disposition","mime%-version"})

	s = mimer.txt2mail(s)
	return s
end
-- -------------------------------------------------------------------------- --
-- Parse the message an returns head + body + attachments list
--
--
function squirrelmail_parse_webmessage(pstate,msg)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local b = internal_state.b
	
	-- build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(squirrelmail_string.save,b:wherearewe(),squirrelmail_string.partial_path,uidl)
	local urih = string.format(squirrelmail_string.save_header,b:wherearewe(),squirrelmail_string.partial_path,uidl)
	-- get the main mail page
	local f,rc = b:get_uri(uri)

	-- extract the body an the attach
	local from,to = string.find(f,squirrelmail_string.body_begin)
	local from1,to1 = string.find(f,squirrelmail_string.body_end)
	local attach = ""
	local body = ""
	if to1 ~= nil then
--print ("normale")
	   body = string.sub(f,to+1,from1-1)
  	   attach = string.sub(f,from1+1,-1)
	else
--print ("non c'e' body")
	   body = ""
	   attach = string.sub(f,to+1,-1)
	end
--print ( from .. " " .. to .. " " .. from1 .. " " .. to1)


	-- extracts the attach list
	local x = mlex.match(attach,squirrelmail_string.attachE,squirrelmail_string.attachG)
	--x:print()
	
	local n = x:count()
	local attach = {}
	
	for i = 1,n do
		--print("addo fino a " .. n)
		local url = string.match(x:get(0,n-1),'HREF="..([^"]*)"')
		url = string.gsub(url,"&amp;", "&")
		attach[x:get(1,i-1)] = "http://" .. b:wherearewe() .. squirrelmail_string.partial_path .. url
		--print (attach[x:get(1,i-1)] .. " ------ " ..  "http://" .. b:wherearewe() .. squirrelmail_string.partial_path .. url)
	end
	
	-- mangles the body
	local body,body_html = mangle_body(body)
	
	-- gets the header
	local f,rc = b:get_uri(urih)
	
	-- extracts the important part
	local from,to = string.find(f,squirrelmail_string.head_begin)

	local f1 = string.sub(f,to+1,-1)
	local from1,to1 = string.find(f1,squirrelmail_string.head_end)
	local head = string.sub(f1,1,from1-1)

	-- mangles the header
	head = mangle_head(head)

	return head,body,body_html,attach
end

-- ************************************************************************** --
--  squirrelmail functions
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
			return squirrelmail_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return squirrelmail_login()
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
	local uri = string.format(squirrelmail_string.delete,b:wherearewe(),squirrelmail_string.partial_path)
	local post = string.format(squirrelmail_string.delete_post)

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.format(squirrelmail_string.delete_next,
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
	local uri = string.format(squirrelmail_string.first,b:wherearewe(),squirrelmail_string.partial_path)
	
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
	    	local x = mlex.match(s,squirrelmail_string.statE,squirrelmail_string.statG)
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
		for i = 1,n do
--			local size = 10000
			local uidl = x:get (0,i-1) 
			local size = x:get (1,i-1)
			local k = x:get (2,i-1)

			-- arrange message size
--			local k,m = nil,nil
--			k = string.match(size,"([Kk][Bb])")
--			m = string.match(size,"([Mm][Bb])")
			size = string.match(size,"([%.%d]+)")
--			uidl = string.match(uidl,'CHECK_([%d]+)')
			uidl = string.match(uidl,'value=([%d]+)')

			if not uidl or not size then
				return nil,"Unable to parse page"
			end

			-- arrange size
			size = math.max(tonumber(size),2)
			if k ~= nil then
				size = size * 1024
--			elseif m ~= nil then
--				size = size * 1024 * 1024
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
		local nex = string.match(s,squirrelmail_string.nextC)
		if nex ~= nil then
			uri = string.format(squirrelmail_string.next,b:wherearewe(),squirrelmail_string.partial_path,nex)
			-- continue the loop
			return false
		else
			return true
		end
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		--print("getting "..uri)
		local f,err = b:get_uri(uri)
		if f == nil then
			return f,err
		end

		local c = string.match(f,squirrelmail_string.session_errorC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = squirrelmail_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,"Session ended,unable to recover"
			end
			
			b = internal_state.b
			-- popserver has not changed
			
			uri = string.format(squirrelmail_string.first,b:wherearewe(),squirrelmail_string.partial_path)		
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
	local head,body,body_html,attach = squirrelmail_parse_webmessage(pstate,msg)
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
	local head,body,body_html,attach = squirrelmail_parse_webmessage(pstate,msg)
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
	require("serial")

	-- the browser module
	require("browser")
	
	-- the MIME mail generator module
	require("mimer")

	-- the common implementation module
	require("common")
	
	-- checks on globals
	freepops.set_sanity_checks()

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
