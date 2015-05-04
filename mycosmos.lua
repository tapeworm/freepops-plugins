-- ************************************************************************** --
-- FreePOPs @mycosmos.gr webmail interface
-- 
-- $Id: mycosmos.lua,v 0.3 2009/05/10 Ilias Bravos Exp $
-- 
-- Released under the GNU/GPL license
-- Written by Ilias Bravos
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.3"
PLUGIN_NAME = "mycosmos"
PLUGIN_REQUIRE_VERSION = "0.2.8"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=mycosmos.lua"
PLUGIN_HOMEPAGE = "http://mycosmospops.wordpress.com/"
PLUGIN_AUTHORS_NAMES = {"Ilias Bravos"}
PLUGIN_AUTHORS_CONTACTS = {"ilias (.) bravos (at) gmail (.) com"}
PLUGIN_DOMAINS = {"@mycosmos.gr"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		en = [[
Used for selecting the folder to operate on (inbox is the default one).<br/>
The supported folders are: inbox, sent, junk, deleted, outbox, drafts.<br/>
Here is an example of a username to get the email from the sent folder:<br/>
foo@mycosmos.gr?folder=sent<br/>
]],
		}	
	},
	{name = "fwdfrom", description = {
		en = [[
Used to ignore and delete messages forwarded to mycosmos from another email account.
Forwarded messages are deleted from inbox and recycle bin and not delivered to your email client.
It is tested on gmail and yahoo.
Here is an example of a username to delete messages forwarded to mycosmos from your gmail account:
foo@mycosmos.gr?fwdfrom=gmailusrname%40gmail.com
Notice that you have to substitute @ with %40
]],
		}	
	},
}
PLUGIN_DESCRIPTIONS = {
	en=[[
This is the webmail support for @mycosmos.gr.<br/>
To use this plugin you have to use your full email address as the user name 
and your real password as the password.<br/>
Adding the "folder" parameter at the end of the username gives the ability to download
email from different folders.
Adding the fwdfrom parameter gives the ability to filter out forwarded messages.
See parameters section for more details.
]]
}

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
globals = {
	StatDone = false,
	LoginDone = false,
	Username = nil,
	Password = nil,
	base_url = nil,
	browser = nil,
	uriRoot = nil,
	uriFolder = nil,
	filter = 0,
	fwdfrom = nil,
	usremail = nil,
}

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- Reply to POP3 USER command
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
function user(pstate,username)
	-- save username
	globals.Username = curl.unescape(freepops.get_name(username))
	return POPSERVER_ERR_OK
end

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- Reply to POP3 PASS command
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
function pass(pstate,password)
	-- save password
	globals.Password = password
	return mycosmos_login()
end

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- very usefull function for case insensitive string matching, copied from programming in lua, 20.4
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
function nocase(s)
	s = string.gsub(s, "%a", function (c)
			return string.format("[%s%s]", string.lower(c),string.upper(c))
		end)
	return s
end

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- generic form login function
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
function form_login(loginurl, username, password)
	local b = globals.browser
	-- ---------------------------------------------------------------------------------------------------- --
	-- load the login page
	local body,err = b:get_uri(loginurl)
	if err then
		log.dbg(err)
		return POPSERVER_ERR_UNKNOWN
	end
	-- ---------------------------------------------------------------------------------------------------- --
	-- build post string
	local post1 = ''	-- hidden form fields storage
	local post2		-- user, pass storage
	local post3		-- login button value storage
	-- for every <input...> tag
	for tag in string.gfind(body, nocase('<input.->')) do
		-- get its type, name, value
		local type_ = string.match(tag, nocase('type="(.-)"'))
		local name = string.match(tag, nocase('name="(.-)"'))
		local value = string.match(tag, nocase('value="(.-)"'))
		type_ = string.lower(type_)
		if type_ == 'hidden' then
			post1 = post1 .. name .. '=' .. curl.escape(value) .. '&'
		elseif type_ == 'text' and value == nil then
			post2 = name .. '=' .. curl.escape(username) .. '&'
		elseif type_ == 'password' then
			post2 = post2 .. name .. '=' .. curl.escape(password) .. '&'
		elseif type_ == 'submit' then
			value = string.gsub(value, ' ', '+')
			post3 = name .. '=' .. curl.escape(value)
		end
	end
	local post = post1 .. post2 .. post3
	-- ---------------------------------------------------------------------------------------------------- --
	-- find the post url and make it absolute
	local posturl = string.match(body, nocase('<form.-action="(.-)"'))
	if string.match(posturl, nocase('^http')) then
	--
	elseif string.match(posturl, '/') then
		posturl = string.match(loginurl, nocase('^(https?://.-)/')) .. posturl
	else
		posturl = string.gsub(loginurl, '([^/]+)$', posturl)
	end
	-- ---------------------------------------------------------------------------------------------------- --
	-- now login
	body,err = b:post_uri(posturl, post) -- host .. '/' .. posturl
	if err then
		return POPSERVER_ERR_UNKNOWN
	else
		log.dbg('Done login!')
	end
	-- ---------------------------------------------------------------------------------------------------- --
	return body
