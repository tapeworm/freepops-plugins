-- ************************************************************************** --
--  FreePOPs @netzero/juno webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russell822@yahoo.com>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.1.20090411"
PLUGIN_NAME = "juno.com"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=juno.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russell822@yahoo.com"}
PLUGIN_DOMAINS = {"@netzero.net","@netzero.com", "@juno.com"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		en = [[
Parameter is used to select the folder (Inbox is the default)
that you wish to access. The folders that are available are the standard 
Yahoo folders, called 
Inbox, Draft, Sent, Junk Mail and 
Trash. For user defined folders, use their name as the value.]]
		}	
	},
	{name = "emptytrash", description = {
		en = [[
Parameter is used to force the plugin to empty the trash when it is done
pulling messages.]]
		}	
	},
	{name = "resetheaders", description = {
		en = [[
Parameter is used to force the plugin to turn off full headers when it is done
pulling messages.]]
		}	
	},
	{name = "noattachments", description = {
		en = [[
Parameter is used to force the plugin to skip attachments.  To turn this on, 
set the value to 1.]]
		}	
	},
}
PLUGIN_DESCRIPTIONS = {
	en=[[
This is the webmail support for @juno.com, @netzero.net and @netzero.com mailboxes. 
To use this plugin you have to use your full email address as the user 
name and your real password as the password.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Login strings
  --
  strLoginHomeUrl = "http://webmail.%s/",
  strLoginCookieCRC = '_jsFileCrc = "([^"]+)"';
  strLoginURL = "http://webmail.%s/cgi-bin/login.cgi?rememberMe=0",   
  strLoginURL2 = "http://webmail.%s/cgi-bin/nz-login.cgi?rememberMe=0",   
  strLoginPostData = "domain=%s&PASSWORD=%s&LOGIN=%s",
  strLoginFailed = "Login Failed - Invalid User name and password",

  -- Expressions to pull out of returned HTML from Yahoo corresponding to a problem
  --
  strRetLoginBadPassword = "(Sign in to Email on the Web)",
  strRetLoginSessionExpired = '(var tofield = document.ComposeForm.To.value.length;)',

  -- Regular expression to extract the mail server
  --

  -- Extract the url to post the login data to
  --
  strLoginPostUrlPattern1='form action="([^"]*)"',
  strLoginPostUrlPattern2='name="([^"]*)" value="([^"]*)"',

  -- Extract the redirect url
  --
  strRedirectUrl = "window%.location%.replace%('([^']+)'%)",

  -- Extract the mail server
  --
  strMailServerPattern = '/(new/[567].*)$',

  -- Pattern to determine if we have no messages
  --
  strMsgListNoMsgPat = "(This folder has no messages)",

  -- Pattern to get the message list
  --
  --strMsgListPat = 'var msgnum = "([^"]+)";.-&nbsp;&nbsp;&nbsp;[^&]+&nbsp;.-&nbsp;&nbsp;&nbsp;([^K]+)K&nbsp;',
  strMsgListPat = 'msgNum=([^&]+)&block=.-&nbsp;&nbsp;&nbsp;[^&]+&nbsp;.-&nbsp;&nbsp;&nbsp;([^K]+)K&nbsp;',
  --strMsgListPat = "%[ '([^']+)' , '[^']+' , '[^']+' , '[^']+' , '([^']+)' , '[^']+' , '[^']*' , '[^']+' , '[^']+' , '[^']+' , '[^']+' , '[^']+' , '[^']*'%]",
  --strMsgListPat = '&msgNum=([^&]+)&block=.->&nbsp;&nbsp;&nbsp;([%d]+)K&nbsp;<',
                    
  -- Attachment patterns
  --
  strAttachLitPattern = ".*<table>.*<tr>.*<td>.*<img>.*</td>.*<td>.*<a>.*</a>.*</td>.*</tr>.*</table>",
  strAttachAbsPattern = "O<O>O<O>O<O>O<O>O<O>O<O>O<X>X<O>O<O>O<O>O<O>",

  -- Pattern used by Stat to get the next page in the list of messages
  --
  strMsgListNextPagePattern = '(>Next%([%d]+%)</a>)',

  -- The amount of time that the session should time out at.
  -- This is expressed in seconds
  --
  nSessionTimeout = 14400,  -- 4 hours!

  -- Defined Mailbox names - These define the names to use in the URL for the mailboxes
  --
  strInbox = "Inbox",
  strBulk = "Junk Mail",
  strTrash = "Trash",
  strDraft = "Draft",
  strSent = "Sent",

  -- Command URLS
  --
  strCmdMsgList = "%s/7?folder=%s",
  strCmdMsgView = "%s/8?msgNum=%s&folder=%s",
  strCmdDelete = "%s/7?folder=%s&command=delete&msgList=", 
  strCmdReadOptions = "%s/48",
  strCmdEmptyTrash = "%s/6?command=Empty&folder=Trash",
  strCmdLogout = "%s/14?type=signOut&GOTO_URL=http://my.juno.com&",

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
  bEmptyTrash = false,
  bResetHeaders = false,
  loginTime = nil,
  bNoAttach = false,
}

-- ************************************************************************** --
--  Helper functions
-- ************************************************************************** --

-- -------------------------------------------------------------------------- --
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

-- -------------------------------------------------------------------------- --
-- Computes the hash of our state.  Concate the user, domain, mailbox and password
--
function hash()
  return (internalState.strUser or "") .. "~" ..
         (internalState.strDomain or "") .. "~"  ..
         (internalState.strMBox or "") .. "~"  ..
	 internalState.strPassword -- this asserts strPassword ~= nil
end


-- -------------------------------------------------------------------------- ---- Issue the command to login
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
  local post = string.format(globals.strLoginPostData, domain, 
    password, username)
  local browser = internalState.browser

  local homeUrl = string.format(globals.strLoginHomeUrl, domain)
  local url = string.format(globals.strLoginURL, domain)
  if (domain == "netzero.net") then
    url = string.format(globals.strLoginURL2, domain)
  end
	
  -- DEBUG - Set the browser in verbose mode
  --
  -- browser:verbose_mode()

  -- Login
  --
  local body, err = browser:get_uri(homeUrl)

  -- set a cookie
  local crc = string.match(body, globals.strLoginCookieCRC)
  browser:add_cookie(homeUrl, "ajaxSupported=1/" .. crc .. "; domain=." .. domain .. "; path=/")

  -- Login
  body, err = browser:post_uri(url, post)

  -- Error checking
  --

  -- No connection
  --
  if body == nil then
    log.error_print("Login Failed: Unable to make connection")
    return POPSERVER_ERR_NETWORK
  end

  -- Check for invalid login
  -- 
  local str = string.match(body, globals.strRetLoginBadPassword)
  if str ~= nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_AUTH
  end

  -- Check for the redirect
  --
  str = string.match(body, globals.strRedirectUrl)
  if str ~= nil then
    body, err = browser:get_uri(str)
  else
    log.dbg("Unable to figure out server: " .. body)
  end

  -- Extract the mail server
  --
  internalState.strMailServer = "http://" .. browser:wherearewe()

  -- The login page sometimes returns a page where a form needs to be submitted.  
  -- We'll do it manually.  Extract the form elements and post the data
  -- 
  url = string.match(body, globals.strLoginPostUrlPattern1)
  if url ~= nil then
    url = internalState.strMailServer .. url
    local postdata = nil
    local name, value  
    for name, value in string.gfind(body, globals.strLoginPostUrlPattern2) do
      if postdata ~= nil then
        postdata = postdata .. "&" .. name .. "=" .. value  
      else
        postdata = name .. "=" .. value 
      end
    end
    body, err = browser:post_uri(url, postdata)

    -- Clean up the base url
    --
    internalState.strMailServer = "http://" .. browser:wherearewe() .. "/webmail"
  else
    -- Clean up the base url
    --
    internalState.strMailServer = "http://" .. browser:wherearewe() .. "/webmail"
  end

  -- DEBUG Message
  --
  log.dbg("Netzero/Juno Mail Server: " .. internalState.strMailServer .. "\n")

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true

  -- Note the time when we logged in
  --
  internalState.loginTime = os.clock();

  -- Turn on full headers
  --
  url = string.format(globals.strCmdReadOptions, internalState.strMailServer)
  local postdata = "headers=1&command=save&page=5"
  body, err = browser:post_uri(url, postdata)
	
  -- Debug info
  --
  log.dbg("Created session for " .. 
    internalState.strUser .. "@" .. internalState.strDomain .. "\n")

  -- Return Success
  --
  return POPSERVER_ERR_OK
end


-- -------------------------------------------------------------------------- ---- Download a single message
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
  local baseUrl = string.format(globals.strCmdMsgView, 
    internalState.strMailServer, uidl, internalState.strMBox)

  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- Modes(0 = No headers processed, 1 = Started receiving, 2 = End receiving,
    --   3 = Get Attachment list, 4 = getting body)
    --
    nMode = 0,

    -- Cache of the headers
    --
    strHeaders = "",

    -- Message Id
    --
    strMessageId = "",

    -- Cache the body
    --
    strBody = "", 

    -- Current attachment
    --
    bHasAttach = false,
    
    -- Is it a multipart-alternative
    --
    bHasAlt = false,

    -- Base URL
    --
    strBaseUrl = baseUrl,

    -- Encoding Buffer
    --
    strBuffer = "",

    -- String hacker
    --
    strHack = stringhack.new(),

    -- Lines requested (-2 means no limited)
    --
    nLinesRequested = nLines,

    -- Lines Received - Not really used for anything
    --
    nLinesReceived = 0,
  }
	
  -- Define the callback
  --
  local cb = downloadMsg_cb(cbInfo, data)

  -- Get the headers and the attachment list
  -- 
  browser:pipe_uri(baseUrl, cb)
  local attachments = {}
  if (internalState.bNoAttach == false) then
    attachments = getAttachmentTable(cbInfo, data)
  end

  -- Get the body
  --
  cbInfo.nMode = 4
  baseUrl = getBodyUrl(cbInfo, data)
  cb = downloadMsg_cb(cbInfo, data)
  browser:pipe_uri(baseUrl, cb)

  -- Cleanup the body if necessary
  --
  local str = string.match(cbInfo.strBody, "^(<pre>)")
  if str ~= nil then
    cbInfo.strBody = cleanupPreHtml(cbInfo.strBody, false)
  end
  local inlineids = findInlineAttachments(attachments, cbInfo)
    
  -- Pipe this through the mimer
  --
  --str = string.match(cbInfo.strBody, "(<[Hh][Tt][Mm][Ll]>)")
  local strBody, strHtml
  if str == nil then
    strBody = nil
    strHtml = cbInfo.strBody
  else
    strBody = cbInfo.strBody
    strHtml = nil
  end
  mimer.pipe_msg(
    cbInfo.strHeaders, 
    strBody, 
    strHtml, 
    internalState.strMailServer, 
    attachments, browser, 
    function(s)
      popserver_callback(s,data)
    end, inlineids)

  return POPSERVER_ERR_OK
end


-- -------------------------------------------------------------------------- ---- Callback for the retr function
--
function downloadMsg_cb(cbInfo, data)
	
  return function(body, len)
    -- Are we done with Top and should just ignore the chunks
    --
    if (cbInfo.nLinesRequested ~= -2 and cbInfo.nLinesReceived == -1) then
      return 0, nil
    end

    -- Do we need to get the headers
    --
    if cbInfo.nMode <= 2 then
      -- Get rid of the text before the <pre>
      --
      if cbInfo.nMode == 0 then
        body = string.match(body, "<pre>(.*)")
        if body == nil or string.len(body) == 0 then
          return len, nil
        end
        cbInfo.nMode = 1
      end

      -- Stop getting the headers at the </pre>
      --
      if cbInfo.nMode < 2 then
        local str = string.match(body, "(.*)</pre>")
        local str2 = string.match(body, "</pre>(.*)")
        if str ~= nil then
          body = cbInfo.strHeaders .. str
          body = processHeaders(body, cbInfo)
          cbInfo.strBuffer = cbInfo.strBuffer .. (str2 or "")
          return len, nil
        else
          -- Store what we have
          --
          cbInfo.strHeaders = cbInfo.strHeaders .. body
      
          -- We'll wait until we have the full headers before we process them
          --
          return len, nil
        end
      end

    -- We are still on the first page but are ignoring the data.  We
    -- Need to detect the end of the page and start the next fetch.
    --
    elseif cbInfo.nMode == 3 then
      -- Save the text left in here.  We'll be getting the list of
      -- of attachments from it.
      --
      cbInfo.strBuffer = cbInfo.strBuffer .. body
      return len, nil
    end
  
    -- Do some cleanup
    --
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

    -- We are downloading the body page.  Just buffer it for now.
    -- I realize that this isn't ideal but this is a start.
    --
    if cbInfo.nMode == 4  then
      cbInfo.strBody = cbInfo.strBody .. body
    end
			
    return len, nil
  end
end


-- -------------------------------------------------------------------------- ---- We captured the full text of the headers.  Now, process that text
-- and save it in the callback data structure
--
function processHeaders(body, cbInfo)
  cbInfo.nMode = 2

  -- We need to do some cleanup.  Remove escaped codes, and all links
  --
  cbInfo.strBuffer = string.gsub(body, "</pre>(.*)", "%1")
  body = cleanupPreHtml(body, true)
          
  -- Figure out if we have attachments
  --
  local strMimeBoundary = string.match(body, '(boundary=)')
  if strMimeBoundary ~= nil then
    cbInfo.bHasAttach = true
  else
    cbInfo.bHasAttach = false
  end
  
  -- Is this a multipart-alternative message?
  --
  local strAlternate = string.match(body, '(multipart/alternative)')
  if strAlternate ~= nil then
    cbInfo.bHasAlt = true
  end

  -- Get the message id
  --
  local strMessageId = string.match(body, "[Mm][Ee][Ss][Ss][Aa][Gg][Ee]%-I[dD]: <([^>]+)>")
  if strMessageId ~= nil then
    cbInfo.strMessageId = strMessageId
  end

  -- Some clean up of the headers
  --
  if cbInfo.bHasAttach == false then
    body = mimer.remove_lines_in_proper_mail_header(body, {
		"content%-disposition", "mime%-version"})
  else
    body = mimer.remove_lines_in_proper_mail_header(body, {"content%-type",
		"content%-disposition", "mime%-version", "boundary"})
  end
  body = mimer.txt2mail(body)

  -- Add a header in there which let's people know which account
  -- it came from -- This was done as at a user's request.
  --
  body = body .. "X-FreePOPs-Domain: " .. internalState.strDomain .. "\r\n";
  body = body .. "X-FreePOPs-Domain: " .. internalState.strMBox .. "\r\n";

  -- Save the headers.
  -- 
  cbInfo.strHeaders = body

  -- Set the mode to getting the attachment list
  --
  cbInfo.nMode = 3

  return body
end


-- -------------------------------------------------------------------------- --
function cleanupPreHtml(body, bHeader) 
  -- Juno/Netzero is retarded beyond belief.  For some reason, inside
  -- <pre>...</pre> content, they are putting in html tags.  We need to 
  -- get rid of it all
  --
  body = string.gsub(body, "(.*)</pre>(.*)", "%1")
  body = string.gsub(body, "&lt;", "<")
  body = string.gsub(body, "&gt;", ">")
  body = string.gsub(body, "&g\nt;", ">") -- Because Juno is retarded!
  body = string.gsub(body, "&\ngt;", ">") -- Because Juno is retarded!
  body = string.gsub(body, "&amp;", "&")
  body = string.gsub(body, "<a[^>]*>", "")
  body = string.gsub(body, "</a>", "")
  body = string.gsub(body, "<br>", "")
  body = string.gsub(body, "mailto:", "")
  body = string.gsub(body, "&quot;", '"')
  body = string.gsub(body, "<pre>", "")

  if (bHeader == true) then 
    body = string.gsub(body, "\n", "\n\n")
    body = string.gsub(body, "\n([^:][^:]-\n)", "%1")
    body = string.gsub(body, "\n\n", "~~CRLF~~")
    body = string.gsub(body, "\n", "")
    body = string.gsub(body, "~~CRLF~~", "\n")
  end
  return body
end

-- -------------------------------------------------------------------------- --
function getAttachmentTable(cbInfo, data)
  local attachments = {}
  local lookup = {}
  local body = cbInfo.strBuffer

  -- find attachments
  --
  for url, filename in 
    string.gfind(body,
      [[href=['"](21%?folder=[^'"]+attachId=[0-9]+)[^'"]*['"][^>]+>.-Name = "([^"]+)"]]) 
  do
    if (filename == "Message") then
      filename = "Message.htm"
    end
    url = internalState.strMailServer .. "/" .. url
    filename = getFilename(url, filename)
    log.dbg("Found Attachment, File: " .. filename .. " - Url: " .. url)
    attachments[filename] = url
  end
  
  return attachments
end

function findInlineAttachments(attachments, cbInfo) 
  local body = cbInfo.strBody
  local inlineids = {}
  local attachurl = ""
  local filename = ""
  local attachId = ""
  local cnt = 0

  -- Find inline images and sounds
  for url in string.gfind(body, [[[Ss][Rr][Cc]="(21[^"]+)"]]) do
    attachurl = internalState.strMailServer .. "/" .. url
    filename = "juno_attach_" .. cnt .. "." .. getExtension(attachurl)
    attachId = cbInfo.strMessageId .. "." .. cnt

    cbInfo.strBody = string.gsub(cbInfo.strBody, string.sub(url, 4), attachId)
    log.dbg("Found inline Attachment, File: " .. filename .. " - Url: " .. url)

    attachments[filename] = attachurl
    inlineids[filename] = attachId
    table.insert(attachments, table.getn(attachments) + 1, attachurl)
    table.insert(inlineids, table.getn(inlineids) + 1, attachId)
    cnt = cnt + 1
  end

  -- Fixing a weird lua bug where it won't replace a string with a ? in it and
  -- add the 
  --
  cbInfo.strBody = string.gsub(cbInfo.strBody, [[src="21.]], 'src="cid:')

  return inlineids
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

-- -------------------------------------------------------------------------- --
function getBodyUrl(cbInfo, data)
  local url = cbInfo.strBaseUrl .. "&attachId="
  if cbInfo.bHasAttach == true and cbInfo.bHasAlt == false then
    url = url .. "1"
  else
    url = url .. "0"
  end

  -- Reinitialize some variables
  --
  cbInfo.strBuffer = ""

  return url
end

-- -------------------------------------------------------------------------- --
function getContentType(url)
  local browser = internalState.browser
  local h, err = browser:get_head(url, {}, true)
  if (err ~= nil) then
    log.dbg(err)
    return "unknown/unknown"
  end
  local x = string.match(h,
                "[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:%s*([^\r]*)")
  return (x or "unknown/unknown")
end

function getFilename(url, filename)
  local browser = internalState.browser
  if (string.find(filename, "%.%.%.$") == nil) then
    return filename
  end

  local h, err = browser:get_head(url, {}, true)
  if (err ~= nil) then
    log.dbg(err)
    return filename
  end

  local x = string.match(h, 'filename= "([^"]+)"')
  if (x == nil) then
    return filename
  end
  return x
end

-- ************************************************************************** --
--  Pop3 functions that must be defined
-- ************************************************************************** --

-- -------------------------------------------------------------------------- --
-- Extract the user, domain and mailbox from the username
--
function user(pstate, username)
	
  -- Get the user, domain, and mailbox
  -- TODO:  mailbox - for now, just inbox
  --
  local domain = freepops.get_domain(username)
  local user = freepops.get_name(username)

  internalState.strDomain = domain
  internalState.strUser = user
  
  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder or globals.strInbox
  if mbox == nil then
    mbox = globals.strInbox
  elseif mbox == "Junk" or mbox == "Junk" then
    mbox = globals.strBulk
  end
  internalState.strMBox = mbox

  -- Should the trash be emptied at the end of the session?
  --
  local val = (freepops.MODULE_ARGS or {}).emptytrash or 0
  if val == "1" then
    log.dbg("Juno/Netzero: The trash will be emptied on quit.")
    internalState.bEmptyTrash = true
  end

  -- Should the trash be emptied at the end of the session?
  --
  local val = (freepops.MODULE_ARGS or {}).resetheaders or 0
  if val == "1" then
    log.dbg("Juno/Netzero: The full header option will be turn off on quit.")
    internalState.bResetHeaders = true
  end

  -- Should we skip attachments?
  --
  local val = (freepops.MODULE_ARGS or {}).noattachments or 0
  if val == "1" then
    log.dbg("Juno/Netzero: Attachments won't be downloaded.")
    internalState.bNoAttach = true
  end

  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
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

-- -------------------------------------------------------------------------- --
-- Quit abruptly
--
function quit(pstate)
  session.unlock(hash())
  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
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
  local baseUrl = string.format(globals.strCmdDelete, internalState.strMailServer,
    internalState.strMBox);
  local cmdUrl = baseUrl
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      cmdUrl = cmdUrl .. get_mailmessage_uidl(pstate, i) .. ";"
      dcnt = dcnt + 1

      -- Send out in a batch of 20
      --
      if math.fmod(dcnt, 20) == 0 then
        log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
        local body, err = browser:get_uri(cmdUrl)
        if not body or err then
          log.error_print("Unable to delete messages.\n")
        end
       
        -- Reset the variables
        --
        dcnt = 0
        cmdUrl = baseUrl
      end
    end
  end

  -- Send whatever is left over
  --
  if dcnt > 0 and dcnt < 20 then
    log.dbg("Sending Delete URL: " .. cmdUrl .. "\n")
    local body, err = browser:get_uri(cmdUrl)
    if not body or err then
      log.error_print("Unable to delete messages.\n")
    end
  end

  -- Empty the trash
  --
  if internalState.bEmptyTrash == true then
    cmdUrl = string.format(globals.strCmdEmptyTrash, internalState.strMailServer)
    log.dbg("Emptying the trash with URL: " .. cmdUrl .. "\n")
    local body, err = browser:get_uri(cmdUrl)
  end

  -- Turn off full headers
  --
  if internalState.bResetHeaders == true then
    cmdUrl = string.format(globals.strCmdReadOptions, internalState.strMailServer)
    log.dbg("Turning off full headers with URL: " .. cmdUrl .. "\n")
    local postdata = "headers=0&command=save&page=5"
    local body, err = browser:post_uri(cmdUrl, postdata)
  end

  -- Should we force a logout.  If this session runs for more than a day, things
  -- stop working
  --
  local currTime = os.clock()
  local diff = currTime - internalState.loginTime
  if diff > globals.nSessionTimeout then 
    cmdUrl = string.format(globals.strCmdLogout, internalState.strMailServer)
    log.dbg("Sending Logout URL: " .. cmdUrl .. "\n")
    local body, err = browser:get_uri(cmdUrl)
 
    log.dbg("Logout forced to keep juno/netzero session fresh and tasty!  Yum!\n")
    log.dbg("Session removed - Account: " .. internalState.strUser .. 
      "@" .. internalState.strDomain .. "\n")
    session.remove(hash())
    return POPSERVER_ERR_OK
  end

  -- Save and then Free up the session
  --
  session.save(hash(), serialize_state(), session.OVERWRITE)
  session.unlock(hash())

  log.dbg("Session saved - Account: " .. internalState.strUser .. 
    "@" .. internalState.strDomain .. "\n")

  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
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
  local cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
    internalState.strMBox);
  local baseUrl = cmdUrl

  -- Keep a list of IDs that we've seen.  With Juno/Netzero, their message list can 
  -- show messages that we've already seen.  This, although a bit hacky, will
  -- keep the unique ones.  We'll need to search the table on every message which
  -- really sucks!
  --
  local knownIDs = {}

  -- Debug Message
  --
  log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
    -- Find out if there are any messages
    -- 
    local nomesg = string.match(body, globals.strMsgListNoMsgPat)
    if (nomesg ~= nil) then
      return true, nil
    end
		
    -- Cycle through the items and store the msg id and size
    --
    local uidl, size  
    for uidl, size in string.gfind(body, globals.strMsgListPat) do

      if not uidl or not size then
        log.say("Netzero/Juno Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      local bUnique = true
      for j = 0, nMsgs do
        if knownIDs[j + 1] == uidl then
          bUnique = false
          break
        end        
      end

      -- Convert the size from it's string (4K) to bytes
      --
      --size = string.match(size, globals.strSizePattern)
      if (internalState.bNoAttach) then
        size = 2048
      else
        size = math.max(tonumber(size), 0) * 1024

        -- This was a reported issue by a user.  It looks like size is exceeding its max
        -- and rolling over.
        --
        if (size < 0) then  
          size = 1024
        end
      end
      -- Save the information
      --
      if bUnique == true then
        nMsgs = nMsgs + 1
        log.dbg("Processed STAT - Msg: " .. nMsgs .. 
	  ", UIDL: " .. uidl .. ", Size: " .. size)
        set_popstate_nummesg(pstate, nMsgs)
        set_mailmessage_size(pstate, nMsgs, size)
        set_mailmessage_uidl(pstate, nMsgs, uidl)
        knownIDs[nMsgs] = uidl
      end
    end
		
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- Look in the body and see if there is a link for a next page
    -- If so, change the URL
    --
    local nextURL = string.match(body, globals.strMsgListNextPagePattern)
    if nextURL ~= nil then
      nPage = nPage + 1
      cmdUrl = baseUrl .. "&block=" .. nPage
      return false
    else
      return true
    end
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
        internalState.strMBox);

      -- Retry to load the page
      --
      return browser:get_uri(cmdUrl)
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
	
  -- Update our state
  --
  internalState.bStatDone = true
	
  -- Return that we succeeded
  --
  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
--
function uidl(pstate,msg)
  return common.uidl(pstate, msg)
end

-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
--
function uidl_all(pstate)
  return common.uidl_all(pstate)
end

-- -------------------------------------------------------------------------- --
-- Fill msg size
--
function list(pstate,msg)
  return common.list(pstate, msg)
end

-- -------------------------------------------------------------------------- --
-- Fill all messages size
--
function list_all(pstate)
  return common.list_all(pstate)
end

-- -------------------------------------------------------------------------- --
-- Unflag each message marked for deletion
--
function rset(pstate)
  return common.rset(pstate)
end

-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
--
function dele(pstate,msg)
  return common.dele(pstate, msg)
end

-- -------------------------------------------------------------------------- --
-- Do nothing
--
function noop(pstate)
  return common.noop(pstate)
end

-- -------------------------------------------------------------------------- --
-- Retrieve the message
--
function retr(pstate, msg, data)
  if not common.check_range(pstate,msg) then
    log.say("Message index out of range.\n")
    return POPSERVER_ERR_NOMSG
  end
  downloadMsg(pstate, msg, -2, data)
  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Top Command (like retr)
--
function top(pstate, msg, nLines, data)
  if not common.check_range(pstate,msg) then
    log.say("Message index out of range.\n")
    return POPSERVER_ERR_NOMSG
  end
  downloadMsg(pstate, msg, nLines, data)
  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
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
