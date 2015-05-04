-- ************************************************************************** --
--  FreePOPs @tdconline.dk webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russells@despammed.com>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.0.2"
PLUGIN_NAME = "tdconline.dk"
PLUGIN_REQUIRE_VERSION = "0.0.97"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=tdconline.lua"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russells (at) despammed (.) com"}
PLUGIN_DOMAINS = {"@tdconline.dk"}
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
  strLoginUrl = "http://mail.tdconline.dk",
  strPostUrl = "https://access.tdc.dk/servlet/getAccessLogin",
  strSSOUrl = "http://sso.tdconline.dk/tdconline/tdclogin",

  -- Login strings
  --
  strLoginPostData = "HiddenURI=https%%3A%%2F%%2Fsso.tdconline.dk%%2Fredir%%2F%%3Fhttp%%3A%%2F%%2Fsso.tdconline.dk%%2Ftdconline%%2Ftdclogin&LOCALE=da_DK&AUTHMETHOD=UserPassword&usr_name=%s&usr_password=%s",
  strLoginFailed = "Login Failed - Invalid User name and/or password",

  -- Expressions to pull out of returned HTML from mail2world corresponding to a problem
  --
  strLoginRedirectPat = '<frame src="([^"]+%.dk/)[^"]+r=([^"&]+)[^"]-"',
  strRetLoginSessionExpired = "(function doDelete())",
  
  -- Regular expression to extract the mail server
  --

  -- Extract the post login next page
  --
  strLoginGoodNextPage = 'var nextpage = "([^"]+)";',
  
  -- Get the crumb value that is needed for every command
  --
  strRegExpCrumb = '&r=([^"&]+)["&]',

  -- Used by Stat to pull out the message ID and the size
  --
  strMsgLinePattern = '<td><a  href="read%.cgi%?pathname=[^&]+&UID=([^&]+)&r=([^"]+)"[^>]+>.-</td>[^<]+<td[^>]+>[^<]+</td>[^<]+<td align="right">([%d]+)KB&nbsp;</td>',

  -- Number of Messages
  --
  strNumMsgsPat = '</b> ud af i alt <b>([%d]+)</b></td>',

  -- Headers
  --
  strHeaderPat = '<table class="ot%-table o%-bg%-gray"  id="o%-mail%-headers%-full">(.-)</table>',

  -- Body Text Pattern
  --
  strTextBodyPat = '<div style=[^>]+>%s+(.-)<!%-%- Instadia tracking script block begin',

  -- Attachment Pattern
  --
  strAttachPat = '<tr>(.-)</tr>',
  strAttachItemPat = '(viewattach%.cgi[^"]+)"[^>]+>([^<]+)</a>',

  -- Default mailbox
  --
  strInbox = "/INBOX",

  -- Command URLS
  --
  strCmdMsgList = '%swebmail/folder.cgi?pathname=%s&r=%s&messagesperpage=10000',
  strCmdDelete = '%swebmail/do-stuff.cgi?r=%s',
  strCmdDeletePost = 'redirect=foo&pathname=%s&actionText=foo&stuff=delete&dest=&template=&folderselect=&shownum=0', -- &UID=1004&UID=1003 
  strCmdMsgView = '%swebmail/read.cgi?UID=%s&pathname=%s&popup=1&nobar=1&r=%s',
  strCmdMsgViewPlain = '%swebmail/viewattach.cgi/?spec=0.0&UID=%s&pathname=%s&r=%s',
  strCmdMsgViewHtml = '%swebmail/viewattach.cgi/?spec=0.1&UID=%s&pathname=%s&r=%s',
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
  strCrumb = nil,
  strMBox = nil,
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
  browser:ssl_init_stuff()

  -- Create the post string
  --
  local post = string.format(globals.strLoginPostData, username, password)
  
  -- Retrieve the mail server.
  --
  local body, err = browser:get_uri(url)
  local _, _, serverUrl, crumb = string.find(body, globals.strLoginRedirectPat)
  if serverUrl == nil or crumb == nil then
    log.error_print("Login Failed: Unable to determine mail server")
    return POPSERVER_ERR_NETWORK
  end

  -- Login
  --
  url = globals.strPostUrl
  body, err = browser:post_uri(url, post)

  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection")
    return POPSERVER_ERR_NETWORK
  end

  body, err = browser:get_uri(globals.strSSOUrl)
  if body == nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_NETWORK
  end


  local cookie = browser:get_cookie('SECURE_COOKIE')
  if cookie == nil then 
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_AUTH
  end

  -- Save the mail server
  --
  internalState.strMailServer = serverUrl

  -- Save the Crumb
  --
  internalState.strCrumb = crumb

  -- DEBUG Message
  --
  log.dbg("TDCOnline Server: " .. internalState.strMailServer .. "\n")
  
  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true
	
  -- Debug info
  --
  log.dbg("Created session (ID: " .. hash() .. ", User: " .. 
    internalState.strUser .. "@" .. internalState.strDomain .. ")\n")

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
    uidl, internalState.strMBox, internalState.strCrumb);

  -- Debug Message
  --
  log.dbg("Getting message: " .. uidl .. ", URL: " .. url)

  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- Header
    --
    strHeader = "",

    -- Body
    --
    strBody = nil,
    strBodyHtml = nil,

    -- Message Id
    --
    strMessageId = "",

    -- Is it a multipart-alternative
    --
    bHasAlt = false,

    -- Is body plain text
    -- 
    bIsPlain = false,

    -- Has attachments
    --
    bHasAttach = false,

    -- Attachment Table
    --
    attachments = {},

    -- Inline Attachment Table
    -- 
    inlineids = {},

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

  -- Get the headers and possibly the body
  --
  local body, err = browser:get_uri(url)

  -- Extract Headers
  --
  extractHeaders(body, cbInfo)

  -- Get the body
  --
  if (cbInfo.bHasAlt == true) then
    getMsgBody(browser, cbInfo, uidl)
  else
    extractBody(body, cbInfo)
  end
 	
  mimer.pipe_msg(
    cbInfo.strHeader, 
    cbInfo.strBody, 
    cbInfo.strBodyHtml, 
    internalState.strMailServer, 
    cbInfo.attachments, browser, 
    function(s)
      popserver_callback(s,data)
    end, cbInfo.inlineids)

  return POPSERVER_ERR_OK