end

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- Login to mycosmos
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
function mycosmos_login()
	if globals.LoginDone then
		return POPSERVER_ERR_OK
	end
	-- ---------------------------------------------------------------------------------------------------- --
	-- create a browser, pretend to be firefox 3.0.6
	globals.browser = browser.new('Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.9.0.6) ' ..
							'Gecko/2009011913 Firefox/3.0.6')
	local b = globals.browser
	-- ---------------------------------------------------------------------------------------------------- --
	-- get folder and convert it to the real folder
	local folders = {	
		inbox = '%CE%95%CE%B9%CF%83%CE%B5%CF%81%CF%87%CF%8C%CE%BC%CE%B5%CE%BD%CE%B1',
		sent = '%CE%91%CF%80%CE%B5%CF%83%CF%84%CE%B1%CE%BB%CE%BC%CE%AD%CE%BD%CE%B1',
		junk = '%CE%91%CE%BD%CE%B5%CF%80%CE%B9%CE%B8%CF%8D%CE%BC%CE%B7%CF%84%CE%B7%20%CE%B1%CE%BB%CE%BB%CE%B7%CE%BB%CE%BF%CE%B3%CF%81%CE%B1%CF%86%CE%AF%CE%B1',
		deleted = '%CE%94%CE%B9%CE%B1%CE%B3%CF%81%CE%B1%CE%BC%CE%BC%CE%AD%CE%BD%CE%B1',
		outbox = '%CE%95%CE%BE%CE%B5%CF%81%CF%87%CF%8C%CE%BC%CE%B5%CE%BD%CE%B1',
		drafts = '%CE%A0%CF%81%CF%8C%CF%87%CE%B5%CE%B9%CF%81%CE%B1'
	}
	local folder = freepops.MODULE_ARGS.folder or 'inbox'
	if folders[folder] == nil then
		log.dbg('You mistyped folder parameter' .. folder .. '!')
		return POPSERVER_ERR_UNKNOWN
	else
		folder = folders[folder]
		globals.usrfolder = folder
	end
	-- ---------------------------------------------------------------------------------------------------- --
	-- Build the login URI and its post data
	local host = 'http://mail.mycosmos.gr'
	form_login(host .. '/mycosmos/login.aspx', globals.Username, globals.Password)
	-- ---------------------------------------------------------------------------------------------------- --
	-- we are logged on now, but since we are allowed to login either with a number or an alias, we need to get the real base folder
	local body, _ = b:get_uri(host .. '/exchange/') 
	local root = string.match(body, '<BASE href="('..host..'/exchange/.-/)">')
	globals.uriRoot = root
	-- now we can store the base url
	globals.uriFolder = root .. folder
	-- one last step to make my life easier: change date and time settings on the mailbox to some standard.
	-- i dont want to write 20 functions to parse an email's date...
	local str = 'Cmd=options&' ..
		'http%3A%2F%2Fschemas.microsoft.com%2Fexchange%2Fshortdateformat=yyyy-MM-dd&' ..
		'http%3A%2F%2Fschemas.microsoft.com%2Fexchange%2Ftimeformat=HH%3Amm&' ..
		'http%3A%2F%2Fschemas.microsoft.com%2Fexchange%2Ftimezone=GTB+Standard+Time'
	local body,_ = b:post_uri(root, str)
	-- log the creation of a session
	log.say("Session started")
	-- ---------------------------------------------------------------------------------------------------- --
	local fwdfrom = freepops.MODULE_ARGS.fwdfrom
	if fwdfrom ~= nil then
		log.dbg('got fwd from')
		globals.filter = 1
		globals.fwdfrom = curl.unescape(fwdfrom)
		globals.usremail = globals.Username .. '@mycosmos.gr'
	end
	-- ---------------------------------------------------------------------------------------------------- --
	globals.LoginDone = true
	return POPSERVER_ERR_OK
