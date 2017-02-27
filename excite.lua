-- ************************************************************************** --
--  FreePOPs @excite.com webmail interface
--  
--  Released under the GNU/GPL license
--  Written by TheMarco <themarco (at) fsmail (.) net>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.0.5a"
PLUGIN_NAME = "excite"
PLUGIN_REQUIRE_VERSION = "0.0.99"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=excite.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/en/viewplugins.php"
PLUGIN_AUTHORS_NAMES = {"TheMarco"}
PLUGIN_AUTHORS_CONTACTS = {"themarco (at) fsmail (.) net"}
PLUGIN_DOMAINS = {"@excite.com","@myway.com"}
PLUGIN_PARAMETERS = {
	{name="folder", description={
		it=[[La cartella da ispezionare. Quella di default &egrave; Inbox, gli altri valori possibili sono: Bulk, Sent, Trash, Drafts o cartella definita dall'utente.]],
		en=[[The folder to interact with. Default is Inbox, other values are: Bulk, Sent, Trash, Drafts or user defined folder.]]}
	},
}

PLUGIN_DESCRIPTIONS = {
	it=[[Plugin per Excite webmail. Usate il vostro indirizzo email completo come 
nome utente e la vostra vera password come password. Per supporto, chiedete nel forum.]],
	en=[[Excite webmail plugin. Use your full email address as the username
and your real password as the password. For support, please post your questions to the forum.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Server URL
  --

  strBaseUrl = "http://e2.email.%s/",
  strAuthUrl = "authenticate.php",
  strCookieUrl = "http://c4.%s/tr.js?a=%s_LOGIN&r=%d" ,
  strLoginUrl2 = "http://registration.%s/login_process.jsp",
 
  -- Login strings
  --

  strLoginData ='<%s-input%s+.-%s+name="?snonce"?.-%s+value="(.-)".-' .. 
	'<%s-input%s+.-%s+name="?stime"?.-%s+value="(.-)"',
  strLoginPostData = "membername=%s&password=%s&snonce=%s&stime=%s&app=em&" ..
	"timeskew=%d&crep=%s&jerror=none&return_url=%s",
  strLoginFailed = "MESSAGE=AUTH_FAILED",
  strSessionPattern = "ArdSI=(.*)",
  strSessionExpired = '<div id="infoLoginMessage',

  -- Default mailboxes
  --
  strInbox = "Inbox",
  strMBoxes = {Inbox=0, Drafts=1, Sent=2, Trash=3, Bulk=4,}, -- the standard 'folder' options
  
  strMailPattern="msg_read.php",
  strDraftsMailPattern="compose.php",
  -- User mailboxes - example : folder.html?FOLDER=UF_mybox
  strUsrBoxPattern="<a href='(folder_msglist.php[^']*)[^>]*><font[^>]*>%s</font></a>",
  strUsrBox = "folder_msglist.php?m=%d&ArdSI=%s",
  
  -- Used by Stat
  --
  strStatE =".*<tr><td><img></td><td><img></td><td.*><img></td><td><img></td><td><input>[.*]{input}</td><td>{font}[.*]{.*}.*{/b}{/font}</td><td>[.*]{.*}<a>{font}.*{/font}</a>{/b}</td><td>{font}[.*]{.*}.*{/b}{/font}</td><td>{font}[.*]{.*}.*{/b}{/font}</td></tr>",
  strStatG ="O<O><O><O><O><O><O><O><O><O><O><O><O><O><O><O>[O]{O}<O><O>{O}[O]{O}O{O}{O}<O><O>[O]{O}<X>{O}O{O}<O>{O}<O><O>{O}[O]{O}O{O}{O}<O><O>{O}[O]{O}X{O}{O}<O><O>",

  strNextPagePattern = "<a%s+href='([^']*)'><font[^>]*>Next",
  
    
  -- Used by Quit_Update
  -- 
  
  -- MESSAGE= specifies the string used as a section header on the feedback page... can use the CONFIRM_DELETE message for multiple mails
  -- CONFIRM_DELETE= specifies if we need to see a confirmation page in order to proceed (it's not the same CONFIRM_DELETE as above!)
  -- trash folder should autodelete after 7 days
  --
  strCmdDelete = "msg_proc.php",
  strCmdDeletePost ="act=del&m_back=%s&m_to=&mid=%s&indBS=&url=&pg=&ArdSI=%s",
  
  strLogout = "logout.php?ArdSI=%s"

}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  bEmptyTrash = false,
  bUsrBox = false,
  bFirstMsg = true,
  strUser = nil,
  strPassword = nil,
  browser = nil,
  strDomain = nil,
  strMailPattern=nil,
  strMBox = nil,
  strMBoxUrl=nil,
  strBaseCmd = nil,
  strBaseUrl = nil,
  strHost =nil,
  strArdSI = nil,
  lastMsg = 0,
  msgUrls = {},
}

-- ************************************************************************** --
--  Helper functions
-- ************************************************************************** --

-- Serialize the state
--
-- serial. serialize is not enough powerfull to correcly serialize the 
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the 
-- serial module to know how to serialize this. so we call b:serialize 
-- method by hand hacking a bit on names
--
function serialize_state()
  internalState.bStatDone = false;
	
  return serial.serialize("internalState", internalState) ..
		internalState.browser:serialize("internalState.browser")
end

-- Computes the hash of our state.  Concate the user, domain and mailbox.
--
function hash()
  return (internalState.strUser or "") .. "~" ..
         (internalState.strDomain or "") .. "~"  ..
         (internalState.strMBox or "")
end

-- Issue the command to login
--
function login()
  -- Check to see if we've already logged in
  --
  if not internalState.bLoginDone then
    
    -- Create a browser to do the dirty work
    --
    internalState.browser = browser.new()
    
    -- Define some local variables
    --
    local username = internalState.strUser
    local password = curl.escape(internalState.strPassword)
    local domain = internalState.strDomain 
    local browser = internalState.browser
    
    -- DEBUG - Set the browser in verbose mode
    --
    browser:verbose_mode()
    
	-- Retrieve the session data page.
    --
    log.dbg("1st Login Url: " .. internalState.strBaseUrl .. globals.strAuthUrl .. "\n")
	local body, err = browser:get_uri(internalState.strBaseUrl .. globals.strAuthUrl)
	local _,_,snonce,stime = string.find(body,globals.strLoginData)
	--log.dbg ("snonce :: " ..snonce .."\nstime :: " .. stime)
	--snonce = "nA0l/662/BLV04l/DTq2Hg=="
	--stime = "44cbae59"
	log.dbg ("one")
	local str = curl.unescape(browser:whathaveweread())
	local _,_,s = string.find(str,"^(.*)/%?")
	str = s and s or str
	log.dbg (str)
	_,_,internalState.strHost=string.find(str,"&return_url=http://(.*)")
	internalState.strBaseUrl = "http://" .. internalState.strHost .."/"
	log.dbg ("initial url::  " .. str)
	--http://registration.excite.com/excitereg/login.jsp?ref=email&return_url=http://e30.email.excite.com
		
	-- seed math.random properly
	math.randomseed(math.fmod(os.time(),37))
	local j = math.random(67)
	math.randomseed((math.fmod((os.time()/j),73)+1)*j)
	
	--get cookie 'uu'
	--
	-- original javascript: Math.round(Math.random()*10000000000)+2
	local num = math.random(2,1000000001)+1000000000*math.random(0,9)
	
	--log.dbg("http://c4.excite.com/tr.js?a=EXCITE_LOGIN&r=" .. num)
	str = (domain == 'excite.com') and "EXCITE" or "BUZZ"
	str = string.format(globals.strCookieUrl,domain,str,num)
	body, err = browser:get_uri(str)
	local cookie = browser:get_cookie("uu") 
	if not cookie then log.say("Cookie 'uu' not found - This plugin may need updating!") end
	--log.dbg ("cookie val#"..cookie.value.."#")
	-- Now calculate the post data
	local skew,passfiller = 1,string.rep("x", string.len(password))
	local data = skew .. snonce
	-- excite's HmacMD5
	local rawres = crypto.hmac(data,crypto.md5(string.lower(password)),crypto.ALGO_md5)
	local crep = base64.encode(string.sub(rawres,7))
    local post = string.format(globals.strLoginPostData, username, passfiller,curl.escape(snonce),curl.escape(stime),skew,curl.escape(crep),internalState.strBaseUrl)
	str= (domain == 'excite.com') and domain .."/excitereg" or domain
	str = string.format(globals.strLoginUrl2, str)
	log.dbg("2nd Login Url: " .. str .. "?" .. post .."\n")
    -- Retrieve the login page.
    --
    local body, err = browser:post_uri( str, post)
    if body == nil then
      log.say("Login Failed - Unable to make connection.\n")
      return POPSERVER_ERR_NETWORK
    end
	
	--log.dbg("body :: " .. body)
	--_,_,str = string.find(body,"location%.replace%('(.-)'%);")
	
	-- then call authenticate again to create the session id.
	--
	body, err = browser:get_uri(internalState.strBaseUrl ..globals.strAuthUrl,{"Host: "..internalState.strHost})
	--browser:show()
	--log.dbg("redirect :: "..str)
	--str = browser:whathaveweread()
	--log.dbg ("first error - url::  " .. str .. " err :: " .. tostring(err))

	--let's get the session cookie...
	cookie = browser:get_cookie("ArdSI")
	local ArdSI
	if cookie then 
		-- clean up the cookie!
		_,_,cookie.value= string.find(cookie.value,"^(%S*)")
		ArdSI = cookie and cookie.value
	end
	--_,_,ArdSI = string.find(ArdSI,"^(%S*)")
	--if cookie then log.dbg ("cookie:: ArdSI - "..cookie.value .. " :: domain - ".. cookie.domain) end

	if (not ArdSI) or ArdSI == "deleted" then
		log.say("Login Failed - Session not initialized, Excite plugin may need updating.\n")
		return POPSERVER_ERR_AUTH
	end
	
	internalState.strArdSI = ArdSI

    -- do we have a mailbox url already?
    if not internalState.strMBoxUrl then
	log.dbg("looking for the mailbox!")
		--standard mailbox
	    local n, str = globals.strMBoxes[internalState.strMBox]
		--log.dbg("n :: "..tostring(n))
	    if n then
			str = string.format(globals.strUsrBox,n,ArdSI)
		else
			-- log.dbg("looking for the folder!")
			-- default to inbox
			str = string.format(globals.strUsrBox,0,ArdSI)		
			body = browser:get_uri(internalState.strBaseUrl .. str,{"Host: "..internalState.strHost})
			if body then
				-- can we find the user mailbox?
				local s=string.format(globals.strUsrBoxPattern,internalState.strMBox)
				--log.dbg("string used for search :: " .. s)
				_,_,s = string.find(body,s)
				--log.dbg("string found :: " .. tostring(s))
				if s then
					str=s
				end
			end
	    end
		internalState.strMBoxUrl = str
		log.dbg ("mailbox :: " .. internalState.strMBox .." - url :: ".. str)
		
    end

    body, err = browser:get_uri(internalState.strBaseUrl .. 
		internalState.strMBoxUrl,{"Host: "..internalState.strHost})
		
	str = browser:whathaveweread() 
    --log.dbg ("Now viewing :: " .. str )

	if not body then  --no mailbox?, they must have changed their html...
		log.say("Excite plugin - Error. Could not find mail folders\n")
		return POPSERVER_ERR_NETWORK
	end
    
    -- We have logged in successfully
    --
    internalState.bLoginDone = true
    log.dbg("Created session (ID: " .. hash() .. ", User: " .. 
	          internalState.strUser .. "@" .. internalState.strDomain .. ")\n");
    
  end
  -- Return Success
  --
  return POPSERVER_ERR_OK
end

-- Download a single message
--
function downloadMsg(pstate, msg, nLines, data)
  -- Make sure we aren't jumping the gun
  --
  local retCode = stat(pstate)
  if retCode ~= POPSERVER_ERR_OK then 
    return retCode 
  end
	
  -- Local Variables
  --
  local browser = internalState.browser
  local uidl = get_mailmessage_uidl(pstate, msg)
  
  local url = internalState.msgUrls[uidl];
  local headerUrl=string.gsub(url, "mid=", "p=0&mid=")

  -- Debug Message
  --
  log.dbg("Getting message: " .. uidl .. ", URL: " .. url)
  local h,e = browser:get_uri(headerUrl,{"Host: "..internalState.strHost})
  log.dbg("header :: " .. tostring(h) .." == " .. tostring(e))
  if h=='' or not h then 
	--don't process ther rest of the message
    return POPSERVER_ERR_OK 
  end
  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- String hacker
    --
    strHack = stringhack.new(),
	header=h,
	first=true,
    -- Lines requested (-2 means not limited)
    --
    nLinesRequested = nLines,

    -- Lines Received - Not really used for anything
    --
    nLinesReceived = 0,
	
	-- Buffer of last characters sent to the client.
	--
	strBuffer = nil,
  }
	
  -- Define the callback
  --
  local cb = downloadMsg_cb(cbInfo, data)

  -- Start the download on the body
  -- 
  local f, _ = browser:pipe_uri(url, cb,{"Host: "..internalState.strHost})
  if not f then
    -- An empty message.  Throw an error
    --
    return POPSERVER_ERR_NETWORK
  end

  if (cbInfo.strBuffer ~= "\r\n") then
	log.dbg("Message doesn't end in CRLF, adding to prevent client timeout.")
	popserver_callback("\r\n\0", data)
  end

  return POPSERVER_ERR_OK
end

-- Callback for the retr function
--
function downloadMsg_cb(cbInfo, data)
	
  return function(body, len)
    -- Are we done with Top and should just ignore the chunks
    --
    if (cbInfo.nLinesRequested ~= -2 and cbInfo.nLinesReceived == -1) then
      return 0, nil
    end
	if cbInfo.first then -- add the mail header to the body of the message
		cbInfo.first=false
		body=cbInfo.header..body
	end
    -- Clean up the end of line
    --
    body = string.gsub(body, "\r", "")
    body = string.gsub(body, "\n", "\r\n")

    -- Perform our "TOP" actions
    --
    if (cbInfo.nLinesRequested ~= -2) then
      body = cbInfo.strHack:tophack(body, cbInfo.nLinesRequested)

      -- Check to see if we are done and if so, update things
      --
      if cbInfo.strHack:check_stop(cbInfo.nLinesRequested) then
        cbInfo.nLinesReceived = -1;
        if (string.sub(body, -2, -1) ~= "\r\n") then
          body = body .. "\r\n"
        end
      else
        cbInfo.nLinesReceived = cbInfo.nLinesRequested - 
          cbInfo.strHack:current_lines()
      end
    end

    -- End the strings properly
    --
	cbInfo.strBuffer = string.sub(body, -2, -1)
    body = cbInfo.strHack:dothack(body) .. "\0"
	--log.dbg ("Msg ::" ..body)
    -- Send the data up the stream
    --
    popserver_callback(body, data)
			
    return len, nil
  end
end

-- ************************************************************************** --
--  Pop3 functions that must be defined
-- ************************************************************************** --

-- Extract the user, domain and mailbox from the username
--
function user(pstate, username)
  -- Get the user, domain, and mailbox
  --
  local domain = freepops.get_domain(username)
  local user = freepops.get_name(username)
  
  internalState.strDomain = domain
  internalState.strUser = user
  internalState.strBaseUrl=string.format(globals.strBaseUrl,domain)
  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder
  internalState.strMBox = mbox and mbox or globals.strInbox

  log.dbg ("user mailbox: " .. internalState.strMBox)
	
  local val = (freepops.MODULE_ARGS or {}).emptytrash or 0
  if val == "1" then
    log.dbg("Emails read will be queued for permanent deletion.\n")
    internalState.bEmptyTrash = true
  end
  return POPSERVER_ERR_OK
end


-- Perform login functionality
--
function pass(pstate, password)
  -- Store the password
  --
  internalState.strPassword = password

  -- Get a session
  --
  local sessID = session.load_lock(hash())

  -- See if we already have a session.  We want to prevent
  -- multiple sessions for a given account
  --
  if sessID ~= nil then
    -- Session exists
  
    -- Check to see if it is locked
    -- Why "\a"?
    --
    if sessID == "\a" then
      log.dbg("Error: Session locked - Account: " .. internalState.strUser .. 
        "@" .. internalState.strDomain .. "\n")
      return POPSERVER_ERR_LOCKED
    end
	
    -- Load the session which looks to be a function pointer
    --
    local func, err = loadstring(sessID)
    if not func then
      log.error_print("Unable to load saved session (Account: " ..
        internalState.strUser .. "@" .. internalState.strDomain .. "): ".. err)
      return login()
    end
		
    log.dbg("Session loaded - Account: " .. internalState.strUser .. 
      "@" .. internalState.strDomain .. "\n")

    -- Execute the function saved in the session
    --
    func()
		
    return POPSERVER_ERR_OK
  else
    -- Create a new session by logging in
    --
    return login()
  end
end

-- Quit abruptly
--
function quit(pstate)
  session.unlock(hash())
  return POPSERVER_ERR_OK
end

-- Update the mailbox status and quit
--
function quit_update(pstate)
  log.dbg("entered quit_update")
  -- Make sure we aren't jumping the gun
  --
  local retCode = stat(pstate)
  if retCode ~= POPSERVER_ERR_OK then 
    return retCode 
  end

  -- Local Variables
  --
  local browser = internalState.browser
  local cnt = get_popstate_nummesg(pstate)
  local post,body
  
  --if false then -- debugging in progress! Don't delete anything!!!!
  if internalState.strMBox ~='Trash' or internalState.bEmptyTrash then
	  -- Cycle through the messages and see if we need to delete any of them
	  -- 
	  local mid,m = ""
	  for i = 1, cnt do
	    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
	      local uidl = get_mailmessage_uidl(pstate, i)
	      local url = string.gsub(internalState.msgUrls[uidl], "mid=", "p=0&mid=")
	      body = browser:get_uri(url,{"Host: "..internalState.strHost})
		  if body and body ~= '' then
			if not  m then _,_,m=string.find(uidl,"%?m=(.-)&") end
			local _,_,str = string.find(uidl,"&mid=(.-)&")
			mid=mid .. str .. ","
			log.dbg ("Cleanup phase - marking message for deletion - uidl: " .. uidl .. "\n")
	      else
	        log.dbg ( "Cleanup phase - could not find message on server - uidl: " .. uidl .. " , URL" .. url.. "\n")
	      end
	    end
	  end

	  if m then
		mid=curl.escape(string.sub(mid,1,-2))
		browser:get_uri(internalState.strBaseUrl .. internalState.strMBoxUrl,{"Host: "..internalState.strHost})
	  	post = string.format(globals.strCmdDeletePost, m.."%7c%7c%7c",mid,internalState.strArdSI)
		-- and now send deleted mail to the trash folder 
		log.dbg("Deletion URL:\n\n" .. internalState.strBaseUrl .. globals.strCmdDelete .. "?" .. post .."\n")
		local cookie = browser:get_cookie("ArdSI")
		if cookie then 
			-- clean up the cookie, to enable the post_uri below to work.
			_,_,cookie.value= string.find(cookie.value,"^(%S*)")
		end
		body = browser:post_uri(internalState.strBaseUrl .. globals.strCmdDelete, post)
		--log.dbg(tostring(body))
		if not body then
			log.say("Message(s) deletion failed. This plugin may need updating.\n")
		end
		-- this should refresh the mail folder
		browser:get_uri(internalState.strBaseUrl .. internalState.strMBoxUrl,{"Host: "..internalState.strHost})
	  else
		if cnt > 0 then
			log.dbg ("Cleanup - none of the mail marked for deleting was found on the server!\n")
		end
	  end
  else
	log.dbg ("Cleanup -  trash folder -> trash folder = no action needed!")
  end
  
  -- Killing the session
  --
  local str = internalState.strBaseUrl .. string.format(globals.strLogout,internalState.strArdSI)
  log.dbg (str)
  browser:get_uri(str,{"Host: " .. internalState.strHost})
  internalState.bLoginDone = false
  session.remove(hash())

  log.dbg("Logged out: " .. internalState.strUser ..  "@" .. internalState.strDomain .. "\n")

  return POPSERVER_ERR_OK
end

-- Stat command - Get the number of messages and their size
--
function stat(pstate)

  -- Have we done this already?  If so, we've saved the results
  --
  if internalState.bStatDone then
	--log.dbg ("Stat for account already fetched, succesfully looked up state.")
    return POPSERVER_ERR_OK
  end
	--log.dbg( "starting Stat")

  local browser = internalState.browser
  local nMsgs = 0
  local cmdUrl = internalState.strBaseUrl .. internalState.strMBoxUrl ;
  local baseUrl = internalState.strBaseUrl
  local ArdSI = internalState.strArdSI

  -- Debug Message
  --
  --log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state as 0, in case of errors before the end.
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
	local x = mlex.match(body,globals.strStatE,globals.strStatG)
	local n = x:count()
	if n == 0 then
		return true,nil
	end 
	-- Cycle through the items and store the msg id and size.  
    ---   
	--local mailPattern="href='(.*)sl=.*'"
	local pattern=(internalState.strMBox=="Drafts") and globals.strDraftsMailPattern
		or globals.strMailPattern
    for i = 1,n do
	  local uidl = x:get (0,i-1) 
	  local size = x:get (1,i-1)
	--log.dbg ( "Loop messages :" .. 
	--log.dbg (" initial uidl ;; " ..uidl)
	  _,_,uidl = string.find (uidl,"href='(.*)sl=.*'")
	  uidl= string.gsub(uidl,pattern,"viewer.php")
	
      if (internalState.msgUrls[uidl] == nil) then
        internalState.msgUrls[uidl] = baseUrl .. uidl .. "&ArdSI=" .. ArdSI
		--log.dbg ("\n----------- processing url:" .. baseUrl ..uidl .. "  Size: " .. size .."\n")
        -- Convert the size from its string (4KB or 2MB) to bytes
        -- Let's figure out the unit
        --
        local bytes = 1
		local _, _, szUnit = string.find(size, "([Mm])")
				if szUnit then
			bytes = 1024 *1024
		end
		_, _, szUnit = string.find(size, "([Kk])")
	    if szUnit then 
			bytes = 1024
		end
        _, _, size = string.find(size, "([%d%.]+)%s-[MmKkBb]")
		size = math.max(tonumber(size), 0) * bytes
		
		log.dbg("\n----------- Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size .. "\n")

        -- Save the information
        --
        nMsgs = nMsgs + 1
		set_popstate_nummesg(pstate, nMsgs)
        set_mailmessage_size(pstate, nMsgs, size)
        set_mailmessage_uidl(pstate, nMsgs, uidl)
      end
    end
	internalState.lastMsg = nMsgs
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- See if there are messages remaining
    --
	
    local _, _, str = string.find(body, globals.strNextPagePattern)
	
    if str then
	  local join = "?"
	  if internalState.bUsrBox then
		join="&"
	  end
	  cmdUrl = internalState.strBaseUrl .. str
	  log.dbg ("Mailbox on more than one page. Fetching new page: " .. cmdUrl .. "\n")
      --cmdUrl = internalStructure.strBaseUrl .. str
      return false
    end
    return true
  end

  -- Local Function to get the list of messages
  --
  local function funcGetPage()  
    -- Debug Message
    --
    --log.dbg("Debug - Getting page: " .. cmdUrl .. "\n")

    -- Get the page and check to see if we got results
    --
    local body, err = browser:get_uri(cmdUrl,{"Host: "..internalState.strHost,})
	
	--log.dbg("Body :: " ..body)
	--  the minimum length for a session is 2 hrs, so no need to check for expired  session
    return body, err
  end


  -- Run through the pages and pull out all the message pieces from
  -- all the message lists
  --
  if not support.do_until(funcGetPage, funcCheckForMorePages, funcProcess) then
    log.error_print("STAT Failed.\n")
    session.remove(hash())
    return POPSERVER_ERR_NETWORK
  end
	
  -- Update our state
  --
  internalState.bStatDone = true
  
  log.dbg("STAT succeded.\n")
	
  -- Return that we succeeded
  --
  return POPSERVER_ERR_OK
end

-- Fill msg uidl field
--
function uidl(pstate,msg)
  return common.uidl(pstate, msg)
end

-- Fill all messages uidl field
--
function uidl_all(pstate)
  return common.uidl_all(pstate)
end

-- Fill msg size
--
function list(pstate,msg)
  return common.list(pstate, msg)
end

-- Fill all messages size
--
function list_all(pstate)
  return common.list_all(pstate)
end

-- Unflag each message marked for deletion
--
function rset(pstate)
  return common.rset(pstate)
end

-- Mark msg for deletion
--
function dele(pstate,msg)
  return common.dele(pstate, msg)
end

-- Do nothing
--
function noop(pstate)
  return common.noop(pstate)
end

-- Retrieve the message
--
function retr(pstate, msg, data)
  downloadMsg(pstate, msg, -2, data)
  return POPSERVER_ERR_OK
end

-- Top Command (like retr)
--
function top(pstate, msg, nLines, data)
  downloadMsg(pstate, msg, nLines, data)
  return POPSERVER_ERR_OK
end

-- Plugin Initialization - Pretty standard stuff.  Copied from the manual
--  
function init(pstate)
  -- Let the log know that we have been found
  --
  log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") found!\n")

  -- Import the freepops name space allowing for us to use the status messages
  --
  freepops.export(pop3server)
	
  -- Load dependencies
  --

  -- Serialization
  --
  require("serial")

  -- Browser
  --
  require("browser")
	
  -- MIME Parser/Generator
  --
  require("mimer")  

  -- Common module
  --
  require("common")
	
  -- Run a sanity check
  --
  freepops.set_sanity_checks()

  -- Let the log know that we have initialized ok
  --
  log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") initialized!\n")

  -- Everything loaded ok
  --
  return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
