-- ************************************************************************** --
--  FreePOPs Alice webmail interface
-- 
--  $Id: alice.lua, v0.2.5 2008/07/10 12:00:00 Viruzzo Exp $
--  Alice.lua fixed by maxgallina (www.maxgallina.it)
--  Now it works under OSX (MAC)
--  Released under the GNU/GPL license
-- ************************************************************************** --

PLUGIN_VERSION = "0.2.5h"
PLUGIN_NAME = "Alice"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=alice.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi","Viruzzo","Max Gallina"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge (at) users (.) sourceforge (.) net","unknown","maxgallina (at) gmail (.) com"}
PLUGIN_DOMAINS = {"@alice.it"}
PLUGIN_REGEXES = {}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it=[[Plugin per caselle @alice.it su portale.rossoalice.it]],
	en=[[This plugin is for italian users only.]]
}

-- ------------------------------------------------------------------------ --
-- Global plugin state
alice_globals = {
	username = nil,
	password = nil,
	domain = "alice.it",
	session_id = nil,
	user_code = nil,

	stat_done = false
}

-- ------------------------------------------------------------------------ --
--  Constants
local alice_strings = {
	login_uri = "https://authsrs.alice.it/aap/validatecredential",
	-- 1-3: username (con dominio); 4: dominio (con @); 5-7: password
	login_data = "login=%s&msisdn=%s&username=%s&DOMAIN=%s&servizio=mail&a3aid=na&PASS=%s&password=%s&pwd=%s",
	
	webmail_uri = "http://auth.rossoalice.alice.it/aap/serviceforwarder?sf_dest=mail_webmail",
	webmail2_uri = "http://portale.rossoalice.alice.it/ps/HomePS.do?area=posta&settore=mail_leggi",
	
	owa_uri = "http://mailstore.rossoalice.alice.it/ExchWeb/bin/auth/owaauth.dll",
	-- 1: username (con dominio); 2: password; 3: inbox_uri con user_code
	owa_data = "flags=0&forcedownlevel=0&trusted=0&username=%s&password=%s&destination=%s",
	
	inbox_uri = "http://mailstore.rossoalice.alice.it/exchange/%s/Posta%%20in%%20arrivo/?cmd=contents",
	
	logout_uri = "http://authsrs.alice.it/aap/deletecredential?URL_OK=http://pf.rossoalice.alice.it",
	
	inbox_e = ".*<tr>.*" ..
		"<td>.*<input>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*<img>.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}[.*]{img}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*" ..
		"<td>.*<font>.*<a>.*<font>[.*]{b}.*{/b}[.*]</font>.*</a>.*</font>.*</td>.*"	..
		"</tr>",

	inbox_g = "O<O>O" ..
		"<O>O<O>O<O>O" ..
		"<O>O<O>O<X>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}O<O>O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>O<O>O" ..
		"<O>",

	head_e = ".*<td>.*<font>.*<nobr>.*</nobr>.*</font>.*</td>.*" ..
		"<td>.*<font>[.*]{(nobr|a)}[.*]{font}.*{/font}[.*]{/(nobr|a)}[.*]{br}[.*]</font>.*</td>",

	head_g = "O<O>O<O>O<O>X<O>O<O>O<O>O" ..
		"<O>O<O>[O]{O}[O]{O}X{O}[O]{O}[O]{O}[O]<O>O<O>",

	attach_e = ".*<img>.*<a>.*<font>.*</font>.*</a>",

	attach_g = "O<O>O<X>O<O>X<O>O<O>",

	days = { ["lun"] = "Mon", ["mar"] = "Tue", ["mer"] = "Wed", ["gio"] = "Thu", ["ven"] = "Fri", ["sab"] = "Sat", ["dom"] = "Sun" },

	months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	
	escape_chars = {
		["à"] = "&agrave;", ["è"] = "&egrave;", ["ì"] = "&igrave;", ["ò"] = "&ograve;", ["ù"] = "&ugrave;",
		["À"] = "&Agrave;", ["È"] = "&Egrave;", ["Ì"] = "&Igrave;", ["Ò"] = "&Ograve;", ["Ù"] = "&Ugrave;",
		["á"] = "&aacute;", ["é"] = "&eacute;", ["í"] = "&iacute;", ["ó"] = "&oacute;", ["ú"] = "&uacute;",
		["Á"] = "&Aacute;", ["É"] = "&Eacute;", ["Í"] = "&Iacute;", ["Ó"] = "&Oacute;", ["Ú"] = "&Uacute;"
	},
	
	url_reserved_chars = {
		["!"] = "%21", ["*"] = "%2A", ["'"] = "%27", ["("] = "%28", [")"] = "%29",
		[";"] = "%3B", [":"] = "%3A", ["@"] = "%40", ["&"] = "%26", ["="] = "%3D",
		["+"] = "%2B", ["$"] = "%24", [","] = "%2C", ["/"] = "%2F", ["?"] = "%3F",
		["%"] = "%25", ["#"] = "%23", ["["] = "%5B", ["]"] = "%5D"
	}
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

	-- the serialization module
	--require("serial")

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
	alice_globals.user = username

	print("*** the user wants to login as '" .. username .. "'")

	return POPSERVER_ERR_OK
end


--------------------------------------------------------------------- --
-- Save password and login
function pass(pstate,password)
	alice_globals.password = password

	print("*** the user inserted '"..password.. "' as the password for '"..alice_globals.user.."'")
	
	-- create a new browser and store it in globals
	alice_globals.browser = browser.new()
	
	-- init SSL
	alice_globals.browser:ssl_init_stuff() 
	
	-- 	b:verbose_mode()

	return alice_login()
end

-- ------------------------------------------------------------------- --
-- Try to login with given username and password
function alice_login()
	print("*** alice_login() ***")

	-- create the data to post
	local login_data = string.format(alice_strings.login_data,
			alice_globals.user,
			alice_globals.user,
			alice_globals.user,
			'@' .. alice_globals.domain,
			alice_globals.password,
			alice_globals.password,
			alice_globals.password
		)

	-- post it
	local file,err = alice_globals.browser:post_uri(alice_strings.login_uri,login_data)
	if (file == nil) then return POPSERVER_ERR_AUTH end

	local i = 1

	if (err ~= nil) then
		print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	file,err = alice_globals.browser:get_uri(alice_strings.webmail_uri)

	if (err ~= nil) then
		print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	local id_url = alice_globals.browser:whathaveweread()

	local id  = id_url:sub(id_url:find("?")+3)
	if (id == nil) then return POPSERVER_ERR_AUTH end

	local user_code = string.match(file,"http://mailstore%.rossoalice%.alice%.it/exchange/(%w+)")
	if (user_code == nil) then return POPSERVER_ERR_AUTH end

	local inbox_url = string.format(alice_strings.inbox_uri,user_code)
	local owa_data = string.format(alice_strings.owa_data,alice_globals.user,alice_globals.password,url_encode(inbox_url))

	file,err = alice_globals.browser:post_uri(alice_strings.owa_uri,owa_data)

	if (err ~= nil) then
		print("error on browser:post_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	alice_globals.session_id = id
	alice_globals.user_code = user_code

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
	print("*** quit_update() ***")

	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	local delete_uri = string.format("http://mailstore.rossoalice.alice.it/exchange/%s/Posta%%20in%%20arrivo",alice_globals.user_code)
	local delete_data = ""

	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			local uidl = get_mailmessage_uidl(pstate,i)
			uidl = url_encode(uidl)
			delete_data = delete_data .. "MsgID=%2F" .. uidl .. "&"
			delete_something = true;
		end
	end

	delete_data = delete_data .. "Cmd=delete"
	
	if delete_something then
		local _,err = alice_globals.browser:post_uri(delete_uri,delete_data)
		if (err ~= nil) then print("error on browser:post_uri: " .. err) end
	end
	
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	if (alice_globals.stat_done == true) then return POPSERVER_ERR_OK end
	
	print("*** stat() ***")
	
	-- retrieve the inbox page
	local inbox_url = string.format(alice_strings.inbox_uri,alice_globals.user_code)

	local file,err = alice_globals.browser:get_uri(inbox_url)
	if (err ~= nil) then
		print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	local x = mlex.match(file,alice_strings.inbox_e,alice_strings.inbox_g)

	print("found " .. x:count() .. " messages")

	set_popstate_nummesg(pstate,x:count())

	for i=1,x:count() do
		local title = string.match(x:get(0,i-1),"href=\"([^?]+)")

		local size = string.match(x:get(1,i-1),"(%d+)")
		local size_mult_k = string.match(x:get(1,i-1),"([Kk][Bb])")
		local size_mult_m = string.match(x:get(1,i-1),"([Mm][Bb])")

		if (size_mult_k ~= nil) then
			size = size * 1024
		elseif (size_mult_m ~= nil) then
			size = size * 1024 * 1024
		end

		set_mailmessage_size(pstate,i,size)
		set_mailmessage_uidl(pstate,i,title)
	end
	
	alice_globals.stat_done = true
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
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	print("*** retr(" .. msg .. ") ***")	
	
	-- we need the stat
	local st = stat(pstate)
	if (st ~= POPSERVER_ERR_OK) then return st end
	
	-- the callback
	local cb = mimer.callback_mangler(common.retr_cb(data))
	
	-- some local stuff
	local msg_uri = "http://mailstore.rossoalice.alice.it/exchange/" .. alice_globals.user_code ..
		"/" .. get_mailmessage_uidl(pstate,msg) .. "?Cmd=open"
	
	-- tell the browser to pipe the uri using cb
	local file,err = alice_globals.browser:get_uri(msg_uri)

	if (err ~= nil) then
		print("error on browser:get_uri: " .. err)
		return POPSERVER_ERR_UNKNOWN
	end

	local head,body_plain,body_html,attach = parse_message(file)
	
	if (head == nil) then return POPSERVER_ERR_UNKNOWN end

	mimer.pipe_msg(head,body_plain,body_html,"http://" .. alice_globals.browser:wherearewe(),attach,alice_globals.browser,cb,{},"utf-8")
	
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Extracts the message from the webmail page
function parse_message(file)
	print("*** parse_message() ***")

	local _,p2 = file:find("id=\"idReadMessageHeaderTbl\">",0,true)
	local p3,p4 = file:find("</TABLE>",p2,true)

	local head_section = file:sub(p2+1,p3-1)

	local x = mlex.match(head_section,alice_strings.head_e,alice_strings.head_g)

	local head_data = {}

	for i=1,x:count() do
		local key = string.lower(string.sub(string.gsub(x:get(0,i-1),"&nbsp;",""),0,-2))
		head_data[key] = string.gsub(x:get(1,i-1),"&nbsp;","")
	end

	local _,p2a = file:find("</TR>",p2,true)
	local _,p2cc = file:find("</TR>",p2a,true)	

	local adv_a = false
	local adv_cc = false

	if (head_data["a"] == nil) then
		-- più di un destinatario, analisi avanzata
		local a_section = file:sub(p2a,p2cc)
		head_data["a"] = parse_addresses(a_section)
		adv_a = true
	end

	if (head_data["cc"] == nil) then
		-- più di un destinatario copia carbone, analisi avanzata
		local cc_section = file:sub(p2cc,p3)
		head_data["cc"] = parse_addresses(cc_section)
		adv_cc = true
	end

	if (head_data["a"] == "") then head_data["a"] = nil end
	if (head_data["cc"] == "") then head_data["cc"] = nil end
	
	local head = ""

	if (head_data["inviato"]) then
		-- conversione nel formato inglese
		local weekday = alice_strings.days[head_data["inviato"]:sub(0,3)]
		local day,month,year = head_data["inviato"]:sub(5,14):match("(%d%d)/(%d%d)/(%d%d%d%d)")
		month = tonumber(month)
		local timestamp = head_data["inviato"]:sub(16,20):gsub("%.",":",1) .. ":00"
		-- approssimazione dell'ora legale
		if (month > 3 and month < 11) then timestamp = timestamp .. " +0200"
		else timestamp = timestamp .. " +0100" end
		month = alice_strings.months[month]
		local msg_date = weekday .. ", " .. day .. " " .. month .. " " .. year .. " " .. timestamp
		head = head .. "Date: ".. msg_date .. "\r\n"
	end
	if (head_data["da"]) then
		head = head .. "From: ".. format_address(head_data["da"]) .. "\r\n"
	end
	if (head_data["a"]) then
		local address = ""
		if (adv_a) then address = head_data["a"]
		else address = format_address(head_data["a"])	end		
		head = head .. "To: ".. address .. "\r\n"
	end
	if (head_data["cc"]) then
		local address = ""
		if (adv_cc) then address = head_data["cc"]
		else address = format_address(head_data["cc"])	end		
		head = head .. "CC: ".. address .. "\r\n"
	end	
	if (head_data["oggetto"]) then
		local oggetto = head_data["oggetto"]
		oggetto = oggetto:gsub("&lt;", "<")
		oggetto = oggetto:gsub("&gt;", ">")
		oggetto = oggetto:gsub("&quot;", "\"")
		oggetto = oggetto:gsub("&amp;", "&")
		head = head .. "Subject: ".. oggetto .. "\r\n"
	end

	head = mimer.txt2mail(head)
	
	local attach = {}

	local _,as = file:find("<NOBR>&nbsp;Allegati:&nbsp;</NOBR>",p4,true)
	_,as = file:find("<FONT color=\"#000000\" size=\"2\">",as,true)
	local ae,_ = file:find("</TD>",as,true)
		
	x = mlex.match(file:sub(as+1,ae-9),alice_strings.attach_e,alice_strings.attach_g)

	if (x:count() > 0) then
		for i=1,x:count() do
			local attach_name = x:get(1,i-1)
			local k,_ = attach_name:find("(",-10,true)
			attach_name = attach_name:sub(0,k-1)
			local attach_url = string.match(x:get(0,i-1), "[^\"]+\"([^\"]+)")
			attach[attach_name] = attach_url:sub(0,-10)
		end
	end

	local _,p4 = file:find("</TABLE>",p4,true)

	local _,body_start = file:find("<TD[^>]*>%s*",p4)
	local body_end = file:find("%s*<INPUT type=\"hidden\" name=\"ParentFolder\" value=\"http://mailstore.rossoalice.alice.it/exchange/[^\"]*\" />",p4)
	local body = file:sub(body_start+1,body_end-1)
	
	local plain_comment = "<!-- Converted from text/plain format -->"
	local is_plain = false
	local is_textarea = false
	if (body:sub(0,9) == "<TEXTAREA") then
		body = body:gsub("<TEXTAREA [^>]*>%s*","",1):sub(0,-12)
		is_textarea = true
		is_plain = true
	else
		if (body:sub(0,#plain_comment) == plain_comment) then
			body = body:sub(#plain_comment+2,-1)
			is_plain = true
		end
		
		body = body:gsub("<TABLE[^>]*>%s*<TR[^>]*>%s*<TD[^>]*>%s*","",1):sub(0,-22)
	end

	print("\"" .. body .. "\"")

	local body_plain, body_html
	if (is_plain) then
		body_plain = mimer.html2txtplain(body)
		if (is_textarea) then
			body_plain = body_plain:gsub("&#13;","\r\n")
			body_plain = body_plain:gsub("&#09;","\t")
		end
		local _,p7 = body_plain:find("%s*%S")
		body_plain = body_plain:sub(p7,-1)
	else body_html = escape_body(body):gsub("/exchweb/bin/redir%.asp%?URL=","") end

	return head, body_plain, body_html, attach
end

---------------------------------------------------------------------------------------------------
-- Escape extra unescaped chars in an html body
function escape_body(body)
	return body:gsub("[^%w%p]", function(c) return alice_strings.escape_chars[c] or c end )
end

-- -------------------------------------------------------------------------- --
-- Escape the url with correct percent-encoding
function url_encode(s)
	local result = ""
	for c in s:gmatch(".") do
		local r = alice_strings.url_reserved_chars[c]
		if (r) then
			result = result .. r
		else
			result = result .. c
		end
	end
	return result
end

-- -------------------------------------------------------------------------- --
-- Format the addresses correctly
function format_address(address)
	if (not address:find("@")) then
		return "\"" .. address .. "\""
	elseif (address:find("%s")) then
		local i = 0
		for j=2,address:len() do
			if (address:sub(-j,-j) == "[") then
				i = j
				break
			end
		end
		return "\"" .. address:sub(1,-i-2) .. "\" <" .. address:sub(-i+1,-2) .. ">"
	else
		return "<" .. address .. ">"
	end
end

-- -------------------------------------------------------------------------- --
-- If there are multiple "a"/"cc" addresses get them
function parse_addresses(file)
	local addr_e = ".*<a>.*<font>.*</font>.*</a>"
	local addr_g = "O<O>O<O>X<O>O<O>"
	
	local x = mlex.match(file,addr_e,addr_g)
	
	if (x:count() == 0) then return nil end

	local result = ""
	for i=1,x:count() do
		result = result .. format_address(x:get(0,i-1)) .. ", "
	end
	
	-- remove extra ',' and cr\lf
	return result:sub(1,-3)
end

-- EOF
-- ************************************************************************** --