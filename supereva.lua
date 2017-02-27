-- ************************************************************************** --
--  FreePOPs Supereva webmail interface
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
-- ************************************************************************** --

PLUGIN_VERSION = "0.2.7c"
PLUGIN_NAME = "Supereva"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=supereva.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org"
PLUGIN_AUTHORS_NAMES = {"Andrea Dalle Molle","Enrico Tassi","Visioning","Viruzzo"}
PLUGIN_AUTHORS_CONTACTS = {"Tund3r (at) fastwebnet (dot) it","gareuselesinge (at) users (dot) sourceforge (dot) net","unknown","unknown"}
PLUGIN_DOMAINS = {"@supereva.it","@supereva.com","@freemail.it","@freeweb.org","@mybox.it","@superdada.com",
	"@cicciociccio.com","@mp4.it","@dadacasa.com","@clarence.com","@concento.it","@dada.net"}
PLUGIN_REGEXES = {}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it=[[Questo plugin consente di scaricare la posta del portale supereva.it]],
	en=[[This plugin is for the supereva.it portal]]
}

-- ------------------------------------------------------------------------ --
-- Global plugin state
supereva_globals = {
	username = nil,
	password = nil,
	browser = nil,

	stat_done = false
}

-- ------------------------------------------------------------------------ --
--  Constants
local supereva_strings = {
	login_uri = "http://sso.dada.it/cgi-bin/sso/login.cgi", --"http://it.email.dada.net/cgi-bin/sso/login.cgi", -- "http://it.email.dada.net/cgi-bin/sn_my/login.chm",
	login_data = "username=%s&password=%s",

	inbox_uri = "http://email.dada.it/cgi-bin/main.chm?mlt_msgs=",
	get_uri = "http://email.dada.it/cgi-bin/nrmail03.chm?msgnum=",

	inbox_e = "" ..
		"<tr>.*" ..
		"<td>.*<input>.*</td>.*" ..
		"<td>.*</td>.*" ..
		"<td>.*<div>[.*]{b}[.*]{/b}.*{b}[.*]<a>[.*]{b}.*{/b}[.*]</a>[.*]{/b}.*</div>.*</td>.*" ..
		"<td>[.*]{b}.*{/b}[.*]</td>.*" ..
		"<td>[.*]{b}.*{/b}[.*]</td>.*" ..
		"<td>.*{img}[.*]</td>.*" ..
		"<td>[.*]{b}.*{/b}[.*]</td>.*" ..
		"</tr>.*",

	inbox_g = "" ..
		"<O>O" ..
		"<O>O<X>O<O>O" ..
		"<O>O<O>O" ..
		"<O>O<O>[O]{O}[O]{O}O{O}[O]<O>[O]{O}O{O}[O]<O>[O]{O}O<O>O<O>O" ..
		"<O>[O]{O}O{O}[O]<O>O" ..
		"<O>[O]{O}O{O}[O]<O>O" ..
		"<O>O{O}[O]<O>O" ..
		"<O>[O]{O}X{O}[O]<O>O" ..
		"<O>O",

	attach_e = "" ..
		"<tr>.*<td>.*<a>.*</a>.*<img>.*</td>.*<td>.*<br>.*<br>.*<ul>.*<li>.*<a>.*</a>.*" ..
		"<ul>.*<li>.*<a>.*</a>.*</li>.*<li>.*<a>.*</a>.*</li>.*</ul>.*</li>.*</ul>.*</td>.*" ..
		"</tr>",

	attach_g = "" ..
		"<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>O<O>O<O>O<X>O<O>O" ..
		"<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O" ..
		"<O>"
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

-- Is called to initialize the module
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '" .. PLUGIN_NAME .. "' version '" .. PLUGIN_VERSION .. "' started!\n")

	-- the browser module
	require("browser")

	-- the common module
	require("common")
	
	-- the mimer module
	require("mimer")

	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Save username
function user(pstate,username)
	--print("--- user(" .. username .. ") ---")
	supereva_globals.username = username
		
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Save password and login
function pass(pstate,password)
	--print("--- pass(***) ---")
	supereva_globals.password = password

	-- create a new browser and store it in globals
	supereva_globals.browser = browser.new()

	return supereva_login()
end

-- -------------------------------------------------------------------------- --
-- Try to login with given username and password
function supereva_login()
	--print("--- supereva_login() ---")

	-- format the post data
  	local login_data = string.format(supereva_strings.login_data,supereva_globals.username,supereva_globals.password)

	-- post the login data
	local file,err = supereva_globals.browser:post_uri(supereva_strings.login_uri,login_data)

	-- removed, would receive 404 when it's actually a 302
--[[	
	if (err) then
		--print("error on browser:post_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end
]]
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
	--print("--- quit_update() ---")

	-- we need the stat
	local st = stat(pstate)
	if (st ~= POPSERVER_ERR_OK) then return st end

	local delete_uri = "http://" .. supereva_globals.browser:wherearewe() .. "/cgi-bin/del_mov.cgi"
	local delete_data = ""

	local delete_something = false;
	local count = 0

	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			local uidl_cur = "cur%2F" .. get_mailmessage_uidl(pstate,i):sub(5,-1)
			delete_data = delete_data .. "&MSG" .. count .. "=" .. uidl_cur
			delete_something = true
			count = count+1
		end
	end

	if (delete_something) then
		delete_data = "max_msg=" .. count .. delete_data .. "&pldelete=Cancella"
		local _,err = supereva_globals.browser:post_uri(delete_uri,delete_data)
		if (err) then print("error on browser:post_uri: " .. err) end
	end

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	if (supereva_globals.stat_done) then return POPSERVER_ERR_OK end
	--print("*** stat() ***")

	local file,err = supereva_globals.browser:get_uri(supereva_strings.inbox_uri .. 1)

	if (err) then
		--print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	local pages = 1
	local _,navs = file:find("<div class=\"nav_pages\">%s*")
	if (navs) then
		local nave = file:find("%s*</div>",navs)
		_,pages = file:sub(navs+1,nave-1):gsub("<[Aa][^>]*>(%d+)</[Aa]>","")
		pages = pages + 1
	end

	--print(pages .. " inbox pages")
	
	local files = {file}
	for i=2,pages do
		file,err = supereva_globals.browser:get_uri(supereva_strings.inbox_uri .. i)

		if (err) then
			print("error on browser:get_uri: " .. err)
			return POPSERVER_ERR_UNKNOWN
		else
			table.insert(files,file)
		end
	end
	
	set_popstate_nummesg(pstate,0)
	
	for i,v in ipairs(files) do parse_inbox(pstate,v) end

	supereva_globals.stat_done = true
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function parse_inbox(pstate,file)
	--print("--- parse_inbox() ---")
	local nummesg = get_popstate_nummesg(pstate)

	-- parse the msg table
	local x = mlex.match(file,supereva_strings.inbox_e,supereva_strings.inbox_g)
	--print(x:count() .. " messages in this page")

	if (x:count() == 0) then return end

	set_popstate_nummesg(pstate,nummesg+x:count())

	-- set uidl/size for each message
	for i=1,x:count() do
		local uidl = string.match(x:get(0,i-1),"value=\"([^\"]*)\"")

		local size = string.match(x:get(1,i-1),"(%d+)")
		local size_mult_k = string.match(x:get(1,i-1),"([Kk])")
		local size_mult_m = string.match(x:get(1,i-1),"([Mm])")

		if (size_mult_k) then
			size = size * 1024
		elseif (size_mult_m) then
			size = size * 1024 * 1024
		end

		set_mailmessage_size(pstate,nummesg+i,size)
		set_mailmessage_uidl(pstate,nummesg+i,uidl)
	end
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
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call
-- popserver_callback to send the data
function retr(pstate,msg,data)
	--print("--- retr(" .. msg .. ") ---")	

	-- we need the stat
	local st = stat(pstate)
	if (st ~= POPSERVER_ERR_OK) then return st end

	-- the callback
	local cb = mimer.callback_mangler(common.retr_cb(data))

	-- get the message's page
	local file,err = supereva_globals.browser:get_uri(supereva_strings.get_uri .. get_mailmessage_uidl(pstate,msg))

	if (err ~= nil) then
		print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	local head,body_plain,body_html,attach = parse_message(file)
	
	mimer.pipe_msg(head,body_plain,body_html,"http://" .. supereva_globals.browser:wherearewe(),
		attach,supereva_globals.browser,cb,{},"utf-8")

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Extracts the message from the webmail page
function parse_message(file)
	--print("--- parse_message() ---")

	local body_begin_text = '<div id="mailbody" class="mailtext">'
	local body_end_text = '</div><!%-%- google_ad_section_end %-%-></td>'
		
	-- extract the body
	local body_pre_begin, body_begin = string.find(file,body_begin_text)
	local body_end, body_end_post = string.find(file,body_end_text)
	
	local body = string.sub(file,body_begin+1,body_end-1)
	-- mostly useless, just reduces range for mlex
	local attach = string.sub(file,body_end_post+1,-1)

	-- retrieve the attachments' url list
	local x = mlex.match(attach,supereva_strings.attach_e,supereva_strings.attach_g)
	
	local n = x:count()
	local attachments = {}
	for i = 0, n - 1 do
		local url = string.match(x:get(1,i),'href=..([^"]*)"')
		if (not url) then print("url non trovato per l'allegato " .. i)
		else url = string.gsub(url,"&amp;", "&") end
		local name = string.match(x:get(0,i),"%s*(.*)")
		attachments[name] = "http://" .. supereva_globals.browser:wherearewe() .. "/" .. url
	end

	-- mangles the body
	local body_html = body
	local body_plain = nil

	-- extracts the important part
	local _,head_begin = string.find(file,"<!%-%-Corpo Leggi messaggio%-%->")

	local raw_head = string.sub(file,head_begin,body_pre_begin)

	-- mangles the header
	local head = mangle_head(raw_head)

	return head,body_plain,body_html,attachments
end

-- ------------------------------------------------------------------------- --
-- given the HTML piece with the header, this returns the *clean* mail header
--
function mangle_head(s)
	-- helper #1 - extract a header field from HTML
	local function extract(field,data) -- ,getaddress)
		local exM = ".*<tr>.*<th>.*<b>%s</b>.*</th>.*<th>.*<.*>" -- ".*<td>.*<b>%s</b>.*</td>.*<td>.*<.*>"
		local exG = "O<O>O<O>O<O>O<O>O<O>O<O>X<O>" -- "O<O>O<O>O<O>O<O>O<O>X<O>"

		-- if getaddress then exG = "O<O>O<O>O<O>O<O>O<O>O<O>X<X>" end
		local x = mlex.match(data,string.format(exM,field),exG)
		
		if x:count() < 1 then
			return nil
		else
			local s = x:get(0,0)
			s = string.gsub(s,"%s+"," ")
			-- s = string.gsub(s,"\r","")
			-- s = string.gsub(s,"\n","")
			s = string.gsub(s,"&lt;","<")
			s = string.gsub(s,"&gt;",">")
			s = string.gsub(s,"&nbsp;","")
		--[[	
			if getaddress then
				local addr = x:get(1,0)
				if s == nil then return addr
				elseif addr == nil then return s
				else return s..' <'..addr..'>' end
			else
				return s
			end
		]]
			return s
		end
	end

	-- fix che risolve il bug nell'oggetto della pagina
	local a, b = s:find("<th><b>Oggetto:</b></td>")
	if (a) then s = s:sub(1,a) .. "<th><b>Oggetto:</b></th>" .. s:sub(b,-1) end
	-- fix che risolve il bug nel campo "to"
	s = string.gsub(s," <p class=\"fixwidth\">","")
	
	-- extract all interesting fields
	local from = extract("^Da:",s)
	local to = extract("^A:",s)
	local cc = extract("^CC:",s)
	local data = extract("^Data:",s)
	local oggetto = extract("^Oggetto:",s)

	-- pare che adesso la data sia gia' in inglese
	-- if (data) then data = translate(data) end
	
	if (to) then to = to:gsub(" ([%w%.-_]+@[%w%.-_]+)"," <%1>") end
	if (cc) then cc = cc:gsub(" ([%w%.-_]+@[%w%.-_]+)"," <%1>") end
	
	local s = ""
	if (to) then s = s .. "To: " .. to .. "\r\n" end
	if (oggetto) then s = s .. "Subject: " .. oggetto .. "\r\n" end
	if (from) then s = s .. "From: " .. from .. "\r\n" end
	if (cc) then s = s .. "CC: " .. cc .."\r\n" end
	if (data) then s = s .. "Date: " .. data .. "\r\n" end

	return s
end

-- EOF
-- ************************************************************************** --
