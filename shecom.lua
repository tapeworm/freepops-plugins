-- ************************************************************************** --
--  FreePOPs @she.com webmail interface
-- 
--  $Id: shecom.lua,v 1.10 2006/01/15 19:43:15 gareuselesinge Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Me <Me@myhouse>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.01"
PLUGIN_NAME = "she.com web mail"
PLUGIN_REQUIRE_VERSION = "0.2.6"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=shecom.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org"
PLUGIN_AUTHORS_NAMES = {"Angus Lee"}
PLUGIN_AUTHORS_CONTACTS = {"anguslee (at) she (dot) com"}
PLUGIN_DOMAINS = {"@she.com"}
PLUGIN_REGEXES = {}
PLUGIN_PARAMETERS = { 
  {name="emptytrash", 
   description={en="Trashed items will be emptied every one day, so this option has no use."}},
}
PLUGIN_DESCRIPTIONS = {
  en=[[
This is the webmail support for @she.com mailbox.
To use this plugin you have to use your full email address as the user 
name and your real password as the password.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Login strings
  --
  strLoginPage = "http://community.she.com/account/login/index.cfm?url=%2Femail%2Freadfolder%2Ecfm%3F",
  strLoginPostData = "login=%s&password=%s",

  -- Expressions to pull out of returned HTML from she.com corresponding to a problem
  --
  -- <td><i>sorry, your login has failed! please try again.</i><br><br></td>
  strRetLoginFailed = "<td><i>(.[^<]+)</i><br><br></td>",  
  strRetLoginSessionExpired = "<td><br>if you're not a member of she%.com, please sign up <a href=\"([%w%p^\"]+)\"",

  strMsgLineLitPattern = ".*<tr>.*<td>.*<img>.*</td>.*<td>.*<INPUT>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*<td>.*</td>.*</tr>.*",
  strMsgLineAbsPattern = "O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>X<O>O<O>O",

  -- MSGID Pattern
  --
  strMsgIDPattern = "[%s]onclick=\"readmail%('readmail_frame%.cfm%?folder=inbox&msgno=(%d+)&msgid=(%d+)",

  -- The amount of time that the session should time out at.
  -- This is expressed in seconds
  --
  nSessionTimeout = 600,  -- 10 minutes!

  -- Command URL's
  --
  strCmdMsgList = "http://webmail.she.com/email/readfolder.cfm?folder=inbox&page=%d&sort=Date_DESC",
  strCmdMsgViewMsg = "http://webmail.she.com/email/readmail_mailbody.cfm?folder=inbox&msgno=%d&login=%s",
  strCmdDelete = "http://webmail.she.com/email/movemail.cfm?uid=%s&msgdel=delete&mailboxfrom=inbox&method=popup",
  strCmdLogout = "http://community.she.com/account/logout",

  -- Used by Stat to pull out the next page
  --
  strNextPagePattern = "<b>(%d+)</b>[%s]|[%s]<a[%s][hH][rR][eE][fF]=\"readfolder%.cfm%?folder=inbox&page=(%d+)&sort=Date_DESC\">(%d+)</a>[%s]|",
 
  -- Pattern used by Stat to get the total number of messages
  --
  strMsgListCntPattern = "mail%.[%s]total[%s](%d+)[%s]mails[%s]in[%s]inbox%.",

  -- Header Pattern
  --
  strHeaderTableStartPattern = "</table>[%c]*<table[%s]width=\"100%%\"[%s]border=\"0\"[%s]cellspacing=\"1\"[%s]cellpadding=\"0\"[%s]bgcolor=\"#cccccc\">",
  strHeaderTableEndPattern = "</table>[%c]*<table[%s]bgcolor=\"#ffffff\"[%s]border=0[%s]cellpadding=1[%s]cellspacing=0[%s]width=\"100%%\">",
  strHeaderTableRowPattern = "[%s]style=\"font%-size:8pt\">&nbsp;(.-)</font>",

  -- Plaintext mail body Pattern
  --
  strMailBodyStartPattern = "</tr>[%c]*</table>[%c]*<br>[%c]*",
  strMailBodyEndPattern = "[%c]*</table>[%c]*<br>[%c]*<br>[%c]*<!%-%-[%s]START[%s]RedSheriff[%s]Measurement",
  strMailAttachmentStartPattern = "[%s]+<table[%s]width=\"98%%\"[%s]align=\"center\">[%c]*[%s]+<tr><td>[%c]*",
  strMailAttachmentEndPattern = "</font></a><br>[%c]*[%s]+</td></tr>[%c]*[%s]+</table>",

  -- Attachment Pattern
  --
  strAttachmentLitPattern = ".*<a>.*<font>.*</font>.*</a>.*<br>",
  strAttachmentAbsPattern = "O<X>O<O>X<O>O<O>O<O>",
  strAttachmentPattern = "[%s]href=\"(.+)\"[%s]target=\"_blank\"",
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  strUser = nil,
  strPassword = nil,
  browser = nil,
  bLoginDone = false,
  loginTime = nil,
  msgno2msgid = {},
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
  
  log.dbg("FreePOPs plugin '"..
    PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

  -- the serialization module
  require("serial")
  --  return POPSERVER_ERR_UNKNOWN 
  --end 

  -- the browser module
  require("browser")
  --  return POPSERVER_ERR_UNKNOWN 
  --end

  -- MIME Parser/Generator
  require("mimer")

  -- Common module
  require("common")

  -- checks on globals
  freepops.set_sanity_checks()
    
  -- Let the log know that we have initialized ok
  log.dbg(PLUGIN_NAME .. "(" .. PLUGIN_VERSION ..") initialized!\n")

  return POPSERVER_ERR_OK
end
-- Computes the hash of our state.  Concate the user, domain, mailbox and password
--
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
  -- Get the user, domain, and mailbox
  --
  local user = freepops.get_name(username)

  internalState.strUser = user

  return POPSERVER_ERR_OK
end
function hash()
  return (internalState.strUser or "") .. "~" ..
	 internalState.strPassword -- this asserts strPassword ~= nil
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
  local browser = internalState.browser
  local post = string.format(globals.strLoginPostData, username, password)

  -- DEBUG - Set the browser in verbose mode
  --
  browser:verbose_mode()

  -- Login
  --
  local body, err = browser:post_uri(globals.strLoginPage, post)

  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection")
    return POPSERVER_ERR_NETWORK
  end

  -- Check for invalid login/password
  -- 
  local _, _, str = string.find(body, globals.strRetLoginFailed)
  if str ~= nil then
    log.error_print("Login Failed: " .. str)
    return POPSERVER_ERR_AUTH
  end

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true

  -- Debug info
  --
  log.dbg("Created session for " .. internalState.strUser .. "@she.com\n")

  -- Note the time when we logged in
  --
  internalState.loginTime = os.clock();

  -- Return Success
  --
  return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
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
    if sessID == "\a" then
      log.dbg("Error: Session locked - Account: " .. internalState.strUser .. "@she.com\n")
      return POPSERVER_ERR_LOCKED
    end

    -- Load the session which looks to be a function pointer
    --
    local func, err = loadstring(sessID)
    if not func then
      log.error_print("Unable to load saved session (Account: " .. internalState.strUser .. "@she.com): ".. err)
      return login()
    end

    log.dbg("Session loaded - Account: " .. internalState.strUser .. "@she.com\n")

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
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
  session.unlock(hash())
  return POPSERVER_ERR_OK
end
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
  return (internalState.strUser or "") .. "~" .. internalState.strPassword -- this asserts strPassword ~= nil
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
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
  local cnt = get_popstate_nummesg(pstate)

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      local cmdUrl = string.format(globals.strCmdDelete, internalState.msgno2msgid[get_mailmessage_uidl(pstate, i)])
      log.dbg("Delete message #" .. i .. " (UIDL=" .. get_mailmessage_uidl(pstate, i) .. ", MsgId=" .. internalState.msgno2msgid[get_mailmessage_uidl(pstate, i)] .. ") using " .. cmdUrl .. "\n")
      local body, err = browser:get_uri(cmdUrl)
      if not body or err then
        log.error_print("Unable to delete message #" .. i .. ".\n")
      end
    end
  end

  -- Should we force a logout.  If this session runs for more than 20 minutes, things
  -- stop working
  --
  local currTime = os.clock()
  local diff = currTime - internalState.loginTime
  if diff > globals.nSessionTimeout then
    log.dbg("Sending Logout URL: " .. strCmdLogout .. "\n")
    local body, err = browser:get_uri(strCmdLogout)

    log.dbg("Logout forced to keep she.com session fresh and tasty!  Yum!\n")
    log.dbg("Session removed - Account: " .. internalState.strUser .. "@she.com\n")
    log.raw("Session removed (Forced by she.com timer) - Account: " .. internalState.strUser .. "@she.com") 
    session.remove(hash())
    return POPSERVER_ERR_OK
  end

  -- Save and then Free up the session
  --
  session.save(hash(), serialize_state(), session.OVERWRITE)
  session.unlock(hash())

  log.dbg("Session saved - Account: " .. internalState.strUser .. "@she.com\n")

  return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
  -- Have we done this already?  If so, we've saved the results
  --
  if internalState.bStatDone then
    return POPSERVER_ERR_OK
  end

  -- Local variables
  -- 
  local browser = internalState.browser
  local nPageCnt = 1
  local nMsgs = 0
  local nTotMsgs = 0  
  local uidls = {}
  local cmdUrl = string.format(globals.strCmdMsgList, nPageCnt)

  -- Debug Message
  --
  log.dbg("Stat URL: " .. cmdUrl .. "\n");

  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
    -- Tokenize out the message ID and size for each item in the list
    --    
    local items = mlex.match(body, globals.strMsgLineLitPattern, globals.strMsgLineAbsPattern)
    log.dbg("Stat Count: " .. items:count())

    if items:count() == 0 then
      log.dbg("Stat count is 0. Here is the page:\n" .. body .. "\n")
      return true, nil
    end 
    
    -- Cycle through the items and store the msg id and size
    --
    for i = 1, items:count() do
      local msgid = items:get(0, i - 1)
      local size = items:get(1, i - 1)

      if not msgid or not size then
        log.say("she.com Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      -- Get the message id.  
      --
      local _, _, uidl, msgno = string.find(msgid, globals.strMsgIDPattern)

      -- stupid she.com cannot handle last page
      if (uidls[uidl] ~= nil) then
        log.say("Stupid she.com cannot handle last page. UIDL " .. uidl .. " has been seen before. Skipping it now.\n")
      else
        internalState.msgno2msgid[uidl] = msgno
        -- Convert the size from it's string (12k) to bytes
        -- The unit is always k
        --
        _, _, size = string.find(size, "(%d+)k")
        size = math.max(tonumber(size), 0) * 1024

        -- Save the information
        --
        nMsgs = nMsgs + 1
        log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", MsgNo: " .. msgno .. ", Size: " .. size)
        set_popstate_nummesg(pstate, nMsgs)
        set_mailmessage_size(pstate, nMsgs, size)
        set_mailmessage_uidl(pstate, nMsgs, uidl)
        uidls[uidl] = uidl
      end
    end

    return true, nil
  end

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body)
    local _, _, currentpage, nextpage, nextpage2 = string.find(body, globals.strNextPagePattern)
    if currentpage ~= nil and nextpage ~= nil then
      nPageCnt = tonumber(nextpage)
      log.dbg("Next page: currentpage = " .. currentpage .. ", nextpage = " .. nextpage)
      cmdUrl = string.format(globals.strCmdMsgList, nPageCnt)
      return false
    else
      log.dbg("No more page. Page ends at " .. nPageCnt)
      return true
    end
  end

  -- Local Function to get the list of messages
  --
  local function funcGetPage()  
    -- Debug Message
    --
    log.dbg("Debug - Getting page: " .. cmdUrl)

    -- Get the page and check to see if we got results
    --
    local body, err = browser:get_uri(cmdUrl)
    if (body == nil or string.find(body, "[%s]NAME=\"SelectedMessages\"[%s]VALUE=\"") == nil) then
      log.dbg("Unable to get mail page. Going to retry.")
      body, err = browser:get_uri(cmdUrl)
      if body == nil then
        log.dbg("Retry get mail page failed.")
        return body, err
      end
    end

    -- Is the session expired
    --
    local _, _, strSessExpr = string.find(body, globals.strRetLoginSessionExpired)
    if strSessExpr ~= nil then
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
      cmdUrl = string.format(globals.strCmdMsgList, nPageCnt)

      -- Retry to load the page
      --
      body, err = browser:get_uri(cmdUrl)
    end

    -- Get the total number of messages
    --
    if nTotMsgs == 0 then
      _, _, nTotMsgs = string.find(body, globals.strMsgListCntPattern)

      if nTotMsgs == nil then
        nTotMsgs = 0
      else 
        nTotMsgs = tonumber(nTotMsgs)
      end
      log.dbg("Total messages in message list: " .. nTotMsgs)
    end

    return body, err
  end

  internalState.msgno2msgid = {}

  -- Run through the pages and pull out all the message pieces from
  -- all the message lists
  --
  if not support.do_until(funcGetPage, funcCheckForMorePages, funcProcess) then
    log.error_print("STAT Failed.\n")
    session.remove(hash())
    return POPSERVER_ERR_UNKNOWN
  end

  -- Make sure we processed the right amount
  --
  if (nMsgs < nTotMsgs) then
    log.say("she.com Module needs to fix it's individual message list pattern matching.\n")
    return POPSERVER_ERR_UNKNOWN
  end

  -- Update our state
  --
  internalState.bStatDone = true

  -- Return that we succeeded
  --
  return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate,msg)
  return common.uidl(pstate, msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
  return common.uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate,msg)
  return common.list(pstate, msg)
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
  return common.dele(pstate, msg)
end
-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
  return common.noop(pstate)
end
-- Produces a hopefully standard header
--
function mangleHeader(body)
  local from, to = string.find(body, globals.strHeaderTableStartPattern)
  if (from == nil and to == nil) then
    log.dbg("Header not found " .. body)
    return nil
  end
  local headerTable = string.sub(body, from + string.len(globals.strHeaderTableStartPattern))
  log.dbg("headerTable = " .. headerTable)

  local from1, to1 = string.find(headerTable, globals.strHeaderTableEndPattern)
  if (from1 == nil and to1 == nil) then
    return nil
  end
  headerTable = string.sub(headerTable, 1, from1)
  log.dbg("headerTable = " .. headerTable)

  local headers = ""
  local i = 1
  for x in string.gfind(headerTable, globals.strHeaderTableRowPattern) do
    log.dbg("i = " .. i .. ", x = " .. x)
    if i == 1 then
      if (x == nil or string.len(x) <= 0) then
        x = "(possible spammer)"
      else
        x = string.gsub(x, "[%s]%[", " <", 1)
        x = string.gsub(x, "%]", ">", 1)
      end
      headers = headers .. "From: " .. x .. "\r\n"
    elseif i == 2 then
      if (x == nil or string.len(x) <= 0) then
        x = "<Undisclosed-Recipient:;>" 
      end
      headers = headers .. "To: " .. x .. "\r\n"
    elseif i == 3 then
      if (x ~= nil and string.len(x) > 0) then
        headers = headers .. "Cc: " .. x .. "\r\n"
      end
    elseif i == 4 then
      if (x == nil or string.len(x) <= 0) then
        x = "(no subject)"
      end
      headers = headers .. "Subject: " .. x .. "\r\n"
    elseif i == 5 then
      if (x == nil or string.len(x) <= 0) then
        x = os.date("%a, %d %b %Y %H:%M:%S %Z")
      end
      headers = headers .. "Date: " .. x .. "\r\n"
    end
    i = i + 1
  end
  headers = headers .. "X-FreePOPs-She-Com-Login-Name: " .. internalState.strUser .. "\r\n"
  log.dbg("Headers:\n" .. headers)

  return headers  
end
-- Produces a better body to pass to the mimer
--
function mangleBody(body)
  local attach = {}
  -- extract mail body
  local from, to = string.find(body, globals.strMailBodyStartPattern)
  if (from ~= nil and to ~= nil) then
    log.dbg("from = " .. from .. ", to = " .. to .. "\n")
  else
    log.dbg("strMailBodyStartPattern not found!")
    return nil, nil, attach
  end
  local from1, to1 = string.find(body, globals.strMailBodyEndPattern)
  if (from1 ~= nil and to1 ~= nil) then
    log.dbg("from1 = " .. from1 .. ", to1 = " .. to1 .. "\n")
  else
    log.dbg("strMailBodyEndPattern not found!")
    return nil, nil, attach
  end
  local mailBodyForEye = string.sub(body, to, from1 - 1)
  log.dbg("Mail body #1 (may contains attachment table):\n" .. mailBodyForEye)

  -- find the attachment table
  local bWithAttach = false
  local afrom, ato = string.find(mailBodyForEye, globals.strMailAttachmentStartPattern)
  if (afrom ~= nil and ato ~= nil) then
    log.dbg("afrom = " .. afrom ..", ato = " .. ato .. "\n")
  end
  local afrom1, ato1 = string.find(mailBodyForEye, globals.strMailAttachmentEndPattern)
  if (afrom1 ~= nil and ato1 ~= nil) then
    log.dbg("afrom1 = " .. afrom1 ..", ato1 = " .. ato1 .. "\n")
  end
  if (afrom ~= nil and ato ~= nil and afrom1 ~= nil and ato1 ~= nil) then
    bWithAttach = true
    local attachment = string.sub(mailBodyForEye, ato, ato1)
    log.dbg("Attachment(s):\n" .. attachment)
    mailBodyForEye = string.sub(mailBodyForEye, 1, afrom - 1)
    -- extracts the attach list
    local x = mlex.match(attachment, globals.strAttachmentLitPattern, globals.strAttachmentAbsPattern)
    log.dbg(x:count() .. " attachments found")
    if x:count() <= 0 then
      log.error_print("Attachment lines found, but no attachment can be extracted")
      return nil, nil, attach
    end
    for i = 1, x:count() do
      log.dbg("Examining attachment:\n" .. x:get(0, i - 1))
      local _, _, attachurl = string.find(x:get(0, i - 1), globals.strAttachmentPattern)
      log.dbg("i = " .. i .. ", filename = " .. x:get(1, i - 1) .. ", attachurl = " .. attachurl)
      attach[x:get(1, i - 1)] = attachurl
      log.dbg("Attachment #" .. i .. ": " .. attach[x:get(1, i - 1)] .. "\n")
    end
  end
  log.dbg("Mail body #2 (attachment table removed):\n" .. mailBodyForEye)

  if string.find(mailBodyForEye, "^[%c]*<html>") == nil then
    log.dbg("Plaintext mail:\n" .. mailBodyForEye)
    return mailBodyForEye, nil, attach
  else -- HTML mail
    log.dbg("HTML mail\n")
    return nil, mailBodyForEye, attach
  end

end
-- Parse the message and returns head + body + attachments list
--
function parseSheComMail(pstate, msg)
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
  local msgUrl = string.format(globals.strCmdMsgViewMsg, uidl, internalState.strUser)
  log.dbg("Preparing to download message #" .. msg .. "(" .. uidl .. ") content from:\n" .. msgUrl .. "\n")

  -- get the main mail page
  local body, err = browser:get_uri(msgUrl)
  if (body == nil or err ~= nil) then
    log.error_print("Download message #" .. msg .. "(" .. uidl .. ") content failed.\n")
    return POPSERVER_ERR_UNKNOWN
  end

  -- get the headers
  local headers = mangleHeader(body)
  -- mangles the mail body
  local mailBody, mailBodyHtml, attach = mangleBody(body)

  return headers, mailBody, mailBodyHtml, attach
end
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata)
  local headers, body, bodyHtml, attach = parseMySinaMail(pstate, msg)
  local strHack = stringhack.new()
  local purge = false
  local browser = internalState.browser

  mimer.pipe_msg(headers, body, bodyHtml, "http://" .. browser:wherearewe(), attach, browser,
    function(s)
      if not purge then
        s = e:tophack(s, lines)
        popserver_callback(s, data)
        if e:check_stop(lines) then 
          purge = true
          return true 
        end
      end
    end)

  return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
  local headers, body, bodyHtml, attach = parseSheComMail(pstate, msg)
  local browser = internalState.browser
  mimer.pipe_msg(headers, body, bodyHtml, "http://" .. browser:wherearewe(), attach, browser,
    function(s)
      popserver_callback(s, pdata)
    end)

  return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
