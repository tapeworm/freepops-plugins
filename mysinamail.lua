-- ************************************************************************** --
--  FreePOPs @mysinamail.com webmail interface
-- 
--  $Id: mysinamail.lua,v 1.10 2006/01/15 19:43:15 gareuselesinge Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Me <Me@myhouse>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.02"
PLUGIN_NAME = "mysinamail.com"
PLUGIN_REQUIRE_VERSION = "0.2.6"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=mysinamail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org"
PLUGIN_AUTHORS_NAMES = {"Angus Lee"}
PLUGIN_AUTHORS_CONTACTS = {"anguslee (at) mysinamail (dot) com"}
PLUGIN_DOMAINS = {"@mysinamail.com"} -- actual e-mail address will be determined after login
PLUGIN_REGEXES = {"@sina*.com"}
PLUGIN_PARAMETERS = { 
  {name="emptytrash", 
   description={en="Mail in the trash can are automatically deleted by MySinaMail every day, so this option has no use."}},
}
PLUGIN_DESCRIPTIONS = {
  en=[[
This is the webmail support for @mysinamail.com and all its other domain mailboxes. 
To use this plugin you have to use your Sina.com.hk member name plus "@mysinamail.com" as the user 
name and your real password as the password.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Login strings
  --
  strLoginPage = "https://login.sina.com.hk/cgi-bin/index.cgi?action=login",
  strLoginPostData = "action=login&.channel=mysinamail&.dest=http%%3A%%2F%%2Fmysinamail.sina.com.hk%%2F&.landing=&.skiplanding=1&.passive=0&.destu=http%%3A%%2F%%2Fmysinamail.sina.com.hk%%2F&login=%s&password=%s",

  -- Expressions to pull out of returned HTML from mysinamail.com corresponding to a problem
  --
  strRetLoginFailed = "<label[%s]class='error'>(.[^<]+)</label>", -- ???????????????????
  strRetLoginSessionExpired = "[%s]class=fred[%s]height=\"[%d]+\">(.[^<]+)</td>", -- ???? (???????)

  -- Get the e-mail address
  --
  strRegExpEMailAddr = "href=\"/cgi%-bin/mail/chkmsgs%.cgi%?sid=([%w%p^&]+)&lang2=(%w+)&f=1&sn=([%w%p^&]+)\">([%w%p]+)@([%w%p]+)</a>",

  -- Used by Stat to pull out the message ID and the size
  --
  -- strMsgLinePattern = "[%s]name=mid[%s]value=\"([%w%p]+)[%s]\"[%s]onclick=.[^w^i^d^t^h^=^\"^8^8^\"]+[%s]width=\"88\"><big>([%w%p]+)</big>",
  -- <tr><td class="inbox_unread" height="31" align="center" width="43"><input type="checkbox" name=mid value="1152777012.22883.sina101.sina.com.hk " onclick=unselectall()></td>
  -- <td class="inbox_unread" align=center width=12><img src=/images2/clip.gif></TD>
  -- <td class="inbox_unread" height="31" width="228"><big><a href="/cgi-bin/mail/rdMail.cgi?mid=1152777012.22883.sina101.sina.com.hk&sid=BJkulanagZoIaoTSxSEWWwo8ZtugolnxgZ_TlwunT8W-oEwlm_lumg-XuWTT!&folder=new&lang2=b5&sn=ZX0lcYQp_XC1Wx-STfpGW&next=1151593461.2104628.0:2,S&prev="><span title='"Genevieve Harrison" &#60;tkress@emdas.com&#62;'>&lt;Genevieve Harrison&gt;</span></a></big>&nbsp;</td>
  -- <td class="inbox_unread" height="31" width="128"><big>13 Jul 2006</big></td>
  -- <td class="inbox_unread" height="31" width="402"><big><a href="/cgi-bin/mail/rdMail.cgi?mid=1152777012.22883.sina101.sina.com.hk&sid=BJkulanagZoIaoTSxSEWWwo8ZtugolnxgZ_TlwunT8W-oEwlm_lumg-XuWTT!&folder=new&lang2=b5&sn=ZX0lcYQp_XC1Wx-STfpGW&next=1151593461.2104628.0:2,S&prev="><b>select bestseller action</b></a></big></td>
  -- <td class="inbox_unread" height="31" width="88"><big>1.2K</big></td></tr>
  strMsgLineLitPattern = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*{img}[.*]</td>.*<td>.*<big>.*<a>.*<span>.*</span>.*</a>.*</big>.*</td>.*<td>.*<big>.*</big>.*</td>.*<td>.*<big>.*<a>.*{b}[.*]{/b}[.*]</a>.*</big>.*</td>.*<td>.*<big>.*</big>.*</td>.*</tr>",
  strMsgLineAbsPattern = "O<O>O<O>O<X>O<O>O<O>O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>X<O>O<O>O<O>", 

  -- MSGID Pattern
  --
  strMsgIDPattern = "[%s]name=mid[%s]value=\"([%w%p^%s]+)[%s]\"[%s]onclick=",

  -- Used by Stat to pull out the next page
  --
  strNextPagePattern = "[%s][hH][rR][eE][fF]=\"/cgi%-bin/mail/chkmsgs%.cgi%?sid=([%w%p^&]+)&lang2=(%w+)&folder=new&f=1&sn=([%w%p^&]+)&startmsg=([%d]+)&nummsg=([%d]+)\">(.[^<]+)</a>[%s]&gt;&gt;</big>",

  -- Pattern used by Stat to get the total number of messages
  --
  strMsgListCntPattern = "[%s]<b[%s]class=fblue>(%d+)</b>[%s]",

  -- Header Pattern
  --
  strHeaderTableStartPattern = "[%s]bgcolor=\"F9F9F9\"[%s]class=\"topLineGrey\">",
  strHeaderTableEndPattern = "</tr>\n</table>\n<table[%s]",
  strHeaderTableRowPattern = "[%s]class=\"tgrey2\"[%s]?.->(.-)</?",

  -- Plaintext mail body Pattern
  --
  strMailBodyStartPattern = "[%s]class=\"%+fs%+\">\"%);\n</script>\n",
  strMailBodyEndPattern = "[%s]</tr>\n<tr><td>____________________________________________________________________________\n<table[%s]",
  strMailAttachmentStartPattern = "<BR><BR>\n%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-<BR>\n....:[%s]<a[%s]",
  strMailAttachmentEndPattern = "%)<BR>\n%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-[%s]</tr>",
  -- strNonHTMLMailPattern = "<BR>\n<BR>\n$",
  -- strNonHTMLMailWithAttachPattern = "<BR>\n$",

  -- Attachment Pattern
  --
  strAttachmentLitPattern = ".*<BR>.*<BR>.*<BR>.*<a>.*</a>.*<BR>.*<BR>",
  strAttachmentAbsPattern = "O<O>O<O>O<O>O<X>O<O>O<O>O<O>",
  strAttachmentPattern = "[%s]href=\"attachment\.cgi/([%w%p^/]+)/Application/OCTET%-STREAM/(([%w%p^,]+),S)\.([%w%p\/]+)/(.+)\"[%s]target=_blank",

  -- Defined Mailbox names - These define the names to use in the URL for the mailboxes
  -- folder=<strInBox>
  --
  strInbox = "1", -- seems no use

  -- The amount of time that the session should time out at.
  -- This is expressed in seconds
  --
  nSessionTimeout = 1080,  -- 20 minutes!

  -- Command URLS
  -- http://mysinamail.sina.com.hk/cgi-bin/mail/chkmsgs.cgi?sid=BQ`aiYakmuaTkkyM0-tJotJifHJfkayamviyoTMyHmp3yf0QUikYkYUYHa-J3&lang2=b5&folder=new&f=1&sn=ki2xojb-liC3T6BdesuSh&startmsg=0&nummsg=20
  strCmdMsgList = "http://mysinamail.sina.com.hk/cgi-bin/mail/chkmsgs.cgi?sid=%s&lang2=%s&folder=new&f=1&sn=%s&startmsg=%d&nummsg=%d",
  strCmdMsgViewMsg = "http://mysinamail.sina.com.hk/cgi-bin/mail/rdMail.cgi?mid=%s&sid=%s&folder=new&lang2=%s&sn=%s&next=&prev=",
  strCmdMsgViewAttachment = "http://mysinamail.sina.com.hk/cgi-bin/mail/attachment.cgi/%s/Application/OCTET-STREAM/%s.%s/%s",
  strCmdDelete = "http://mysinamail.sina.com.hk/cgi-bin/mail/msgactions.cgi?sn=%s",
  strCmdDeletePost = "folder=new&sid=%s&sn=%s&lang2=%s&para=Delete&onlynew=&act=&com=&to1=none&to=none&istartmsg=",
  -- strCmdLogout = "http://mysinamail.sina.com.hk/cgi-bin/login.cgi?sn=%s&cmd=logout",
  strCmdLogout = "https://login.sina.com.hk/cgi-bin/index.cgi?action=logout&.dest=http%3A%2F%2Flogin.sina.com.hk%2Fcgi-bin%2Findex.cgi",
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  strUser = nil,
  strPassword = nil,
  bLoginDone = false,
  browser = nil,
  strEmail = nil,
  strEmailUser = nil,
  strEmailDomain = nil, -- actual e-mail domain is not known until successfully login
  strSID = nil,
  strLang2 = nil,
  strSN = nil,
  loginTime = nil,
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
    PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' found!\n")

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
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
  -- Get the user, domain, and mailbox
  --
  local domain = freepops.get_domain(username)
  local membername = freepops.get_name(username)

  -- Get the user
  --
  if membername == nil then
    log.error_print("Unable to get Sina.com.hk member name.")
    return POPSERVER_ERR_AUTH
  else
    internalState.strUser = membername
    
    log.dbg("Account: " .. membername .. "@" .. domain .. ".\n")
  end

  return POPSERVER_ERR_OK
end
-- Computes the hash of our state.  Concate the user, domain, mailbox and password
--
function hash()
  return (internalState.strUser or "") .. "~" ..
   internalState.strPassword -- this asserts strPassword ~= nil
end
function login()
  -- Check to see if we've already logged in
  --
  if internalState.loginDone then
    return POPSERVER_ERR_OK
  end

  -- Create a browser to do the dirty work
  --
  internalState.browser = browser.new()

  -- DEBUG - Set the browser in verbose mode
  --
  internalState.browser:verbose_mode()

  -- Disable SSL certificates verification
  --
  internalState.browser:ssl_init_stuff()

  -- Login
  --
  local body, err = internalState.browser:post_uri(globals.strLoginPage, string.format(globals.strLoginPostData, internalState.strUser, internalState.strPassword))
  
  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection" .. err)
    return POPSERVER_ERR_NETWORK
  end

  -- Check for invalid login/password
  -- 
  local _, _, str = string.find(body, globals.strRetLoginFailed)
  if str ~= nil then
    log.error_print("Login Failed: " .. str)
    return POPSERVER_ERR_AUTH
  end
  -- _, _, str = string.find(body, globals.strRetLoginBadPassword)
  -- if str ~= nil then
    -- log.error_print("Login Failed: " .. str)
    -- return POPSERVER_ERR_AUTH
  -- end

  -- Extract the SID, SN, and e-mail address
  --
  local _, _, sid, lang2, sn, email, domain = string.find(body, globals.strRegExpEMailAddr) -- SID and SN can be obtained from cookies as well
  if sid == nil or lang2 == nil or sn == nil or email == nil or domain == nil then
    log.error_print("Login Failed: Unable to detect e-mail address")
    return POPSERVER_ERR_UNKNOWN
  else
    internalState.strEmail = string.format("%s@%s", email, domain)
    internalState.strEmailUser = email
    internalState.strEmailDomain = domain
    internalState.strSID = sid
    internalState.strLang2 = lang2
    internalState.strSN = sn

    -- DEBUG Message
    --
    log.dbg("SID = " .. sid .. "\nlang2 = " .. lang2 .. "\nSN = " .. sn .. "\n")
    log.dbg("SID (cookie) = " .. internalState.browser:get_cookie("SID").value .. "\nSN (cookie) = " .. internalState.browser:get_cookie("SN").value .. "\n")
    log.dbg("MySinaMail.com e-mail address: " .. email .. "@" .. domain .. "\n")
  end

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true

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
      log.dbg("Error: Session locked - Account: " .. internalState.strUser .. "@mysinamail.com\n")
      return POPSERVER_ERR_LOCKED
    end

    -- Load the session which looks to be a function pointer
    --
    local func, err = loadstring(sessID)
    if not func then
      log.error_print("Unable to load saved session (Account: " .. internalState.strUser .. "@mysinamail.com): ".. err)
      return login()
    end

    log.dbg("Session loaded - Account: " .. internalState.strUser .. "@mysinamail.com\n")

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

  return serial.serialize("internalState", internalState) .. internalState.browser:serialize("internalState.browser")
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
  local cmdUrl = string.format(globals.strCmdDelete, internalState.strSN)
  local postdata = string.format(globals.strCmdDeletePost, internalState.strSID, internalState.strSN, internalState.strLang2)
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      postdata = postdata .. "&mid=" .. get_mailmessage_uidl(pstate, i) .. " "
      log.dbg("Message #" .. i .. "(" .. get_mailmessage_uidl(pstate, i) .. ") to be deleted\n")
      dcnt = dcnt + 1
    end
  end

  -- Send them
  --
  if dcnt > 0 then
    log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
    log.dbg("Sending Delete parameters: " .. postdata .. "\n")
    local body, err = browser:post_uri(cmdUrl, postdata)
    if not body or err then
      log.error_print("Unable to delete messages.\n")
    end
  end

  -- Should we force a logout.  If this session runs for more than 20 minutes, things
  -- stop working
  --
  local currTime = os.clock()
  local diff = currTime - internalState.loginTime
  if diff > globals.nSessionTimeout then
    cmdUrl = string.format(globals.strCmdLogout, internalState.strSN)
    log.dbg("Sending Logout URL: " .. cmdUrl .. "\n")
    local body, err = browser:get_uri(cmdUrl)

    log.dbg("Logout forced to keep mail.com session fresh and tasty!  Yum!\n")
    log.dbg("Session removed - Account: " .. internalState.strEmail .. "\n")
    log.raw("Session removed (Forced by MySinaMail.com timer) - Account: " .. internalState.strEmail) 
    session.remove(hash())
    return POPSERVER_ERR_OK
  end

  -- Save and then Free up the session
  --
  session.save(hash(), serialize_state(), session.OVERWRITE)
  session.unlock(hash())

  log.dbg("Session saved - Account: " .. internalState.strEmail .. "\n")

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
  local nMsgs = 0
  local nPrevCnt = 0
  local nPageMsgCnt = 0
  local nTotMsgs = 0;
  local cmdUrl = string.format(globals.strCmdMsgList, internalState.strSID, internalState.strLang2, internalState.strSN, nPrevCnt, nPageMsgCnt)

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
        log.say("MySinaMail.com Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end
      
      -- Get the message id.  
      --
      local _, _, uidl = string.find(msgid, globals.strMsgIDPattern)

      -- Convert the size from it's string (5.7K) to bytes
      -- First figure out the unit (K)
      --
      local _, _, kbUnit = string.find(size, "(K)")
      _, _, size = string.find(size, "([%d]*%.*[%d]*)K")
      if not kbUnit then 
        size = math.max(tonumber(size), 0)
      else
        size = math.max(tonumber(size), 0) * 1024
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
    local _, _, sid, lang2, sn, prevcnt, pagemsgcnt = string.find(body, globals.strNextPagePattern)
    if prevcnt ~= nil and pagemsgcnt ~= nil then
      log.dbg("Next page: nPrevCnt = " .. prevcnt .. ", nPageMsgCnt = " .. pagemsgcnt)
      nPrevCnt = tonumber(prevcnt)
      nPageMsgCnt = tonumber(pagemsgcnt)
      cmdUrl = string.format(globals.strCmdMsgList, internalState.strSID, internalState.strLang2, internalState.strSN, nPrevCnt, nPageMsgCnt)
      return false
    else
      log.dbg("No more page. Page ends at " .. nPrevCnt / nPageMsgCnt)
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
    if (body == nil or string.find(body, "[%s]name=mid[%s]value=\"") == nil) then
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
      cmdUrl = string.format(globals.strCmdMsgList, internalState.strSID, internalState.strLang2, internalState.strSN, nPrevCnt, nPageMsgCnt)

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
      -- nTotMsgs = 20
      log.dbg("Total messages in message list: " .. nTotMsgs)
    end

    return body, err
  end

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
    log.say("MySinaMail.com Module needs to fix it's individual message list pattern matching.\n")
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
-- Calls mimer.html2txtplain() as well as unescaping &#dd; and &#xHH;
-- This function is not required if mimer.html2txt() can decode numeric entities
--
function html2text(htmltext)
  if (htmltext ~= nil) then
    local plaintext = mimer.html2txtplain(htmltext, "http://" .. internalState.browser:wherearewe())
    -- plaintext = string.gsub(plaintext, "&#38;", "&");
    -- plaintext = string.gsub(plaintext, "&#60;", "<");
    -- plaintext = string.gsub(plaintext, "&#62;", ">");
    -- decode numeric entities
    plaintext = string.gsub(plaintext, "(&#(%d-);)", function(c, d)
      if (d ~= nil and tonumber(d, 10) > 255) then
        return c
      else
        return string.char(tonumber(d, 10)) or c
      end
    end)
    -- decode hexadecimal entities
    plaintext = string.gsub(plaintext, "(&#x(%x-);)", function(c, x)
      if (x ~= nil and tonumber(x, 16) > tonumber("0xff", 16)) then
        return c
      else
        return string.char("0x" .. x) or c
      end
    end)
    return plaintext
  else
    return nil
  end
end
-- Produces a hopefully standard header
--
function mangleHeader(body)
  local from, to = string.find(body, globals.strHeaderTableStartPattern)
  if (from == nil and to == nil) then
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
    log.dbg("i = " .. i .. ", x = " .. x) -- i = 5 can be ignored
    if i == 1 then
      x = html2text(x)
      if (x == nil or string.len(x) <= 0) then
        x = "(possible spammer)"
      end
      headers = headers .. "From: " .. string.sub(x, 1, string.len(x) - 2) .. "\r\n"
    elseif i == 2 then
      x = html2text(x)
      if (x == nil or string.len(x) <= 0) then
        x = "<Undisclosed-Recipient:;>" 
      end
      headers = headers .. "To: " .. x .. "\r\n"
    elseif i == 3 then
      if (x == nil or string.len(x) <= 0) then
        x = os.date("%a, %d %b %Y %H:%M:%S %Z")
      end
      headers = headers .. "Date: " .. x .. "\r\n"
    elseif i == 4 then
      x = html2text(x)
      if (x == nil or string.len(x) <= 0) then
        x = "(no subject)"
      end
      headers = headers .. "Subject: " .. x .. "\r\n"
    end
    i = i + 1
  end
  headers = headers .. "X-FreePOPs-Sina-Member-Name: " .. internalState.strUser .. "\r\n"
  headers = headers .. "X-FreePOPs-MySinaMail-Domain: " .. internalState.strEmailDomain .. "\r\n"
  log.dbg("Headers:\n" .. headers)

  return headers
end
-- Determine e-mail body is plaintext or HTML
--
-- function isNonHTMLMail(body)
  -- local mailBody = mimer.remove_tags(body, {"a", "br"}) -- MySinaMail add <a> to URL and <BR> to end of line to a plaintext e-mail
  -- if string.find(mailBody, "<.+>") ~= nil then
    -- return false -- contains HTML tags
  -- else
    -- return true -- no HTML tags
  -- end
-- end
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
  local mailBodyForEye = string.sub(body, to + 1, from1 + 5)
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
    local attachment = string.sub(mailBodyForEye, afrom, ato1 - 6) .. "<BR>"
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
      local _, _, name, mid, _, fname, ofname = string.find(x:get(0, i - 1), globals.strAttachmentPattern)
      log.dbg("i = " .. i .. ", name = " .. name .. ", mid = " .. mid .. ", fname = " .. fname .. ", ofname = " .. ofname)
      attach[ofname] = string.format(globals.strCmdMsgViewAttachment, name, mid, fname, ofname)
      -- table.setn(attach, table.getn(attach) + 1)
      log.dbg("Attachment #" .. i .. ": " .. attach[ofname] .. "\n")
    end
  else
    mailBodyForEye = string.sub(mailBodyForEye, 1, string.len(mailBodyForEye) - 6)
  end
  -- log.dbg(string.byte(string.sub(mailBodyForEye, string.len(mailBodyForEye) - 1)))
  log.dbg("Mail body #2 (attachment table removed):\n" .. mailBodyForEye)

  -- if (bWithAttach ~= true and string.find(mailBodyForEye, globals.strNonHTMLMailPattern) ~= nil or bWithAttach ~= false and string.find(mailBodyForEye, globals.strNonHTMLMailWithAttachPattern) ~= nil) then -- Plaintext
  -- if (isNonHTMLMail(mailBodyForEye) ~= false) then
  local s = mimer.remove_tags(mailBodyForEye, {"a", "br"})
  if string.find(s, "<.+>") == nil then
    -- local s = mimer.remove_tags(mailBodyForEye, {"a", "br"})
    s = html2text(s)
    log.dbg("Plaintext mail:\n" .. s)
    return s, nil, attach
  else -- HTML mail
    log.dbg("HTML mail\n")
    return nil, mailBodyForEye, attach
  end
end
-- Parse the message and returns head + body + attachments list
--
function parseMySinaMail(pstate, msg)
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
  local msgUrl = string.format(globals.strCmdMsgViewMsg, uidl, internalState.strSID, internalState.strLang2, internalState.strSN)
  log.dbg("Preparing to download message #" .. msg .. "(" .. uidl .. ") content from:\n" .. msgUrl .. "\n")
  -- local attachmentUrl = string.format(globals.strCmdMsgViewAttachment, internalState.strMailServer, internalState.strMBox, uidl)

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
  local headers, body, bodyHtml, attach = parseMySinaMail(pstate, msg)
  local browser = internalState.browser
  mimer.pipe_msg(headers, body, bodyHtml, "http://" .. browser:wherearewe(), attach, browser,
    function(s)
      popserver_callback(s, pdata)
    end)

  return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
