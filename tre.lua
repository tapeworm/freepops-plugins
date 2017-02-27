-- ************************************************************************** --
--  FreePOPs @tre.it webmail interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Eddi De Pieri <dpeddi@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.5"
PLUGIN_NAME = "Tre"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=tre.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Eddi De Pieri"}
PLUGIN_AUTHORS_CONTACTS = {"dpeddi (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@tre.it", "@three.com.au"} 
-- list of tables with fields name and description.
-- description must be in the stle of PLUGIN_DESCRIPTIONS,
-- so something like {it="bla bla bla", en = "bla bla bla"}
PLUGIN_PARAMETERS = {
	{name = "purge", description = {
		it = [[
Elimina automaticamente la posta cancellata dal cestino. Valori permessi: yes/no
Es: 393921234567@tre.it?purge=yes ]],
		en = [[
Remove automatically deleted mail from trashcan. Permitted flags: yes/no
Ie: 443921234567@three.com.au?purge=yes ]],
		}
	},
        {name = "folder", description = {
                it = [[
Serve per selezionare la cartella (inbox &egrave; quella di default)
su cui operare.
Le cartelle standard disponibili sono INBOX, INBOX.Draft, INBOX.Sent, INBOX.trash.
Se hai creato delle cartelle dalla webmail allora puoi accedervi usando il
loro nome con il suffisso "INBOX.". es: 393921234567@tre.it?folder=INBOX.Esempio]],
		en = [[
Select a folder (inbox is the default folder).
Standard folders are  INBOX, INBOX.Draft, INBOX.Sent, INBOX.trash.
If you have creaded some your own folders you can select it using its name with 
the "INBOX." suffix.
ie: 443921234567@three.com.au?folder=INBOX.Example]],
        	}
	},
}
						
PLUGIN_DESCRIPTIONS = {
	it=[[
Per usare questo plugin dovrete impostare nel vostro client di posta come
nome utente il vostro numero di telefono nel formato 393921234567@tre.it 
e come password il pin originale della vostra usim, indicato nella busta
sigillata fornita da tre.]],
	en=[[
To use this plugin you have to configure your mail client using as username
your phone number formatted as 393921234567@three.com.XX and as password the usim's
original pin code provided by three.
PS: this plugin is tested only whith "three italy", please report me if it works
with the three webmail of your country!.
]]
}

-- This plugin should be finished, so I increased the version number.
-- Perhaps there are some bugfix to do.

-- The three webmail seems to be written in a very poor way!
-- there are some wrongs with html like: <a href[...]>TEXT<a> that
-- make parsing html more difficult!
-- or nested comment tags...

