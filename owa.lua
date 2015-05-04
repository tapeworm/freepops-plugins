-- ************************************************************************** --
--  FreePOPs Outlook Web Access (OWA) webmails interface
--  
--  $Id: owa.lua, version 0.03, 2009/03/28, Ilias Bravos Exp $
--  
--  Released under the GNU/GPL license
--  Written by Ilias Bravos
-- ************************************************************************** --
-- these are used in the init function
PLUGIN_VERSION = "0.03"
PLUGIN_NAME = "Outlook Web Access (OWA)"
PLUGIN_REQUIRE_VERSION = "0.2.9"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=owa.lua"
PLUGIN_HOMEPAGE = "http://owapops.wordpress.com/"
PLUGIN_AUTHORS_NAMES = {"Ilias Bravos"}
PLUGIN_AUTHORS_CONTACTS = {"ilias (.) bravos (at) gmail (.) com"}
PLUGIN_DOMAINS = {"@owa"}
PLUGIN_PARAMETERS = {
	{name = "loginurl", description = {
		en = [[
This is where you inform the plugin on the website it will operate on.<br/>
Go to your browser and copy (maybe from a bookmark) your login address exactly as
it appears on browser's address bar, complete with http:// and / at the end of
the address, if there is one.<br/>
Here is an example of user george that wants to read his email from his
OWA site at http://georgesowa.com/login.html<br/>
george@owa?loginurl=http://georgesowa.com/login.html<br/>]],
		}	
	},
	{name = "folder", description = {
		en = [[
Used for selecting the folder to operate on (inbox is the default one).<br/>
The supported folders are: inbox, sent, junk, deleted, outbox, drafts.<br/>
Here is an example of a username to get the email from the ‘Sent Items’ folder:<br/>
george@owa?loginurl=http://georgesowa.com/login.html&folder=sent<br/>]],
		}	
	},
}
PLUGIN_DESCRIPTIONS = {
	en=[[
This plugin adds support for OWA based webmails. It is in beta state, especially for sites that use basic authentication (sites where a window pops up for you to fill your credentials) like mail2web.<br/>
Put the plugin in LUA_UNOFFICIAL folder.<br/>
To use this plugin you have to use something like<br/>
george@owa?loginurl=http://georgesowa.com/login.html<br/>
as your username and your real password as password. If your username has special characters like @ you have to unescape them. Substitute @ with %40. For example to login to my owa account at mail2web I use myusername%40mail2web.com@owa?loginurl=http://eng-basic-exchange.mail2web.com/exchange as the username.<br/>
Adding the "folder" parameter at the end of the username gives the ability to download
email from different folders. Check "Parameters" for more
details about the available parameters.]]
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
globals = {
	StatDone = false,
	LoginDone = false,
	Username = nil,
	Password = nil,
	browser = nil,
	strFolder = nil,
	uriRoot = nil,
	uriFolder = nil,
	auth = nil, -- extra header, autorization field, for some servers that use basic-authentication than post
	offset = '',
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Must save the root name
function user(pstate,username)
	-- save username
	globals.Username = curl.unescape(freepops.get_name(username))
	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Must login
function pass(pstate,password)
	globals.Password = password
	return owa_login()
end

-- generic login function
-- it needs the address of a login form
-- automatically finds form fields, their names and their values
function login(form_url, username, password)
end

-- very usefull function for case insensitive string matching, copied from programming in lua, 20.4
function nocase(s)
	s = 	string.gsub(s, "%a", function (c)
			return string.format("[%s%s]", string.lower(c),string.upper(c))
		end)
	return s
end

function absolutize_url(url, whereweare)
	if string.match(url, nocase('^http')) then
	--
	elseif string.match(url, '/') then
		url = string.match(whereweare, nocase('^(https?://.-)/')) .. url
	else
		url = string.gsub(whereweare, '([^/]+)$', url)
	end
	return url
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function owa_login()
	if globals.LoginDone then
		return POPSERVER_ERR_OK
	end
	------------------------------------------------------------------------------------------------------------------------
	-- create a browser, pretend to be firefox 3.0.6
	globals.browser = browser.new('Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.9.0.6) ' ..
							'Gecko/2009011913 Firefox/3.0.6')
	local b = globals.browser
	-- get ready for https
	b:ssl_init_stuff()
	------------------------------------------------------------------------------------------------------------------------
	-- get folder parameter and check it
	local folders = {inbox=1, sent=1, junk=1, deleted=1, outbox=1, drafts=1}
	local folder = freepops.MODULE_ARGS.folder or 'inbox'
	if folders[folder] == nil then
		log.dbg('You mistyped folder parameter' .. folder .. '!')
	end
	------------------------------------------------------------------------------------------------------------------------
	-- get loginurl (read user-supplied parameter)
	local loginurl = freepops.MODULE_ARGS.loginurl
	if loginurl == nil then
		log.dbg('You have to supply your email provider’s login address!')
		return POPSERVER_ERR_UNKNOWN
	end
	-- validate it's a working address
	local body,err = b:get_uri(loginurl)
	if err then
		if string.match(err, '401') then -- it is valid and uses basic authorization. build authorization string
			globals.auth = {'Authorization: Basic ' .. base64.encode(globals.Username ..
						':' .. globals.Password)}
			log.dbg('Site uses basic authentication!')
		else -- it's not a valid address
			log.dbg("Address must be in the form http://.../, " ..
					"exactly as it appears in your browser's address bar!")
			log.dbg(err)
			return POPSERVER_ERR_UNKNOWN
		end
	end
	-- now, (possibly after some redirects) we are landed at the login page. we can store some info about it
	local host = 'http://' .. b:wherearewe()
	loginurl = b:whathaveweread()
	-- normally the site doesn't use basic authorization, do post to login
	if globals.auth == nil then
		local post1 = ''	-- hidden form fields storage
		local post2		-- user, pass storage
		local post3		-- login button value storage
		-- extract form fields (names, values etc)
		for tag in string.gfind(body, nocase('<input.->')) do
			local type_ = string.match(tag, nocase('type="(.-)"'))
			local name = string.match(tag, nocase('name="(.-)"'))
			local value = string.match(tag, nocase('value="(.-)"'))
			type_ = string.lower(type_)
			if type_ == 'hidden' then
				post1 = post1 .. name .. '=' .. curl.escape(value) .. '&'
			elseif type_ == 'text' and value == nil then
				post2 = name .. '=' .. curl.escape(globals.Username) .. '&'
			elseif type_ == 'password' then
				post2 = post2 .. name .. '=' .. curl.escape(globals.Password) .. '&'
			elseif type_ == 'submit' then
				value = string.gsub(value, ' ', '+')
				post3 = name .. '=' .. curl.escape(value)
			end
		end
		local post = post1 .. post2 .. post3
		-- login
		local posturl = string.match(body, nocase('<form.-action="(.-)"'))
		log.dbg(loginurl)
		log.dbg(posturl)
		posturl = absolutize_url(posturl, loginurl)
		log.dbg(posturl)
		body,_ = b:post_uri(posturl, post) -- host .. '/' .. posturl
	end
	------------------------------------------------------------------------------------------------------------------------
	-- we are logged on now, but one think remains: exchange mailboxes give users uris like .../exchange/username2
	-- where username2 is different from login username. we need to get that.
	body,_ = b:get_uri(host .. '/exchange/', globals.auth)
	local root = string.match(body, nocase('<base href="(.-/exchange/.-/)">'))
	-- store the paths
	globals.uriRoot = root
	------------------------------------------------------------------------------------------------------------------------
	-- read real folder names, international versions have different folder names
	-- this is very hacky, we find folder names from the names of their associated gif icons...
	local folder_param_to_gif = {
		inbox = 'inbox',
		sent = 'sent-items',
		junk = 'junkemail'
	}
	local gif_to_real_folder = {}
	body,_ = b:get_uri(globals.uriRoot .. '?Cmd=contents&ShowFolders=1', globals.auth)
	for tag in string.gfind(body, nocase('<INPUT[^>]+type=checkbox.-<IMG.-src=".-"')) do
		local real_folder, gif = string.match(tag, nocase('value="/(.-)".*src=".*/([^/]+)%.gif"'))
		gif_to_real_folder[string.lower(gif)] = real_folder
	end
	-- folder param to new folder
	local real_folder = gif_to_real_folder[folder_param_to_gif[folder]]
	log.dbg(real_folder)
	globals.strFolder = real_folder
	globals.uriFolder = root .. real_folder
	------------------------------------------------------------------------------------------------------------------------
	-- get user's timezone setting, OWA sites do not provide this info per email, only this general setting
	body,_ = b:get_uri(globals.uriRoot .. '?Cmd=options', globals.auth) 
	local offset = string.match(body, nocase('Current Time Zone.-<OPTION selected value.->%(GMT(.-)%)'))
	if offset == '' then
		globals.offset = '+0000'
	else
		globals.offset = string.gsub(offset, ':', '')
	end
	-- one last step to make my life easier: change date and time settings on the mailbox to some standard.
	-- i dont want to write 20 functions to parse an email's date...
	local _,_ = b:post_uri(globals.uriRoot, 'Cmd=options&'..
			'http%3A%2F%2Fschemas.microsoft.com%2Fexchange%2Fshortdateformat=yyyy-MM-dd'..
			'&http%3A%2F%2Fschemas.microsoft.com%2Fexchange%2Ftimeformat=HH%3Amm', globals.auth)
	------------------------------------------------------------------------------------------------------------------------
	globals.LoginDone = true
	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function month_tostring(month)
	if month == 1 then
		month = 'Jan'
	elseif month == 2 then
		month = 'Feb'
	elseif month == 3 then
		month = 'Mar'
	elseif month == 4 then
		month = 'Apr'
	elseif month == 5 then
		month = 'May'
	elseif month == 6 then
		month = 'Jun'
	elseif month == 7 then
		month = 'Jul'
	elseif month == 8 then
		month = 'Aug'
	elseif month == 9 then
		month = 'Sep'
	elseif month == 10 then
		month = 'Oct'
	elseif month == 11 then
		month = 'Nov'
	elseif month == 12 then
		month = 'Dec'
	end
	return month
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function get_head_and_attach(msg_path)
	-- get the whole email
	local b = globals.browser
	local msg = b:get_uri(msg_path .. '?Cmd=open', globals.auth)
	------------------------------------------------------------------------------------------------------------------------
	-- extract header
	local HeadRE = nocase('(<table[^>]+idReadMessageHeaderTbl.-/table>)')
	local s = string.match(msg, HeadRE)
	-- some <a> tags have info in title field, replace tags with this info
	s = string.gsub(s, '<[Aa][^>]+title="(.-)">(.-)</[Aa]>', '"%2" _/#/_%1_/$/_')
	-- remove all tags
	s = string.gsub(s, '<.->', '')
	-- restore email addresses
	s = string.gsub(s, '_/#/_', '<')
	s = string.gsub(s, '_/$/_', '>')
	-- remove whitespace
	s = string.gsub(s, '&nbsp;', ' ')
	s = string.gsub(s, '%s+', ' ')
	s = string.gsub(s, '^ ', '')
	s = string.gsub(s, ' $', '')
	-- dont want quots around sections like =?utf-8?B?....?=
	s = string.gsub(s, '&quot;=%?', '=%?')
	s = string.gsub(s, '%?=&quot;', '%?=')
	-- fix strange characters
	s = string.gsub(s, '&amp;', '&')
	s = string.gsub(s, '&quot;', '"')
	-- fix header fields
	s = string.gsub(s, ' %[(.-)%]" <%1>', '" <%1>') --from
	s = string.gsub(s, ' Sent:', '\r\nDate:')
	s = string.gsub(s, ' To:', '\r\nTo:')
	s = string.gsub(s, ' Cc:', '\r\nCc:')
	s = string.gsub(s, ' (Subject:.*)', '\r\n%1\r\n')
	--fix date
	s = string.gsub(s, 'Date: (%a+) (%d+)-(%d+)-(%d+) (%d+):(%d+)', function(weekday, year, month, day, hour, minute)
		return string.format('Date: %s, %s %s %s %s:%s %s', weekday, day, month_tostring(tonumber(month)),
						year, hour, minute, globals.offset)
		end
		)
	------------------------------------------------------------------------------------------------------------------------
	-- extract attachments
	local attach = {}
	for path, filename in string.gfind(msg, '"([^"]+/([^/]+)%?attach=1)"') do
		filename = curl.unescape(filename)
		filename = string.gsub(filename, '^%%', '')
		attach[filename] = path
	end
	return s, attach
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function get_msg(msg_path)
	-- get the body
	local b = globals.browser
	local body_html, err = b:get_uri(msg_path .. '?cmd=body&Security=1&unfiltered=1', globals.auth)
	if err then
		if string.match(err, '404') then
			body_html = '' -- only empty messages return 404
		end
	end
	-- body txt
	local body_txt = 'owa'
	-- extracts inline attachments
	local inlineids = {}
	body_html = string.gsub(body_html, '"?(1_[Mm]ultipart/(.-)%?Security=2)"?', function(path, filename)
		filename = curl.unescape(filename)
		filename = string.gsub(filename, '^%%', '')
		inlineids[filename] = filename
		return '"cid: ' .. filename .. '"'
	end)
	------------------------------------------------------------------------------------------------------------------------------------------------------
	return body_txt,body_html,inlineids
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function owa_parse_webmessage(pstate,msg)
	local msg_path = globals.uriFolder .. '/' .. get_mailmessage_uidl(pstate,msg) .. '/'
	local head, attach = get_head_and_attach(msg_path)
	local body_txt, body_html, inlineids = get_msg(msg_path)
	return head, body_txt, body_html, attach, inlineids, 'UTF-8'
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fill the number of messages and their size
function stat(pstate)
	------------------------------------------------------------------------------------------------------------------------------------------------------
	if globals.StatDone then
		return POPSERVER_ERR_OK
	end
	------------------------------------------------------------------------------------------------------------------------------------------------------
	-- connect to the browser
	local b = globals.browser
	------------------------------------------------------------------------------------------------------------------------------------------------------
	-- READ UIDL AND SIZE FROM MESSAGE LIST
	local msg = {}
	local body = ''
	local n = 0
	local StatRE = '<INPUT.-MsgID.-value="/.-/(.-%.EML)">.->(%d+)&nbsp;([KM]?)B<.-</TR>'
	local function stat_page(pagenum)
		local uri = string.format('%s/?Cmd=contents&Page=%s&View=Messages', globals.uriFolder, pagenum)
		body = b:get_uri(uri, globals.auth)
		for uidl, size, size_mult in string.gfind(body, StatRE) do
			n = n + 1
			msg[n] = {}
			if size_mult == 'K' then size = size * 1024 end
			if size_mult == 'M' then size = size * 1048576 end
			msg[n].uidl = uidl
			msg[n].size = size
		end
	end
	------------------------------------------------------------------------------------------------------------------------------------------------------
	stat_page(1)
	local total_pages = string.match(body,'>&nbsp;of&nbsp;(%d+)<')
	if total_pages == nil then
		log.error_print( 'cant read number of pages' )
		return POPSERVER_ERR_UNKNOWN
	elseif tonumber(total_pages) > 1 then
		for i=2,total_pages do
			stat_page(i)
		end
	end
	------------------------------------------------------------------------------------------------------------------------------------------------------
	-- SEND UIDL AND SIZE INFO TO FREEPOPS
	-- update nummesg, must be done before setting uidl and size
	set_popstate_nummesg(pstate, n)
	for i = 1, n do
		set_mailmessage_uidl(pstate,i,msg[i].uidl)
		set_mailmessage_size(pstate,i,msg[i].size)
	end
	------------------------------------------------------------------------------------------------------------------------------------------------------
	globals.StatDone = true
	return POPSERVER_ERR_OK
	------------------------------------------------------------------------------------------------------------------------------------------------------
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function delete(post)
	local b = globals.browser
	local uri = globals.uriRoot

	local extract_f = function(s) return true,nil end
	local check_f = support.check_fail
	local retrive_f = support.retry_n(3,support.do_post(b,uri,post))
	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Unable to delete messages\n")
		return POPSERVER_ERR_UNKNOWN
	end
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Update the root status and quit
function quit_update(pstate)
	local b = globals.browser
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	-- 
	local folder = globals.strFolder
	local post = 'FormType=Note'
	-- 
	local delete_something = false;
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. '&MsgID=' .. curl.escape('/'.. folder .. '/') .. get_mailmessage_uidl(pstate,i)
			delete_something = true	
		end
	end
	if delete_something then
		delete(post)
	end
	-- logoff
	local root = globals.uriRoot
	_,_ = b:get_uri(root .. '?Cmd=logoff', globals.auth) 

	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	local head,body,body_html,attach, inlineids, encoding = owa_parse_webmessage(pstate,msg)
	local b = globals.browser
	mimer.pipe_msg(
		head,body,body_html,
		"http://" .. b:wherearewe(),attach,b,
		function(s)
			popserver_callback(s,data)
		end, inlineids, encoding)
	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get message msg, must call popserver_callback to send the data
function top(pstate,msg,lines,data)
	local head,body,body_html,attach = owa_parse_webmessage(pstate,msg)
	local e = stringhack.new()
	local purge = false
	local b = globals.browser
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

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  This function is called to initialize the plugin.
--  We also export the pop3server.* names to global environment so we can
--  write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
function init(pstate)
	freepops.export(pop3server)
	log.dbg("FreePOPs plugin '"..PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")
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
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fill msg uidl field
function uidl(pstate,msg)
	return common.uidl(pstate,msg)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fill all messages uidl field
function uidl_all(pstate)
	return common.uidl_all(pstate)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fill msg size
function list(pstate,msg)
	return common.list(pstate,msg)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fill all messages size
function list_all(pstate)
	return common.list_all(pstate)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unflag each message merked for deletion
function rset(pstate)
	return common.rset(pstate)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mark msg for deletion
function dele(pstate,msg)
	return common.dele(pstate,msg)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do nothing
function noop(pstate)
	return common.noop(pstate)
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Must quit without updating
function quit(pstate)
	return POPSERVER_ERR_OK
end
