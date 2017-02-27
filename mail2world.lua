-- ************************************************************************** --
--  FreePOPs @mail2world.com webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russells@despammed.com>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.0.2g"
PLUGIN_NAME = "mail2world.com"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?module=mail2world.lua"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russells (at) despammed (.) com"}
--PLUGIN_DOMAINS = {"@mail2world.com", "@mail2.*%.com"}
PLUGIN_REGEXES = {"@mail2.*%.com"}
PLUGIN_PARAMETERS = {
	{name="folder", description={
		it=[[La cartella che vuoi ispezionare.]],
		en=[[The folder you want to interact with. Default is Inbox.]]}
	},
	{name = "nossl", description = {
		en = [[
Parameter is used to force the plugin to not use ssl in its session.  Set the value to 1 to 
enable this feature.]]
		}	
	},

}
PLUGIN_DESCRIPTIONS = {
	it=[[
Per usare questo plugin dovrete usare il vostro indirizzo email completo come 
nome utente e la vostra vera password come password.]],
	en=[[
To use this plugin you have to use your full email address as the username
and your real password as the password.  For support, please post a question to
the forum instead of emailing the author(s).]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Server URL
  --
  strLoginUrl = "://www.mail2world.com/default.asp",

  -- Login strings
  --
  strLoginPostData = "username=%s&domain=%s&password=%s&rememberme=&faction=login&securebutt=on&submitbut.x=19&submitbut.y=14",
  strLoginFailed = "Login Failed - Invalid User name and/or password",

  -- Expressions to pull out of returned HTML from mail2world corresponding to a problem
  --
  strRetGoodLogin = '(<form name="userLogin")',
  strRetLoginSessionExpired = "(<title>User Message List Display</title>)",
  
  -- Regular expression to extract the mail server
  --
 
  -- Extract the first post login next page
  --
  strLoginGoodNextPage1 = 'url=([^"]+)"></noscript>',

  -- Extract the second post login next page
  --
  strLoginGoodNextPage2 = 'var nextpage = "([^"]+)";',
  
  -- Get the crumb value that is needed for every command
  --
  strRegExpGUID = 'GUID=([^"&]+)["&]',

  -- Pattern to determine the total number of messages
  --
  strMsgListCntPatternStart = '<input type=hidden name="messages_count_start"[^v]+value="([^"]+)">',
  strMsgListCntPatternEnd = '<input type=hidden name="messages_count_end"[^v]+value="([^"]+)">',

  -- Used by Stat to pull out the message ID and the size
  --
  strMsgLinePattern = 'ms_message.asp.MsgID=([^&]+)&.-<td class="tdrow"  align=right>([^<]+)</td></tr>',

  -- Number of pages
  --
  strNumPagesPat = '<option selected value=1>1 of ([%d]+)</option>',

  -- Default mailbox
  --
  strInbox = "/INBOX",

  -- Command URLS
  --
  strCmdMsgList = "http://%s/mail/ms_inbox.asp?GUID=%s&Current_folder=%s",
  strCmdMsgListNextPage = "&Current_page=%d",
  strCmdDelete = 'http://%s/mail/ms_inbox.asp?GUID=%s&Current_folder=%s',
  strCmdDeletePost = 'mvfolder=none&folder=%s&faction=DeleteMessages&passed_data2=none&location=&cached_folder=false&items_count=0&CurrentCachedFolder=&NewFolderName=&sort_by=&sort_order=&s_search=&passed_data=',
  strCmdMsgView = 'http://%s/tools/getFile.asp?GUID=%s&MsgID=%s&Show=3&ForceDownload=1&name=X*1&MsgFormat=txt&Headers=true',
  strCmdMsgRead = 'http://%s/mail/ms_message.asp?GUID=%s&MsgID=%s&SM=F&FolderName=%s&RI=1',
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  strUser = nil,
  strPassword = nil,
  browser = nil,
  strMailServer = nil,
  strDomain = nil,
  strGUID = nil,
  strMBox = nil,
  bSSLEnabled = true,
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

-- Computes the hash of our state.  Concate the user, domain, mailbox and password
--
function hash()
  return (internalState.strUser or "") .. "~" ..
         (internalState.strDomain or "") .. "~"  ..
         (internalState.strMBox or "") .. "~"  ..
	 internalState.strPassword      -- this asserts strPassword ~= nil
end

-- Issue the command to login
--
function login()
  -- Check to see if we've already logged in
  --
  if internalState.loginDone then
    return POPSERVER_ERR_OK
  end

  -- Create a browser to do the dirty work
  --
  internalState.browser = browser.new()

  -- Define some local variables
  --
  local username = internalState.strUser
  local password = curl.escape(internalState.strPassword)
  local domain = internalState.strDomain
  local url = "http" .. globals.strLoginUrl
  local browser = internalState.browser
	
  -- DEBUG - Set the browser in verbose mode
  --
--  browser:verbose_mode()

  -- Enable SSL
  --
  if internalState.bSSLEnabled then
    url = "https" .. globals.strLoginUrl
    browser:ssl_init_stuff()
  end

  -- Create the post string
  --
  local post = string.format(globals.strLoginPostData, username, domain, password)
  
  -- Retrieve the login page.
  --
  local body, err = browser:post_uri(url, post)

  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection")
    return POPSERVER_ERR_NETWORK
  end

  local str = string.match(body, globals.strRetGoodLogin)
  if str ~= nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_AUTH
  end

  -- Save the mail server
  --
  internalState.strMailServer = browser:wherearewe()

  -- Find the next page to go to.  We need to extract some info
  --
  str = string.match(body, globals.strLoginGoodNextPage1)
  if (str == nil) then
    log.error_print("Mail2World's login page has changed.  Alert the author.")
    return POPSERVER_ERR_NETWORK
  end
  log.dbg("http://" .. internalState.strMailServer .. str)
  body, err = browser:get_uri("http://" .. internalState.strMailServer .. str)

  -- Find the next page to go to.  We need to extract some info
  --
  str = string.match(body, globals.strLoginGoodNextPage2)
  if (str == nil) then
    log.error_print("Mail2World's login page has changed.  Alert the author.")
    return POPSERVER_ERR_NETWORK
  end
  body, err = browser:get_uri("http://" .. internalState.strMailServer .. str)

  -- DEBUG Message
  --
  log.dbg("Mail2World Server: " .. internalState.strMailServer .. "\n")
  
  -- Extract the GUID - This is needed for everything
  --
  str = string.match(body, globals.strRegExpGUID)
  if str == nil then
    log.error_print("Can't get the 'GUID' value. This will lead to problems!")
    internalState.strGUID = ""
  else
    internalState.strGUID = str
  
    -- Debug Message
    -- 
    log.dbg("Mail2World GUID value: " .. str .. "\n")
  end

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true
	
  -- Debug info
  --
  log.dbg("Created session for " .. 
    internalState.strUser .. "@" .. internalState.strDomain .. "\n")

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
  
  local url = string.format(globals.strCmdMsgView, internalState.strMailServer,
    internalState.strGUID, uidl);

  -- Debug Message
  --
  log.dbg("Getting message: " .. uidl .. ", URL: " .. url)

  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- String hacker
    --
    strHack = stringhack.new(),

    -- Lines requested (-2 means not limited)
    --
    nLinesRequested = nLines,

    -- Lines Received - Not really used for anything
    --
    nLinesReceived = 0,
  }
	
  -- Define the callback
  --
  local cb = downloadMsg_cb(cbInfo, data)

  -- Start the download on the body
  -- 
  local f, _ = browser:pipe_uri(url, cb)
  if not f then
    -- An empty message.  Throw an error
    --
    return POPSERVER_ERR_NETWORK
  end

  -- Mark the thing as read
  --
  url = string.format(globals.strCmdMsgRead, internalState.strMailServer,
    internalState.strGUID, uidl, internalState.strMBox);
  browser:get_head(url)

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
    body = cbInfo.strHack:dothack(body) .. "\0"

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

  -- Determine whether we should disable SSL
  --
  local val = (freepops.MODULE_ARGS or {}).nossl or 0
  if val == "1" then
    log.dbg("Mail2World: SSL is disabled.")
    internalState.bSSLEnabled = false
  end

  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder
  if mbox == nil then
    internalState.strMBox = globals.strInbox
  else
    internalState.strMBox = "/" .. mbox
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
    -- This code is copied from example.  It doesn't make sense to me.
    --
  
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
  -- Make sure we aren't jumping the gun
  --
  local retCode = stat(pstate)
  if retCode ~= POPSERVER_ERR_OK then 
    return retCode 
  end

  -- Local Variables
  --
  local browser = internalState.browser
  local cmdUrl = string.format(globals.strCmdDelete, internalState.strMailServer, internalState.strGUID, 
    internalState.strMBox)
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0
  local post = string.format(globals.strCmdDeletePost, internalState.strMBox) 

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      local uidl = get_mailmessage_uidl(pstate, i)
      post = post .. uidl .. "%7C"
      dcnt = dcnt + 1

      -- Send out in a batch of 5
      --
      if math.fmod(dcnt, 25) == 0 then
        log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
        local body, err = browser:post_uri(cmdUrl, post)
       
        -- Reset the variables
        --
        dcnt = 0
        post = string.format(globals.strCmdDeletePost, curl.escape(internalState.strMBox))
      end
    end
  end

  -- Send whatever is left over
  --
  if dcnt > 0 and dcnt < 5 then
    log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
    local body, err = browser:post_uri(cmdUrl, post)
    if not body or err then
      log.error_print("Unable to delete messages.\n")
    end
  end

  -- Save and then Free up the session
  --
  session.save(hash(), serialize_state(), session.OVERWRITE)
  session.unlock(hash())

  log.dbg("Session saved - Account: " .. internalState.strUser .. 
    "@" .. internalState.strDomain .. "\n")

  return POPSERVER_ERR_OK
end

-- Stat command - Get the number of messages and their size
--
function stat(pstate)

  -- Have we done this already?  If so, we've saved the results
  --
  if internalState.bStatDone then
    return POPSERVER_ERR_OK
  end

  -- Local variables
  -- 
  local browser = internalState.browser
  local nPage = 1
  local nMsgs = 0
  local nTotPages = 0;
  local cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
    internalState.strGUID, internalState.strMBox);
  local baseUrl = cmdUrl

  -- Debug Message
  --
  log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
    -- Cycle through the items and store the msg id and size.  
    ---    
    for uidl, size in string.gfind(body, globals.strMsgLinePattern) do

      if not uidl or not size then
        log.say("Mail2World Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      -- Convert the size from it's string (4KB or 2MB) to bytes
      -- First figure out the unit (KB or just B)
      --
      local kbUnit = string.match(size, "([Kk])")
      size = string.match(size, "([%d]+)[KkMm]")
      if not kbUnit then 
        size = math.max(tonumber(size), 1) * 1024 * 1024
      else
        size = math.max(tonumber(size), 1) * 1024
      end

      -- Save the information
      --
      nMsgs = nMsgs + 1
      log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size)
      set_popstate_nummesg(pstate, nMsgs)
      set_mailmessage_size(pstate, nMsgs, size)
      set_mailmessage_uidl(pstate, nMsgs, uidl)
    end
    
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- See if there are messages remaining
    --
    if nPage < nTotPages then
      nPage = nPage + 1		
      cmdUrl = baseUrl .. string.format(globals.strCmdMsgListNextPage, nPage)
      return false
    end
    return true
  end

  -- Local Function to get the list of messages
  --
  local function funcGetPage()  
    -- Debug Message
    --
    log.dbg("Debug - Getting page: ".. cmdUrl)

    -- Get the page and check to see if we got results
    --
    local body, err = browser:get_uri(cmdUrl)
    if body == nil then
      return body, err
    end

    -- Is the session expired
    --
    local strSessExpr = string.match(body, globals.strRetLoginSessionExpired)
    if strSessExpr == nil then
      -- Invalidate the session
      --
      internalState.bLoginDone = nil
      session.remove(hash())

      -- Try Logging back in
      --
      local status = login()
      if status ~= POPSERVER_ERR_OK then
        return nil, "Session expired.  Unable to recover"
      end
	
      -- Reset the local variables		
      --
      browser = internalState.browser
      cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
        internalState.strGUID, internalState.strMBox);
      if nPage > 1 then
        cmdUrl = cmdUrl .. string.format(globals.strCmdMsgListNextPage, nPage)
      end

      -- Retry to load the page
      --
      return browser:get_uri(cmdUrl)
    end

    -- Get the total number of messages
    --
    if nTotPages == 0 then
      local strTotPages = string.match(body, globals.strNumPagesPat)

      if strTotPages ~= nil then
        nTotPages = tonumber(strTotPages)
      else
        nTotPages = 1
      end
      log.dbg("Total Pages in message list: " .. nTotPages)
    end
	
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
	
  -- Check to see that we completed successfully.  If not, return a network
  -- error.  This is the safest way to let the email client now that there is
  -- a problem but that it shouldn't drop the list of known uidls.
  if (nPage < nTotPages) then
    return POPSERVER_ERR_NETWORK
  end

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