end

-- Callback for the retr function
--
function processBody(cbInfo, body)
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

  return body
end

function extractBody(html, cbInfo)
  local _, _, body = string.find(html, globals.strTextBodyPat)

  body = findInlineAttachments(body, cbInfo)

  -- Remove the tags
  --
  if (cbInfo.bIsPlain == true) then
    body = string.gsub(body, "\n", "")
    body = mimer.html2txtplain(body, internalState.strMailServer)  
  else
    body = "<html><body>" .. body
    body = string.gsub(body, "</div>%s-<br>%s-</div>%s-$", "\n")
  end

  -- Save the Body
  --
  body = processBody(cbInfo, body)

  if (cbInfo.bIsPlain == true) then
    cbInfo.strBody = body
  else
    cbInfo.strBodyHtml = body
  end
end

function getMsgBody(browser, cbInfo, uidl)
  local url1 = string.format(globals.strCmdMsgViewPlain, internalState.strMailServer,
    uidl, internalState.strMBox, internalState.strCrumb);
  local url2 = string.format(globals.strCmdMsgViewHtml, internalState.strMailServer,
    uidl, internalState.strMBox, internalState.strCrumb);

  -- Get the text version
  --
  local body, err = browser:get_uri(url1)
  cbInfo.strBody = processBody(cbInfo, body)

  -- Get the HTML version
  --
  local body, err = browser:get_uri(url2)
  cbInfo.strBodyHtml = processBody(cbInfo, body)
end

