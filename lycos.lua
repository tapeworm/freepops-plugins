-- ************************************************************************** --
--  FreePOPs @lycos.it webmail interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.5"
PLUGIN_NAME = "Lycos.IT (this plugin doesn't work!)"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "-------"
PLUGIN_HOMEPAGE = "---------"
PLUGIN_AUTHORS_NAMES = {"--- "}
PLUGIN_AUTHORS_CONTACTS = {"-----"}
PLUGIN_DOMAINS = {"@..."}
PLUGIN_PARAMETERS = { 
	{name="--name--", description={en="--desc--",it=="--desc--"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[
questo plugin non fa la dele e la top/retr. E' a met&agrave; in quanto lycos viene gestito da owa.lua.	
]],
	en=[[
this plugin cant' do a delete and retr/top. this is half done since 
now the lycos webmail is served by the owa.lua plugin.
]]
}

-- XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
-- this plugin cant' do a delete and retr/top. this is half done since 
-- now the lycos webmail is served by the owa.lua plugin
-- XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX






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
local lycos_mbox_id = {
	inbox = 5,
	spam = 13,
	altro = 16,
	sent = 6,
	dust = 7,
	draft = 12,
}

local lycos_string = {
	-- The uri the browser uses when you click the "login" button
	prelogin = "http://secure.mail.lycos.it/",
	login = "http://secure.mail.lycos.it/lsu/signin/action.jsp",
	login_post = "login=%s&password=%s&act=30",

	login_failC="(warning.gif.*la password digitata.*errata)",
	session_errorC = "(http://[^/]+/Europe/Bin/Utils/error.jsp)",
	loginC = '<frame[^>]*src="([^"]+)"[^>]*target="_top"',
	-- mesage list mlex
	stat = '<input%s*class="lstchk"%s*value="(%d+)"'..
		'%s*name="chkitem"%s*type="checkbox">',
	-- The uri for the first page with the list of messages
	first = "http://%s/app/msg/mail/list.jsp?id=%d",
	-- The uri to get the next page of messages
	nextC ='(http://images.lycos.europe.com/m/comc/lycos/nav/R.gif)',
	next = "http://%s/app/msg/mail/list.jsp?id=%d&f=%d",

	-- The capture to understand if the session ended
	timeoutC = '(FIXME)',
	-- The uri to save a message (read download the message)
	save = "http://%s/app/msg/mail/read/view.jsp?id=%d",
	save = "http://%s/Europe/Bin/Mail/Features/MailContent/mailContent.jsp?MESSAGEID=%d&PARENTID=5&MYSORT=-1",
	save_header = "http://%s/Europe/Bin/Mail/Features/MailContent/headerContent.jsp?MESSAGEID=%d",
	-- The uri to delete some messages
	delete = "http://%s/Europe/Bin/Mail/Features/FolderContent/actionFolderContent.jsp",
	delete_post = "ACTION=3&FOLDERID=7&",
	-- The peace of uri you must append to delete to choose the messages 
	-- to delete
	delete_next = "CHECK_%d=1&",
	attachE = '.*<div class="listNA">.*<script>.*</script>.*<div class="w250L">.*<a title="Download">.*<script>.*</script>.*</a>.*</div>.*<div class="w150L">.*<a>.*</a>.*</div>.*<div class="breaker">.*</div>',
	attachG = "O<O>O<O>O<O>O<O>O<X>O<O>O<O>X<O>O<O>O<O>O<O>O<O><O>O<O>O<O>",
	attach_begin = '</div>%s+</div>%s+<div style="overflow%-x:auto;padding%-bottom:25px;" class="whitecontent"><P>',
	attach_end = '\n</P>\n%s+</div>\n',
	head_begin = '<div style="text%-align:left;" class="whitecontent">',
	head_end = '</div>',
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

function lycos_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	local username = internal_state.name
	local uri = lycos_string.login
	local post = string.format(lycos_string.login_post,username,password)
	
	-- the browser must be preserved
	internal_state.b = browser.new()

	local b = internal_state.b
	--b:verbose_mode()

	b:get_uri(lycos_string.prelogin)
	
	local extract_f = support.do_extract(
		internal_state,"login_url",lycos_string.loginC)
	local check_f = support.check_fail
	local retrive_f = support.retry_n(
		3,support.do_post(internal_state.b,uri,post))

	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end

	if internal_state.login_url == nil then
		log.error_print("unable to get the first loginC")
		return POPSERVER_ERR_AUTH
	end
	local uri = "http://" .. b:wherearewe() .. internal_state.login_url

	local body,err = b:get_uri(uri)

	if body == nil then
		log.error_print("login falied, unable to get the mail site")
		return POPSERVER_ERR_AUTH
	end
	b:show()
	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "\n")

	internal_state.folder=5
		
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
		-- the webmail damages these tags
		s = mimer.remove_tags(s,
			{"html","head","body","doctype","void","style"})
	
		s = lycos_string.html_preamble .. s .. 
			lycos_string.html_conclusion

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
	
	s = mimer.remove_lines_in_proper_mail_header(s,{"content%-type",
		"content%-disposition","mime%-version"})

	s = mimer.txt2mail(s)
	return s
end
-- -------------------------------------------------------------------------- --
-- Parse the message an returns head + body + attachments list
--
--
function lycos_parse_webmessage(pstate,msg)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local b = internal_state.b
	
	-- build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(lycos_string.save,b:wherearewe(),uidl)
	local urih = string.format(lycos_string.save_header,b:wherearewe(),uidl)
	
	-- get the main mail page
	local f,rc = b:get_uri(uri)
	if f == nil then
		log.error_print(rc)
		return nil
	end
	
	-- extract the body an the attach
	local from,to = string.find(f,lycos_string.attach_begin)
	local f1 = string.sub(f,to+1,-1)
	local from1,to1 = string.find(f1,lycos_string.attach_end)
	local body = string.sub(f1,1,from1-1)
	local attach = string.sub(f1,from1,-1)
	
	-- extracts the attach list
	local x = mlex.match(attach,lycos_string.attachE,lycos_string.attachG)
	--x:print()
	
	local n = x:count()
	local attach = {}
	
	for i = 1,n do
		--print("addo fino a " .. n)
		local url = string.match(x:get(0,n-1),'href="([^"]*)"')
		attach[x:get(1,n-1)] = "http://" .. b:wherearewe() .. url
		table.setn(attach,table.getn(attach) + 1)
	end
	
	-- mangles the body
	local body,body_html = mangle_body(body)
	
	-- gets the header
	local f,rc = b:get_uri(urih)
	
	-- extracts the important part
	local from,to = string.find(f,lycos_string.head_begin)
	local f1 = string.sub(f,to+1,-1)
	local from1,to1 = string.find(f1,lycos_string.head_end)
	local head = string.sub(f1,1,from1-1)
	
	-- mangles the header
	head = mangle_head(head)
	
	return head,body,body_html,attach
end

-- ************************************************************************** --
--  Lycos functions
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
			return lycos_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return lycos_login()
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
	local uri = string.format(lycos_string.delete,b:wherearewe())
	local post = string.format(lycos_string.delete_post)

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.format(lycos_string.delete_next,
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
	local uri = string.format(
		lycos_string.first,b:wherearewe(),internal_state.folder)
	
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		local mails = {}
		string.gsub(s,lycos_string.stat,
			function(uid)
				table.insert(mails,uid) 
			end)
		
		local n = table.getn(mails)
		
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
			local uidl = mails[i] 
			local size = 1

			if not uidl or not size then
				return nil,"Unable to parse page"
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
		local nex = string.match(s,lycos_string.nextC)
		if nex ~= nil then
			uri = string.format(
				lycos_string.next,
				b:wherearewe(),
				internal_state.folder,
				get_popstate_nummesg(pstate))
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

		--local real_uri = string.match(f,lycos_string.loginC)

		--local f,err = b:get_uri("http://" .. b:wherearewe() .. real_uri)
		--if f == nil then
		--	return f,err
		--end

		local c = string.match(f,lycos_string.session_errorC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = lycos_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,"Session ended,unable to recover"
			end
			
			b = internal_state.b
			-- popserver has not changed
			
			uri = string.format(
				lycos_string.first,
				b:wherearewe(),
				internal_state.folder)		
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
	local head,body,body_html,attach = lycos_parse_webmessage(pstate,msg)
	local b = internal_state.b

	if head == nil then
		return POPSERVER_ERR_UNKNOWN
	end
	
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
	local head,body,body_html,attach = lycos_parse_webmessage(pstate,msg)
	local e = stringhack.new()
	local purge = false
	local b = internal_state.b

	if head == nil then
                return POPSERVER_ERR_UNKNOWN
        end
	
	mimer.pipe_msg(
		head,body,body_html,
		"http://" .. b:wherearewe(),attach,b,
		function(s)
			if not purge then
				s = e:tophack(s,lines)
				
				popserver_callback(s,data)
				if e:check_stop(lines) then 
					if(string.sub(s,-2,-1) ~= "\r\n") then
					  popserver_callback("\r\n",data)
					end	
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
