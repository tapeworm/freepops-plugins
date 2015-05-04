-- ************************************************************************** --
--  FreePOPs @--LogonSoftware-- webmail interface
-- 
--  $Id: logonsw.lua,v 1.7 2006/03/11 01:30 gareuselesinge Exp $
-- 
--  Released under the GNU/GPL license
--  Written by --Matteo Turconi-- <--matteo.turconi@logonsw.it-->
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.5"
PLUGIN_NAME = "LogonSW.IT"
PLUGIN_REQUIRE_VERSION = "0.0.97"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=logonsw.lua"
PLUGIN_HOMEPAGE = "http://matteo1164.interfree.it/"
PLUGIN_AUTHORS_NAMES = {"Matteo Turconi"}
PLUGIN_AUTHORS_CONTACTS = {"matteo.turconi@logonsw.it"}
PLUGIN_DOMAINS = {"@logonsw.it"}
PLUGIN_PARAMETERS = { 
	{name="---na---", 
	 description={en="---na---",it=="---na---"}},
}
PLUGIN_DESCRIPTIONS = {
	it="Questo plugin &egrave; per gli account di posta del portale logonsw.it. "..
	   "Utilizzare lo username completo di dominio e l'usuale password. ",
	en="This plugin is for the webmail of Logon Software employees only."
}

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