end

-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
-- functions to read a message
-- ------------------------------------------------------------------------------------------------------------------------------------------------------ --
months = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'}
function get_head_and_attach(pstate,msg_path)
	-- get the whole email
	local b = globals.browser
	local email = b:get_uri(msg_path .. '?Cmd=open')
	-- isolate header h
	local s = string.match(email, nocase('(<table[^>]+idReadMessageHeaderTbl.-/table>)'))
	-- some <a> tags have info in title field, replace tags with this info
	s = string.gsub(s, nocase('<a[^>]+title="(.-)">(.-)</a>'), '"%2" _/#/_%1_/$/_')
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
	s = string.gsub(s, ' %[(.-)%]" <%1>', '" <%1>')
	s = string.gsub(s, ' Sent:', '\r\nDate:')
	s = string.gsub(s, ' To:', '\r\nTo:')
	s = string.gsub(s, ' Cc:', '\r\nCc:')
	s = string.gsub(s, ' (Subject:.*)', '\r\n%1\r\n')
	-- mycosmos does not provide time offset. contact http://www.timezoneconverter.com/ to find the time offset per eamil
	s = string.gsub(s, 'Date: (%a+) (%d+)-(%d+)-(%d+) (%d+):(%d+)', function(weekday, year, month, day, hour, minute)
		local b = globals.browser
		local post = 'refzone=Europe%2FAthens&now=0&month='..month..'&day='..day..'&year='..year..
				'&showtime='..hour..'%3A'..minute..'%3A00&GMT=1&submit=Submit'
		local body,err = b:post_uri('http://www.timezoneconverter.com/cgi-bin/tzref.tzc', post)
		local month = months[tonumber(month)]
		local h, m = string.match(body, '%-%d+:(%d+):(%d+):%d+')
		local adjust = '+'..h..m
		return string.format('Date: %s, %s %s %s %s:%s %s', weekday, day, month, year, hour, minute, adjust)
		end
	)
	-- extract attachments
	local attach = {}
	for path, filename in string.gfind(email, '"([^"]+/([^/]+)%?attach=1)"') do
		filename = curl.unescape(filename)
		filename = string.gsub(filename, '^%%', '')
		attach[filename] = path
	end
	------------------------------------------------------------------------------------------------------------------------------------------------------
	-- head, attach
	return s, attach
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function get_msg(pstate,msg_path)
	-- get the body
	local b = globals.browser
	local body_html, err = b:get_uri(msg_path .. '?cmd=body&Security=1&unfiltered=1')
	if err ~= nil then
		if string.match(err, '404') then
			body_html = '' -- only empty messages return 404
		end
	end
	body_html = string.gsub(body_html, '/exchweb/bin/redir.asp%?URL=', '')
	-- body txt
	local body_txt = 'mycosmos'
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
function mycosmos_parse_webmessage(pstate,msg)
	local msg_path = globals.uriFolder .. '/' .. globals.ok[msg].uidl .. '/'
	local body_txt, body_html, inlineids = get_msg(pstate,msg_path)
	if globals.filter == 1 then
		return globals.ok[msg].head, body_txt, body_html, globals.ok[msg].attach, inlineids, 'UTF-8'
	else
		local head, attach = get_head_and_attach(pstate,msg_path)
		return head, body_txt, body_html, attach, inlineids, 'UTF-8'
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Must quit without updating
function quit(pstate)
--~ 	session.unlock(key())
	return POPSERVER_ERR_OK
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
	-- function to read job info of one page
	local msg_all = {}
	local body = ''
	local n = 0
	local StatRE = '<INPUT.-MsgID.-value="/.-/(.-%.EML)">.->(%d+)&nbsp;([KM]?)B<.-</TR>'
	local function stat_page(pagenum)
		local uri = string.format('%s/?Cmd=contents&Page=%s&View=Messages', globals.uriFolder, pagenum)
		body = b:get_uri(uri)
		for uidl, size, size_mult in string.gfind(body, StatRE) do
			n = n + 1
			msg_all[n] = {}
			if size_mult == 'K' then size = size * 1024 end
			if size_mult == 'M' then size = size * 1048576 end
			msg_all[n].uidl = uidl
			msg_all[n].size = size
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
	if globals.filter == 1 then
		-- IF FILTER IS ENABLED WE HAVE TO READ ALSO THE HEADER
		local del = 0
		local ok = 0
		local msg_del = {}
		local msg_ok = {}
		for i = 1, n do
			local msg_path = globals.uriFolder .. '/' .. msg_all[i].uidl .. '/'
			local head, attach = get_head_and_attach(pstate,msg_path)
			if string.match(head, 'To:.-'..globals.usremail..'.-Cc') == nil and string.match(head, 'To:.-'..globals.fwdfrom..'.-Cc') then
				-- blacklist it
				del = del + 1
				msg_del[del] = msg_all[i].uidl
			else
				-- whitelist it
				ok = ok + 1
				msg_ok[ok] = {}
				msg_ok[ok].uidl = msg_all[i].uidl
				msg_ok[ok].size = msg_all[i].size
				msg_ok[ok].head = head
				msg_ok[ok].attach = attach
			end
		end
		-- SEND UIDL AND SIZE INFO TO FREEPOPS
		-- update nummesg, must be done before setting uidl and size
		set_popstate_nummesg(pstate, ok)
		for i = 1, ok do
			set_mailmessage_uidl(pstate,i,msg_ok[i].uidl)
			set_mailmessage_size(pstate,i,msg_ok[i].size)
		end
		globals.ok = msg_ok
		globals.delsize = del
		globals.del = msg_del
	else
		set_popstate_nummesg(pstate, n)
		for i = 1, n do
			set_mailmessage_uidl(pstate,i,msg_all[i].uidl)
			set_mailmessage_size(pstate,i,msg_all[i].size)
		end
		globals.ok = msg_all
		globals.delsize = 0
		globals.del = {}
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
	local folder = globals.usrfolder
	local post = 'FormType=Note'
	-- 
	local delete_something = false;
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. '&MsgID=' .. curl.escape('/'.. folder .. '/') .. get_mailmessage_uidl(pstate,i)
			delete_something = true	
		end
	end
	for i = 1, globals.delsize do
		post = post .. '&MsgID=' .. curl.escape('/'.. folder .. '/') .. globals.del[i]
		delete_something = true
	end
	post = post .. '&Cmd=delete'

	if delete_something then
		delete(post)
	end
	-- delete blacklisted from deleted items as well
	if globals.delsize > 0 then
		folder = '%CE%94%CE%B9%CE%B1%CE%B3%CF%81%CE%B1%CE%BC%CE%BC%CE%AD%CE%BD%CE%B1'
		post = 'FormType=Note'
		for i = 1, globals.delsize do
			post = post .. '&MsgID=' .. curl.escape('/'.. folder .. '/') .. globals.del[i]
		end
		post = post .. '&Cmd=delete'
		delete(post)
	end
	-- logoff
	local root = globals.uriRoot
	_,_ = b:get_uri(root .. '?Cmd=logoff') 

	return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	local head,body,body_html,attach, inlineids, encoding = mycosmos_parse_webmessage(pstate,msg)
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
	local head,body,body_html,attach = mycosmos_parse_webmessage(pstate,msg)
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
-- This function is called to initialize the plugin.
-- We also export the pop3server.* names to global environment so we can
-- write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
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