-- Todo:
-- Clean lua source (Remove debug print and optimization)
-- Since I hope three with solve issue with html, I keep at the moment all
-- print for a near future.
-- End

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
local tre_string = {
	-- The uri the browser uses when you click the "login" button
	login = "http://webmail.%s/cgi-bin/messagecenter.cgi",
	session_errorC = "(http://[^/]+/tre/src/redirect.php)",
	loginC = '.*<a.*href="([^"]+)".*>E.*mail.*',

	-- mesage list mlex
	statE = '.*<tr>.*<td>.*</td>.*<td><a>[.*]{img}</a></td>.*<td><a>.*<img>.*</a>.*</td>.*<td>.*</td>.*<td><a>.*</a></td>.*<td>.*</td>.*<td><a>.*</a></td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td><a><img></a></td>.*</tr>.*',
	statG = 'O<O>O<O>O<O>O<O><O>[O]{O}<O><O>O<O><O>O<O>O<O>O<O>O<O>O<O>O<O><O>O<O><O>O<O>O<O>O<O><X>O<O><O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>O<O>O<O><O><O><O><O>O<O>O',

	-- The uri for the first page with the list of messages
	first = "http://webmail.%s/cgi-bin/listfolders.cgi?count=5&do=viewfolder&folder=%s",
	-- The uri to get the next page of messages
	nextC = "message%s(%d+)-(%d+),%stotal:%s(%d+)",
	next = "http://webmail.%s/cgi-bin/listfolders.cgi?count=5&skip=%d&do=viewfolder&folder=%s",

	-- The capture to understand if the session ended
	timeoutC = '(FIXME)',
	-- The uri to save a message (read download the message)
	save = 'http://webmail.%s/cgi-bin/inbox.cgi?do=viewmessage%d&folder=%s',
	bodyC= '(<tr%swidth="572">.*<td%swidth="542"%salign="left"%sclass="bodyText">(.*)</td>.*</tr>)',
--	headerE = '.*<tr>.*<td><img></td>.*<td>.*</td>[.*]{!--}.*<td>[.*]{a}.*{.*a}[.*]</td>.*',
--	headerG = 'O<O>O<O><O><O>O<O>X<O>[O]{O}O<O>[O]{O}X{O}[O]<O>O',
--- se <a></a> nei campi a/cc/bcc compiaono pi volte si imputtana il parser
	headerE = '.*<tr>.*<td><img></td>.*<td>.*</td>[.*]{!--}.*<td>.*</td>.*',
	headerG = 'O<O>O<O><O><O>O<O>X<O>[O]{O}O<O>X<O>O',

	-- The uri to delete some messages
	delete = "http://webmail.%s/cgi-bin/viewmsg.cgi",
	delete_post = "count=14&do=delete&folder=%s&",
	-- The peace of uri you must append to delete to choose the messages 
	-- to delete
	delete_next = "msgid=%s&",
	
	attach = 'http://webmail.%s/cgi-bin/viewmsg.cgi?do=viewattach&folder=%s&msgid=%s',
	attachE = '<tr>.*<td></td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td><a>.*</a></td>.*<td></td>.*</tr>.*',
	attachG = '<O>O<O><O>O<O>O<O>O<O>X<O>O<O>O<O>O<O><X>O<O><O>O<O><O>O<O>O',
   
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

---------------------------------------------------------------------------------- Build a mail header date string
--
function build_date(str)
        if(str==nil) then
            return(os.date("%a, %d %b %Y %H:%M:%S"))
        else
	    -- 22/12/2004  21:10 (wrong format)
	    -- parse date with gsub
	    local temp
	    str=string.gsub(str,"[0-9]+/[0-9]+/[0-9]+ [0-9]+:[0-9]+","%2/%1/%3 %4:%5:00")
	    temp = getdate.toint( str )
	    log.dbg("Date: " .. str .. " Date in UNIX format: " .. temp )
            return(os.date("%a, %d %b %Y %H:%M:%S",temp))
	end
end

--------------------------------------------------------------------------------
-- Build a mail header
--
function build_mail_header(hfrom,hto,hcc,hdate,hsubject,uidl)
-- Corrected way of date formatting! "16 Jan 2003 16:35:49 -0000"
        return
        "Message-Id: <"..uidl..">\r\n"..
        "From: "..hfrom.."\r\n"..
        "To: "..hto.."\r\n"..
        "Cc: "..hcc.."\r\n"..
        "Date: "..build_date(hdate).."\r\n"..
        "Subject: "..hsubject.."\r\n"..
        "User-Agent: freepops "..PLUGIN_NAME..
        " plugin "..PLUGIN_VERSION.."\r\n"
end

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
		(internal_state.password or "")..
		(internal_state.purge or "")..
                (internal_state.folder or "")			
end

--------------------------------------------------------------------------------
-- Login to the tre website
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

function tre_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local domain = internal_state.domain
	local uri = string.format(tre_string.login,internal_state.domain)
	log.dbg("DEBUG: login uri " .. uri )

	-- the browser must be preserved
	internal_state.b = browser.new()

	local b = internal_state.b

	--b.curl:setopt(curl.OPT_VERBOSE,1)
	b.curl:setopt(curl.OPT_USERPWD,internal_state.name..":"..internal_state.password)

	local extract_f = support.do_extract(
		internal_state,"login_url",tre_string.loginC)
	local check_f = support.check_fail
	local retrive_f = support.retry_n(
		3,support.do_retrive(internal_state.b,uri))

	if not support.do_until(retrive_f,check_f,extract_f) then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end

	--int ( "DEBUG: " .. internal_state.login_url )
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
		-- three webmail doesn't support html mail, so this simplify parsing!!!
		s = mimer.remove_tags(s,
			{"html","head","body","doctype","void","style","table","td","tr","img"})
	
		s = tre_string.html_preamble .. s .. 
			tre_string.html_conclusion

		return nil,s
	end
end

-- -------------------------------------------------------------------------- --
-- Parse the message an returns head + body + attachments list
--
--
function tre_parse_webmessage(pstate,msg)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local b = internal_state.b
	
	-- body handling: build the uri
	local uidl = get_mailmessage_uidl(pstate,msg)
	local uri = string.format(tre_string.save,internal_state.domain,uidl,internal_state.folder)
	log.dbg("DEBUG: web message " .. uri )
	
	-- get the main mail page
	local f,rc = b:get_uri(uri)

	-- extract the body
	local body = string.match(f,tre_string.bodyC)

	log.dbg("YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY")
	log.dbg("DEBUG: Parsing message")
	log.dbg("BODY" .. body)
	log.dbg("YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY")

	local subst = 1

        while subst > 0 do
	    log.dbg("DEBUG: number of substitution " .. subst )
	    f,subst = string.gsub(f,"<[aA] href=\"[^\"]+\" [a-z]+='[^']+' [a-z]+='[^']+' [a-z]+='[^']+'>([^<]*)<[/]*a>","%1")
	end	

	-- generate the headers
	local x = mlex.match(f,tre_string.headerE,tre_string.headerG)

	local hfrom
	local hto
	local hcc
	local hdata
	local hsubject
	local n = x:count()

	for i = 1,n do
		log.dbg("addo " .. i .. " fino a " .. n)
		local k = string.match(x:get(0,i-1),'([A-Za-z]+):.*')

		log.dbg("DEBUG:" .. k)

		local v = string.match(mimer.html2txtplain(x:get(1,i-1)),'^[%s%t]*(.*)')

		log.dbg("DEBUG:" .. x:get(1,i-1))
		if k == "Da" then
		    hfrom = v
		end
		if k == "A" then
		    hto = v
		end
		if k == "Cc" then
		    hcc = v
		end
		if k == "Data" then
		    hdata = v
		end
		if k == "Oggetto" then
		    hsubject = v
		end
	end


	-- attach handling: build the uri
	local uri = string.format(tre_string.attach,internal_state.domain,internal_state.folder,uidl)
	-- get the main attach page
	local f,rc = b:get_uri(uri)

	-- extracts the attach list
	local x = mlex.match(f,tre_string.attachE,tre_string.attachG)

	log.dbg("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
	log.dbg("DEBUG: extracts the attach list from " .. uri )
	log.dbg("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
	
	local n = x:count()
	local attach = {}
	
	for i = 1,n do
		log.dbg("addo fino a " .. n)
		local url = string.match(x:get(1,i-1),'href="([^"]*)"')
		url = string.gsub(url,"&amp;", "&")
		local fname = string.match(x:get(0,i-1),'^[%s%t]*(.*)')
		attach[mimer.html2txtplain(fname)] = "http://".. b:wherearewe() .. "/cgi-bin/" .. url
		log.dbg("DEBUG: attacchment url " .. attach[mimer.html2txtplain(fname)] )
	end
	
	-- mangles the body
	local body,body_html = mangle_body(body)
	local head = build_mail_header(hfrom, hto, hcc, hdata, hsubject, uidl)
	return head,body,body_html,attach
end

-- ************************************************************************** --
--  tre functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name

        local f = (freepops.MODULE_ARGS or {}).folder or "INBOX"
--        local f64 = base64.encode(f)
--        local f64u = base64.encode(string.upper(f))
--        internal_state.folder = f64
        internal_state.folder = f
--        internal_state.folder_uppercase = f64u		
	
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
			return tre_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. "\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return tre_login()
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

        local purge = (freepops.MODULE_ARGS or {}).purge or "yes"

	-- shorten names, not really important
	local b = internal_state.b
	local uri = string.format(tre_string.delete,internal_state.domain)
	local post = string.format(tre_string.delete_post,internal_state.folder)
	local post_trash = string.format(tre_string.delete_post,"INBOX.Trash")

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post = post .. string.format(tre_string.delete_next,
				get_mailmessage_uidl(pstate,i))
			if ( purge == "yes") then
				post_trash = post_trash .. string.format(tre_string.delete_next,
	    			    get_mailmessage_uidl(pstate,i))
			end
			delete_something = true	
		end
	end

	if delete_something then
		-- Build the functions for do_until
		local extract_f = function(s) return true,nil end
		local check_f = support.check_fail
		local retrive_f = support.retry_n(3,support.do_post(b,uri.."?"..post,""))

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

	b.curl:setopt(curl.OPT_USERPWD,internal_state.name..":"..internal_state.password)

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later

	local uri = string.format(tre_string.first,internal_state.domain,internal_state.folder)
	
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
	    	local x = mlex.match(s,tre_string.statE,tre_string.statG)
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
			local uidl = x:get (0,i-1) 
			local size = x:get (1,i-1)

			-- arrange message size
			local k,m = nil,nil
			k = string.match(size,"([Kk][Bb])")
			m = string.match(size,"([Mm][Bb])")
			size = string.match(size,"([%.%d]+)")
			uidl = string.match(uidl,'viewmessage([%d]+)')

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
                local from,to,last = string.match(s,tre_string.nextC)
                if last == nil or to == nil then
		    return true
--                    error("unable to capture last or to")
                end
--		print ( "DEBUG: " .. from .. " " .. to .. " " .. last )

		if tonumber(to) < tonumber(last) then
			uri = string.format(tre_string.next,internal_state.domain,to,internal_state.folder)
			-- continue the loop
			return false
		else
			return true
		end
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		log.dbg("getting "..uri)
		local f,err = b:get_uri(uri)
		if f == nil then
			return f,err
		end

		local c = string.match(f,tre_string.session_errorC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = tre_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,"Session ended,unable to recover"
			end
			
			b = internal_state.b
			-- popserver has not changed
			
			uri = string.format(tre_string.first,internal_state.domain)

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
	local head,body,body_html,attach = tre_parse_webmessage(pstate,msg)
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
	local head,body,body_html,attach = tre_parse_webmessage(pstate,msg)
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