function extractHeaders(body, cbInfo)
  local _, _, headers = string.find(body, globals.strHeaderPat)
  local _, _, attach = string.find(headers, globals.strAttachPat)

  if (attach ~= nil) then
    getAttachmentTable(cbInfo, attach)
  end

  -- Is this a multipart-alternative message?
  --
  local _, _, strAlternate = string.find(body, '([^;]multipart/alternative)')
  if strAlternate ~= nil then
    cbInfo.bHasAlt = true
  end

  -- Is this a plain text message?
  --
  local _, _, str = string.find(body, '(text/plain)')
  if str ~= nil then
    cbInfo.bIsPlain = true
  end

  -- Clean up the headers 
  --  
  headers = string.gsub(headers, "<tr>.-</tr>", "") -- not a header element 
  headers = string.gsub(headers, "\n", "")
  headers = string.gsub(headers, "\t", "")
  headers = string.gsub(headers, "<td>", " ")
  headers = string.gsub(headers, "</tr>", "\n")
  headers = string.gsub(headers, "</[^>]+>", "")
  headers = string.gsub(headers, "<[^>]+>", "")
  headers = string.gsub(headers, "&lt;", "<")
  headers = string.gsub(headers, "&gt;", ">")
  headers = string.gsub(headers, "&amp;", "&")
  headers = string.gsub(headers, "&quot;", '"')
  headers = string.gsub(headers, "^\s+", "")
  headers = string.gsub(headers, "\n", "\r\n")

  -- Get the message id
  --
  local _, _, strMessageId = string.find(headers, "[Mm][Ee][Ss][Ss][Aa][Gg][Ee]%-[Ii][dD]:[ ]-<([^>]+)>")
  if strMessageId ~= nil then
    cbInfo.strMessageId = strMessageId
  end

  -- Add some of our own
  --
  headers = headers .. "X-FreePOPs-Domain: " .. internalState.strDomain .. "\r\n";
  headers = headers .. "X-FreePOPs-Domain: " .. internalState.strMBox .. "\r\n";

  -- Some clean up of the headers
  --
  headers = mimer.remove_lines_in_proper_mail_header(headers, {"content%-type",
		"content%-disposition", "mime%-version", "boundary"})

  -- Save the headers
  --
  cbInfo.strHeader = headers

end

function getAttachmentTable(cbInfo, body)
  -- find attachments
  --
  for url, filename in 
    string.gfind(body, globals.strAttachItemPat) 
  do
    log.dbg("Found Attachment, File: " .. filename .. " - Url: " .. url)
    cbInfo.attachments[filename] = internalState.strMailServer .. "webmail/" .. url
    table.setn(cbInfo.attachments, table.getn(cbInfo.attachments) + 1)
    cbInfo.bHasAttach = true
  end
end

