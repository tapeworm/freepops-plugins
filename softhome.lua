-- ************************************************************************** --
--  FreePOPs @softhome.net webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russells@despammed.com>
-- ************************************************************************** --


-- Globals
--
PLUGIN_VERSION = "0.0.2b"
PLUGIN_NAME = "softhome.net"
PLUGIN_REQUIRE_VERSION = "0.0.97"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=softhome.lua"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russells (at) despammed (.) com"}
PLUGIN_DOMAINS = {"@softhome.net"}
PLUGIN_PARAMETERS = {
        {name="folder", description={
                it=[[La cartella che vuoi ispezionare.]],
                en=[[The folder you want to interact with. Default is Inbox.]]}
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
  strLoginUrl = "http://www.softhome.net/signup/pro/ ",
  strLoginRedirect = "http://%s/sqwebmail/",


  -- Login strings
  --
  strLoginPostData = "username=%s&password=%s&sameip=on&do.login.x=0&do.login.y=0",
  strLoginFailed = "Login Failed - Invalid User name and/or password",


  -- Expressions to pull out of returned HTML from softhome corresponding to a problem
  --
  strRetLoginSessionExpired = "<title>(Folder contents)</title>",
  strRetGoodLogin = "(>Logout</a>)",
  
  -- Regular expression to extract the mail server
  --
  
  -- Get the base url that is needed for every command
  --
  strBaseUrlPat = '<p><a href="(.-)folder=',


  -- Used by Stat to pull out the message
  --
  strMsgLinePattern = '<INPUT TYPE=HIDDEN NAME="MOVEFILE[^"]+" VALUE="([^"]+)">.-<A HREF="([^"]+)".-<font class="message%-size">([^KBM]+[KBM])',
  strNextPagePattern = '<IMG SRC="/webmail/right.gif" width=48 height=24 alt="Next Page" title="Next Page">(</A>)',


  -- Delete pattern
  --
  strDeletePattern = '<A HREF="([^"]+)"><IMG SRC="/webmail/trash2.gif"',


  -- Default mailboxes
  --
  strInbox = "Inbox",


  -- Command URLS
  --
  strCmdMsgList = "form=folder&folder=",
  strCmdDeletePost = "form=delmsg&folder=%s&list1=Trash&move1=Go&pos=0&posfile=%s",
  strLogout = "http://www.softhome.net/?logout=yes",
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
  strGUID = nil, -- Remove
  strMBox = nil,
  strBaseUrl = nil,
  msgUrls = {},
  fullIds = {},
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
  local url = globals.strLoginUrl
  local browser = internalState.browser
        
  -- DEBUG - Set the browser in verbose mode
  --
--  browser:verbose_mode()


  -- Create the post string
  --
  local post = string.format(globals.strLoginPostData, username, password)


  -- Retrieve the login page.
  --
  local body, err = browser:post_uri(url, post)


  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection")
    return POPSERVER_ERR_NETWORK
  end


  -- Verify that we are logged in.
  --
  local _, _, str = string.find(body, globals.strRetGoodLogin)
  if str == nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_AUTH
  end


  -- Save the mail server
  --
  internalState.strMailServer = browser:wherearewe()


  -- Redirect to get authentication info.
  --
  url = string.format(globals.strLoginRedirect, internalState.strMailServer)
  body, err = browser:get_uri(url)


  local _, _, str = string.find(body, globals.strBaseUrlPat)
  if str == nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_AUTH
  else
    str = string.gsub(str, "%%2e", ".")
    internalState.strBaseUrl = str
    log.dbg("SoftHome - Base Url: " .. str)
  end


  -- DEBUG Message
  --
  log.dbg("Softhome Server: " .. internalState.strMailServer .. "\n")
  
  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true
        
  -- Debug info
  --
  log.dbg("Created session (ID: " .. hash() .. ", User: " .. 
    internalState.strUser .. "@" .. internalState.strDomain .. ")\n")


  -- Get the folders page.  This will cause delete to work.
  --
  local cmdUrl = internalState.strBaseUrl .. "folder=Trash&form=folders&folderdir=";
  local body, err = browser:get_uri(cmdUrl)  


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
  url = string.gsub(url, "form=readmsg", "form=fetch&download=1")


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


  -- Add an extra line feed
  --
--  popserver_callback("\r\n\0", data)



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


  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder
  if (mbox == nil) then
    internalState.strMBox = globals.strInbox
  else
    internalState.strMBox = mbox
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
  local cmdUrl = internalState.strBaseUrl
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0
  local post = nil


  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      local uidl = get_mailmessage_uidl(pstate, i)
      local url = internalState.msgUrls[uidl];
      local body, err = browser:get_uri(url);
      _, _, cmdUrl = string.find(body, globals.strDeletePattern)
      if (cmdUrl == nil) then
        log.error_print("Unable to find delete url for uidl: " .. uidl)
      else
        body, err = browser:get_uri(cmdUrl)
      end
--      post = string.format(globals.strCmdDeletePost, internalState.strMBox, 
--         internalState.fullIds[uidl])
--      log.dbg("Deleting msgs, url: " .. cmdUrl .. " - params: " .. post)
--      local body, err = browser:post_uri(cmdUrl, post)
    end
  end


  -- Save and then Free up the session
  --
--  session.save(hash(), serialize_state(), session.OVERWRITE)
--  session.unlock(hash())


  -- This service is retarded.  Just kill the session
  --
  browser:get_uri(globals.strLogout)
  internalState.bLoginDone = nil
  session.remove(hash())


  log.dbg("Session removed - Account: " .. internalState.strUser .. 
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
  local nMsgs = 0
  local cmdUrl = internalState.strBaseUrl .. globals.strCmdMsgList .. internalState.strMBox;
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
    for uidl, url, size in string.gfind(body, globals.strMsgLinePattern) do


      if not uidl or not size or not url then
        log.say("Softhome Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the url, size and uidl from the html"
      end


      -- Pull out the first bit from the uidl
      -- 
      local id = uidl
      _, _, uidl = string.find(uidl, "^([^%.]+)%.");


      if (internalState.fullIds[uidl] == nil) then
        internalState.fullIds[uidl] = id


        -- Convert the size from it's string (4KB or 2MB) to bytes
        -- First figure out the unit (KB or just B)
        --
        local _, _, kbUnit = string.find(size, "([KkMm])")
        _, _, size = string.find(size, "([%d]+%.?[%d]*)[KkMmbB]")
        if kbUnit == "k" or kbUnit == "K" then 
          size = math.max(tonumber(size), 0) * 1024
        elseif kbUnit == "m" or kbUnit == "M" then 
          size = math.max(tonumber(size), 0) * 1024 * 1024
        end


        -- Save the information
        --
        nMsgs = nMsgs + 1
        log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size .. ", url: " .. url)
        set_popstate_nummesg(pstate, nMsgs)
        set_mailmessage_size(pstate, nMsgs, size)
        set_mailmessage_uidl(pstate, nMsgs, uidl)
        internalState.msgUrls[uidl] = url
      end
    end
    
    return true, nil
  end 


  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- See if there are messages remaining
    --
    local _, _, str = string.find(body, globals.strNextPagePattern)
    if str ~= nil then
      cmdUrl = baseUrl .. "&pos=" .. nMsgs
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
    local _, _, strSessExpr = string.find(body, globals.strRetLoginSessionExpired)
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


      -- Retry to load the page
      --
      browser:get_uri(cmdUrl)
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