-- ************************************************************************** --
--  strings
-- ************************************************************************** --
local logonsw_string = {
	-- The uri the browser uses when you click the "login" button
	login_url = "http://mail.logonsw.it/openwebmail-cgi/openwebmail.pl",		
	login_post = "loginname=%s&password=%s&login=Login",		
	-- This is the capture to get the session ID from the login-done webpage
    sessionC = "sessionid=([%w%.]+@[%w%.%-]+)&",
	inbox_url = "http://mail.logonsw.it/openwebmail-cgi/openwebmail-main.pl"
		.."?sessionid=%s&action=displayheaders_afterlogin&firstmessage=%d",
	del_url = "http://mail.logonsw.it/openwebmail-cgi/openwebmail-main.pl",
	statE = ".*<tr>.*<td>[.*]{B}.*{/B}[.*]<a>[.*]{img}.*</a>[.*]{img}.*</td>.*<td>[.*]{B}.*<font>.*</font>.*{/B}[.*]</td>"
			..".*<td>[.*]{B}.*<a>.*</a>.*{/B}[.*]</td>.*<td>[.*]{B}.*<a>.*</a>.*{/B}[.*]</td>.*<td>[.*]{B}.*{/B}[.*]</td>"
			..".*<td>.*<[Ii][Nn][Pp][Uu][Tt].*[Vv][Aa][Ll][Uu][Ee].*=.*[[:digit:]]+.*>.*</td>.*</tr>",
	statG = "O<O>O<O>[O]{O}O{O}[O]<O>[O]{O}O<O>[O]{O}O<O>O<O>[O]{O}O<O>O<O>O{O}[O]<O>O<O>[O]"
			.."{O}O<O>O<O>O{O}[O]<O>O<O>[O]{O}O<O>O<O>O{O}[O]<O>O<O>[O]{O}X{O}[O]<O>O<O>O<X>O<O>O<O>",
	next_page = "IMG alt=\">\"",
	next_page_url = "http://mail.logonsw.it/openwebmail-cgi/openwebmail-main.pl?sessionid=%s&folder=INBOX&"
				.."action=displayheaders&firstmessage=%d",
	get_html_str = "http://mail.logonsw.it/openwebmail-cgi/openwebmail-read.pl?sessionid=%s&searchtype=subject&folder=INBOX"
				.."&message_id=%s&action=readmessage&attmode=simple&headers=all",
	attach4E = ".*<table>.*<tr>.*<td>.*<font>[.*]{/font}.*</td>.*</tr>[.*]{tr}[.*]{td}[.*]{br}[.*]{br}[.*]{/td}.*"
			.."<td>.*<a.*[[:digit:]]+.*>[.*]{img}.*</a>.*</td>.*</tr>.*</table>",
	attach4G = "O<O>O<O>O<O>O<O>[O]{O}O<O>O<O>[O]{O}[O]{O}[O]{O}[O]{O}[O]{O}O<O>O<X>[O]{O}O<O>O<O>O<O>O<O>",
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

-- this table contains the realtion between the mail address domain, the
-- webmail domain name and the mailbox domain
local logonsw_domain = {
	["logonsw.it"] = { website=".logonsw.it",        choice="logonsw" },
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
	domain = nil,
	name = nil,
	password = nil,
	b = nil
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Checks the validity of a domain
--
function check_domain(domain)
	return 	logonsw_domain[domain] ~= nil
end

--------------------------------------------------------------------------------
-- Extract Header from HTML
-- s: string webmessage
-- hs: header string to find
-- es: end string
--
function extract_header_tag(s,hs,es)
	local i,j,str
	
	i = 0
	j = 0
	i,_ = string.find(s,hs)
	_,j = string.find(s,es, i)
	if i == nil or j == nil then 
		str = nil
	else
		str = string.sub(s,i,j)
	end
	if str ~= nil then
		local subst = 1
		while subst > 0 do
			str,subst = string.gsub(str,"\n\n","\n")
		end
		local base = "http://" .. internal_state.b:wherearewe()
		str = mimer.html2txtplain(str,base)
	end
	return str
end

--------------------------------------------------------------------------------
-- Extract more then one occurence of the same header from HTML
-- s: string webmessage
-- hs: header string to find
-- es: end string
-- ml: multi line
-- mls: multi line string
--
function extract_multiheader_tag(s,hs,es,ml,mls)
	local done = false
	local j,i,str
	j = 1
	i = 0
	while not done do 
		i,j = string.find(s,hs,j-1)
		if i == nil or j == nil then
			done = true
			str = nil
		else
			j,_ = string.find(s,es,j)
			str = string.sub(s,i,j-1)
		end
		if str ~= nil then
			if ml then
				str = string.gsub(str, "("..mls..")", "")
			end
			local subst = 1
			while subst > 0 do
				str,subst = string.gsub(str,"\n\n","\n")
			end
			local base = "http://" .. internal_state.b:wherearewe()
			str = mimer.html2txtplain(str,base)
		end
	end
	return str
end

-- -------------------------------------------------------------------------- --
-- Produces a better body to pass to the mimer
--
--
function mangle_body(s)
	local x = "class=msgbody"
	local y = "</[Tt][Aa][Bb][Ll][Ee]>"
	local z = ">Allegato"
	local start_body = ">"
	local w = "<[Tt][Aa][Bb][Ll][Ee]"
	local body,i,j,k,bstart,bend

	body = " "
	bstart = 0
	bend = 0
	i,j = string.find(s,x)
	i,j = string.find(s,start_body,j)
	if j ~= nil then
		bstart = j + 1
	end
	
	i,j = string.find(s,y,bstart)
	if i ~= nil and j ~= nil then
		k,_ = string.find(s,z,bstart)
		if k == nil then
			bend = j
		else
			if k > i then
				bend = j
			end
			if i > k then
				i,_ = string.find(s,w,bstart)
				bend = i - 1
			end
		end
	end
	body = string.sub(s,bstart,bend)
	
	log.dbg("\n"..body.."\n")
	-- the webmail damages these tags
	body = mimer.remove_tags(body,
		{"html","head","body","doctype","void","style"})
	
	body = logonsw_string.html_preamble..body..logonsw_string.html_conclusion
	
	log.dbg("\n"..body.."\n")
	
	return nil,body
end

-- ************************************************************************** --
--  Logon SW functions
-- ************************************************************************** --

-- Is called to initialize the module
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!")

	-- the serialization module
	-- if freepops.dofile("serialize.lua") == nil then 
	-- 	return POPSERVER_ERR_UNKNOWN 
	-- end 

	-- the browser module
	if freepops.dofile("browser/browser.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end
	
	-- the common implementation module
	if freepops.dofile("common.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end
	
	-- the mimer implementation module
	if freepops.dofile("mimer.lua") == nil then 
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
	local post_data = string.format(logonsw_string.login_post, user, pwd)
	log.dbg("*** post_data '"..post_data.."'")
	local post_uri = logonsw_string.login_url
	log.dbg("*** post_uri '"..post_uri.."'")

	-- the browser must be preserved
	internal_state.b = browser.new()
	local b = internal_state.b
	-- b:verbose_mode()
	-- get first page
	local file,err = nil,nil
	-- file,err = b:get_uri(post_uri)
	-- post login request
	file,err = b:post_uri(post_uri,post_data)

	-- search the session ID
	local _,_,id = string.find(file,logonsw_string.sessionC)
	internal_state.session_id = id
	
	-- check if do_extract has correctly extracted the session ID
	if internal_state.session_id == nil then
		log.error_print("Login failed, unable to get session ID!")
		return POPSERVER_ERR_AUTH
	end
	
	log.dbg("*** session_id '"..internal_state.session_id.."'")
	internal_state.login_done = true	
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. 
		"(" .. internal_state.session_id .. ")\n")
		
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
	local session_id = internal_state.session_id
	local b = internal_state.b
	
	local post_del_str = "action=movemessage&sessionid=%s&keyword=&searchtype=subject&folder=INBOX&destination=mail-trash"
	local msg_ids_str = "&message_ids=%s"

	local post_data = string.format(post_del_str,session_id)
	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			local uidl = get_mailmessage_uidl(pstate,i)
			-- eliminate all unescape from uidl
			uidl = string.gsub(uidl, "(&lt;)", "%%3C")
			uidl = string.gsub(uidl, "(@)", "%%40")
			uidl = string.gsub(uidl, "(&gt;)", "%%3E")
			post_data = post_data .. string.format(msg_ids_str,uidl)
			delete_something = true
		end
	end

	-- log data to post
	log.dbg("*** data "..post_data)
	
	if delete_something then
		log.dbg("*** delete_something true")
		local file,err = nil,nil
		file,err = b:post_uri(logonsw_string.del_url,post_data)
		if err then
			log.dbg("post_uri::"..err)
			return POPSERVER_ERR_NETWORK
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
	local uri = string.format(logonsw_string.inbox_url,session_id,page)
	log.dbg("*** uri "..uri)
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s)
		log.dbg("--- function action_f")
		
		-- match in webpage	
		local x = mlex.match(s,logonsw_string.statE,logonsw_string.statG)	
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
			local uidl = x:get (1,i-1) 
			local size = x:get (0,i-1)
			log.dbg("*** uidl "..uidl)
			log.dbg("*** size "..size)
			
			local k = nil
			_,_,k = string.find(size,"([Kk][Bb])")
			_,_,size = string.find(size,"(%d+)")
			_,_,uidl = string.find(uidl,"VALUE=\"(.*)\"")
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
		local tmp1,tmp2 = string.find(s,logonsw_string.next_page)
		if tmp1 ~= nil then
			local get_next_str = logonsw_string.next_page_url
			page = page + 20
			-- change retrive behaviour
			uri = string.format(get_next_str,session_id,page)
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
	
	-- some local stuff	
	local b = internal_state.b

	log.dbg("*** msg "..msg)
	
	-- build the uri
	local session_id = internal_state.session_id
	local uidl = get_mailmessage_uidl(pstate,msg)
	-- eliminate all unescape from uidl
	uidl = string.gsub(uidl, "(&lt;)", "%%3C")
	uidl = string.gsub(uidl, "(@)", "%%40")
	uidl = string.gsub(uidl, "(&gt;)", "%%3E")
	local uri = string.format(logonsw_string.get_html_str,session_id,uidl)
	
	-- prepare headers for mimer
	local head = ""
	log.dbg("*** b:get_uri "..uri)
	local f,_ = b:get_uri(uri)
	
	if f == nil then
		return POPSERVER_ERR_NETWORK
	end

	local str

	-- Return-Path
	log.dbg("Search Return-Path..")
	str = extract_header_tag(f,"Return%-Path:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Received
	log.dbg("Search Received..")
	str = extract_multiheader_tag(f,"Received:","<[Bb]>",true,"<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Message-ID
	log.dbg("Search Message-ID..")
	str = extract_header_tag(f,"Message%-ID:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- From
	log.dbg("Search From..")
	str = extract_header_tag(f,"From:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- To
	log.dbg("Search To..")
	str = extract_header_tag(f,"To:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Subject
	log.dbg("Search Subject..")
	str = extract_header_tag(f,"Subject:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Date
	log.dbg("Search Date..")
	str = extract_header_tag(f,"Date:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- X-Priority
	log.dbg("Search X-Priority..")
	str = extract_header_tag(f,"X%-Priority:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- X-MSMail-Priority
	log.dbg("Search X-MSMail-Priority..")
	str = extract_header_tag(f,"X%-MSMail%-Priority:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- X-Mailer
	log.dbg("Search X-Mailer..")
	str = extract_header_tag(f,"X%-Mailer:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end		
	-- X-MimeOLE
	log.dbg("Search X-MimeOLE..")
	str = extract_header_tag(f,"X%-MimeOLE:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- X-MS-Has-Attach
	log.dbg("Search X-MS-Has-Attach..")
	str = extract_header_tag(f,"X%-MS%-Has%-Attach:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Thread-Topic
	log.dbg("Search Thread-Topic..")
	str = extract_header_tag(f,"Thread%-Topic:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	-- Thread-Index
	log.dbg("Search Thread-Index..")
	str = extract_header_tag(f,"Thread%-Index:","<[Bb][Rr]>")
	if str ~= nil then
		log.dbg("string.find "..str)
		head = head..str
	end
	
	log.say("\n\n"..head)
	-- attachments
	-- match in webpage	
	local x = mlex.match(f,logonsw_string.attach4E,logonsw_string.attach4G)
	log.dbg("*** mlex.match")
	local n = x:count()
	log.dbg("*** x:count "..n)
	local attach = {}
	
	for i = 1,n do
		local href = x:get (0,i-1)
		log.dbg("*** href "..href)
		
		local _,_,name = string.find(href,"viewatt%.pl/(.*)%?")
		-- print("addo fino a " .. n)
		local _,_,url = string.find(href,'href="([^"]*)"')
		local base = "http://" .. internal_state.b:wherearewe()
		url = mimer.html2txtplain(url,base)
		attach[name] = base..url
		table.setn(attach,table.getn(attach) + 1)
		log.dbg("\nattach: "..name.."\nURL: "..attach[name])
	end
	
	-- get body and body_html
	local body,body_html = mangle_body(f)
	
	-- retrive message
	mimer.pipe_msg(
		head,body,body_html,
		"http://" .. b:wherearewe(),attach,b,
		function(s)
			popserver_callback(s,pdata)
		end)

	log.dbg("--- return retr")
	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