function findInlineAttachments(body, cbInfo) 
  local inlineids = {}
  local attachurl = ""
  local filename = ""
  local attachId = ""
  local cnt = 0

  -- Find inline images
  --
  for url in string.gfind(body, [[src="(viewattach[^"]+)"]]) do
    attachurl = internalState.strMailServer .. "webmail/" .. url
    filename = "tdc_attach_" .. cnt .. "." .. getExtension(attachurl)
    attachId = cbInfo.strMessageId .. "." .. cnt
   
    body = string.gsub(body, '(viewattach[^"]+)"', "cid:" .. attachId .. '"')
    log.dbg("Found inline Attachment, File: " .. filename .. " - Url: " .. attachurl .. " - id: " .. attachId)

    cbInfo.attachments[filename] = attachurl
    inlineids[filename] = attachId
    table.setn(cbInfo.attachments, table.getn(cbInfo.attachments) + 1)
    table.setn(inlineids, table.getn(inlineids) + 1)
    cnt = cnt + 1
  end

  cbInfo.inlineids = inlineids
  return body
end

function getContentType(url)
  local browser = internalState.browser
  local h, err = browser:get_head(url, {}, true)
  if (err ~= nil) then
    log.dbg(err)
    return "unknown/unknown"
  end
  local _, _, x = string.find(h,
                "[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:%s*([^\r]*)")
  return (x or "unknown/unknown")
end

function getExtension(url)
  local type = getContentType(url)
  if (string.find(type, "[Gg][Ii][Ff]") ~= nil) then
    return "gif"
  elseif (string.find(type, "[Jj][Pp][Gg]") ~= nil) then
    return "jpg"
  elseif (string.find(type, "[Jj][Pp][Ee][Gg]") ~= nil) then
    return "jpg"
  elseif (string.find(type, "[Bb][Mm][Pp]") ~= nil) then
    return "bmp"
  elseif (string.find(type, "[Bb][Ii][Tt][Mm][Aa][Pp]") ~= nil) then
    return "bmp"
  elseif (string.find(type, "[Pp][Ii][Cc][Tt]") ~= nil) then
    return "pct"
  elseif (string.find(type, "[Pp][Nn][Gg]") ~= nil) then
    return "png"
  elseif (string.find(type, "[Pp][Cc][Xx]") ~= nil) then
    return "pcx"
  elseif (string.find(type, "[Tt][Ii][Ff]") ~= nil) then
    return "tif"
  elseif (string.find(type, "[Ff][Ii][Ff]") ~= nil) then
    return "fif"
  elseif (string.find(type, "[Cc][Gg][Mm]") ~= nil) then
    return "cgm"
  elseif (string.find(type, "[Dd][Ww][Gg]") ~= nil) then
    return "svf"
  elseif (string.find(type, "[Gg][3][Ff][Aa][Xx]") ~= nil) then
    return "g3"
  elseif (string.find(type, "[Qq][Uu][Ii][Cc][Kk][Tt][Ii][Mm][Ee]") ~= nil) then
    return "qif"
  elseif (string.find(type, "[Aa][Ii][Ff]") ~= nil) then
    return "aif"
  elseif (string.find(type, "[Ww][Aa][Vv]") ~= nil) then
    return "aif"
  elseif (string.find(type, "[Mm][Ii][Dd][Ii]") ~= nil) then
    return "mid"
  elseif (string.find(type, "[Mm][Pp][Ee][Gg]3") ~= nil) then
    return "mp3"
  elseif (string.find(type, "[Mm][Pp][Ee][Gg]%-3") ~= nil) then
    return "mp3"
  elseif (string.find(type, "[Mm][Pp][Ee][Gg]2") ~= nil) then
    return "mp2"
  elseif (string.find(type, "[Mm][Pp][Ee][Gg]") ~= nil) then
    return "mpg"
  elseif (string.find(type, "[Rr][Ee][Aa][Ll]") ~= nil) then
    return "rm"
  end

  -- Handle unknown cases
  --
  log.dbg("Inline Attachments: Unable to figure out type for attachment with url: " .. url)
  return ""
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
  local cmdUrl = string.format(globals.strCmdDelete, internalState.strMailServer, internalState.strCrumb)
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0
  local post = string.format(globals.strCmdDeletePost, internalState.strMBox) 

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      local uidl = get_mailmessage_uidl(pstate, i)
      post = post .. "&UID=" .. uidl
      dcnt = dcnt + 1

      -- Send out in a batch of 25
      --
      if math.mod(dcnt, 25) == 0 then
        log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
        local body, err = browser:post_uri(cmdUrl, post)
       
        -- Reset the variables
        --
        dcnt = 0
        post = string.format(globals.strCmdDeletePost, internalState.strMBox)
      end
    end
  end

  -- Send whatever is left over
  --
  if dcnt > 0 and dcnt < 25 then
    log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
    local body, err = browser:post_uri(cmdUrl, post)
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
  local nMsgs = 0
  local nTotMsgs = 0;
  local cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
    internalState.strMBox, internalState.strCrumb);

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
    for uidl, r, size in string.gfind(body, globals.strMsgLinePattern) do
      if not uidl or not size or not r then
        log.say("TDCOnline Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      -- Convert the size from it's string (4KB or 2MB) to bytes
      -- First figure out the unit (KB or just B)
      --
      size = math.max(tonumber(size), 0) * 1024

      -- Save the information
      --
      nMsgs = nMsgs + 1
      log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size)
      set_popstate_nummesg(pstate, nMsgs)
      set_mailmessage_size(pstate, nMsgs, size)
      set_mailmessage_uidl(pstate, nMsgs, uidl)

      -- Save the new crumb
      --
      internalState.strCrumb = r
    end
    
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- All messages are on the first page.
    --
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
      cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
        internalState.strCrumb, internalState.strMBox);

      -- Retry to load the page
      --
      return browser:get_uri(cmdUrl)
    end

    -- Get the total number of messages
    --
    if nTotMsgs == 0 then
      local _, _, strTotMsgs = string.find(body, globals.strNumMsgsPat)

      if strTotMsgs ~= nil then
        nTotMsgs = tonumber(strTotMsgs)
      else
        log.error_print("STAT Failed: Unable to figure out the number of messages.\n")
        return POPSERVER_ERR_NETWORK
      end
      log.dbg("Total Messages in message list: " .. nTotMsgs)
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
  if (nMsgs < nTotMsgs) then
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
