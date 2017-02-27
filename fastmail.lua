-- ************************************************************************** --
--  FreePOPs @fastmail.com webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russell822@yahoo.com>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.1.20100903"
PLUGIN_NAME = "fastmail.com"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=fastmail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager"}
PLUGIN_AUTHORS_CONTACTS = {"russell822 (at) yahoo (.) com"}
PLUGIN_DOMAINS = { "@123mail.org", "@150mail.com", "@150ml.com", "@16mail.com",
"@2-mail.com", "@4email.net", "@50mail.com", "@airpost.net", "@allmail.net", 
"@bestmail.us", "@cluemail.com", "@elitemail.org", "@emailgroups.net", "@emailplus.org", 
"@emailuser.net", "@eml.cc", "@fastem.com", "@fast-email.com", "@fastemail.us", 
"@fastemailer.com", "@fastest.cc", "@fastimap.com", "@fastmail.cn", "@fastmail.com.au", 
"@fastmail.fm", "@fastmail.us", "@fastmail.co.uk", "@fastmail.to", "@fmail.co.uk", 
"@fast-mail.org", "@fastmailbox.net", "@fastmessaging.com", "@fea.st", "@f-m.fm", 
"@fmailbox.com", "@fmgirl.com", "@fmguy.com", "@ftml.net", "@hailmail.net", 
"@imap.cc", "@imap-mail.com", "@imapmail.org", "@internet-e-mail.com", "@internetemails.net", 
"@internet-mail.org", "@internetmailing.net", "@jetemail.net", "@justemail.net", "@letterboxes.org", 
"@mailandftp.com", "@mailas.com", "@mailbolt.com", "@mailc.net", "@mailcan.com", "@mail-central.com", 
"@mailforce.net", "@mailftp.com", "@mailhaven.com", "@mailingaddress.org", "@mailite.com", 
"@mailmight.com", "@mailnew.com", "@mail-page.com", "@mailsent.net", "@mailservice.ms", 
"@mailup.net", "@mailworks.org", "@ml1.net", "@mm.st", "@myfastmail.com", "@mymacmail.com", 
"@nospammail.net", "@ownmail.net", "@petml.com", "@postinbox.com", "@postpro.net",
"@proinbox.com", "@promessage.com", "@realemail.net", "@reallyfast.biz", "@reallyfast.info", 
"@rushpost.com", "@sent.as", "@sent.at", "@sent.com", "@speedpost.net", "@speedymail.org", 
"@ssl-mail.com", "@swift-mail.com", "@the-fastest.net", "@theinternetemail.com", "@the-quickest.com", 
"@veryfast.biz", "@veryspeedy.net", "@warpmail.net", "@xsmail.com", "@yepmail.net", "@your-mail.com", 
      }
PLUGIN_PARAMETERS = {
	{name = "view", description = {
		it = [[ Viene usato per determinare la lista di messaggi da scaricare. I valori possibili sono All (tutti), Unread (non letti) e Flag.]],
		en = [[ Parameter is used when getting the list of messages to 
pull.  It determines what messages to be pulled.  Possible values are All, Unread and Flag.]]
		}
	},
	{name = "keepmsgstatus", description = {
		en = [[
Parameter is used to maintain the status of the message in the state it was before being pulling.  If the value is 1, the behavior is turned on
and will override the markunread flag. ]]
		}	
	},
	{name = "domain", description = {
		en = [[
Parameter is used to override the domain in the email address.  This is used so that users don't
need to add a mapping to config.lua for a hosted hotmail account. ]]
		}
	},		
}
PLUGIN_DESCRIPTIONS = {
	en=[[
This is the webmail support for @fastmail.fm, @fmailbox.com and similar mailboxes. 
To use this plugin you have to use your full email address as the user 
name and your real password as the password.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  host = 'mail.messagingengine.com',
  port = 143,

  strInbox = "INBOX",
  strTrash = "INBOX.Trash",

  strViewAll = "all",
  strViewUnread = "Seen",
  strViewFlagged = "Flagged",

  strViewAllPat = "([Aa]ll)",
  strViewUnreadPat = "([Uu]nread)",
  strViewFlaggedPat = "([Ff]lagged)",
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  strUser = nil,
  strPassword = nil,
  strDomain = nil,
  strMBox = nil,
  socket = nil,
  strView = nil,
  cnt = 1000,
  nMsgs = 0,
  nTotMsgs = 0,
  cbInfo = nil,
  msgids = {},
  bKeepMsgStatus = false,  
}

-- ************************************************************************** --
--  Helper functions
-- ************************************************************************** --

-- Issue the command to login
--
function login()
  -- Check to see if we've already logged in
  --
  if internalState.loginDone then
    return POPSERVER_ERR_OK
  end

  -- Define some local variables
  --
  local username = internalState.strUser
  local domain = internalState.strDomain
  local password = internalState.strPassword
	
  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true

  -- let's connect
  --
  internalState.socket = psock.connect(globals.host, globals.port, true)
  if not internalState.socket then
	log.error_print("Fastmail: Connection failed!")
	return POPSERVER_ERR_NETWORK
  end
	
  local str = nil
  str = internalState.socket:recv()
  if not str or string.match(str, "OK IMAP") == nil then
    log.error_print("Error receiving the welcome")
	return POPSERVER_ERR_NETWORK
  end
  
  local rc, str = sendCmd("login " .. username .. "@" .. domain .. " " .. password, nil)
  if (rc ~= POPSERVER_ERR_OK or string.match(str, "OK User logged in") == nil) then
    log.error_print("Login failed")
	return POPSERVER_ERR_AUTH
  end
  
  rc, str = sendCmd("examine " .. internalState.strMBox, nil)
  if (rc ~= POPSERVER_ERR_OK or string.match(str, "NO EXAMINE failure") ~= nil) then
    log.error_print("Folder: " .. internalState.strMBox .. " is invalid.")
	return POPSERVER_ERR_AUTH
  end
  
  -- Return Success
  --
  return POPSERVER_ERR_OK
end

function sendCmd(cmd, f)
  internalState.cnt = internalState.cnt + 1
  cmd = internalState.cnt .. " " .. cmd
  local rc
  if internalState.socket ~= nil then
	rc = internalState.socket:send(cmd)
  else 
	tc = -1
  end
	
  if rc < 0 then 
	log.error_print("Short send of "..rc..
		" instead of "..string.len(cmd).."\n")
	return POPSERVER_ERR_NETWORK 
  end

  local str = ""
  local done = false
  while (not done) do
    local newstr = internalState.socket:recv()
	if f then 
	  f(newstr)
      if (string.match(newstr, internalState.cnt .. " OK")) then
	    done = true
	  end
	else
  	  if (newstr == nil) then
	    str = "-ERR network error"
	    done = true
	  end
	
	  if (done == false) then
	    if (string.match(newstr, internalState.cnt .. " OK") or 
		    string.match(newstr, internalState.cnt .. " NO") or 
			string.match(newstr, internalState.cnt .. " BAD")) then
	      done = true
	    end
	    if (str ~= nil) then
	      str = str .. "\n" .. newstr
	    else
	      str = newstr
	    end
	  end
    end
  end
  
  if f then
	return POPSERVER_ERR_OK, ""
  else
	return POPSERVER_ERR_OK, str
  end
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
  local uidl = get_mailmessage_uidl(pstate, msg)
  local msgid = internalState.msgids[uidl]

  -- Debug Message
  --
  log.dbg("Getting message: " .. uidl)

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
	
	-- data
	--
	dataptr = data,
	
	-- uidl
	--
	uidlptr = uidl
  }
	
  internalState.cbInfo = cbInfo
  
  local f = function(line)
    if (string.match(line, "OK FETCH completed") or string.match(line, "^%)$") 
      or string.match(line, " FETCH %(")) then
      return POPSERVER_ERR_OK
    end
  
    local cbInfo = internalState.cbInfo
	if (line == "") then
      line = "X-FREEPOPS-UIDL: " .. cbInfo.uidlptr .. "\r\n"
	end
    line = cbInfo.strHack:dothack(line) .. "\r\n\0"
    popserver_callback(line, cbInfo.dataptr)
    return POPSERVER_ERR_OK
  end
  local cmd = " BODY[HEADER]"
  if (internalState.bKeepMsgStatus) then
    cmd = " BODY.PEEK[HEADER]"
  end
  local rc, _ = sendCmd("fetch " .. msgid .. cmd, f)

  local f = function(line)
    if (string.match(line, "OK FETCH completed") or string.match(line, "^%)$") 
      or string.match(line, " FETCH %(")) then
      return POPSERVER_ERR_OK
    end
 
    local cbInfo = internalState.cbInfo
      cbInfo.nLinesReceived = cbInfo.nLinesReceived + 1
    line = cbInfo.strHack:dothack(line) .. "\r\n\0"
    if (cbInfo.nLinesReceived <= cbInfo.nLinesRequested or cbInfo.nLinesRequested < 0) then
      popserver_callback(line, cbInfo.dataptr)
	end
    return POPSERVER_ERR_OK
  end
  cmd = " BODY[TEXT]"
  if (internalState.bKeepMsgStatus) then
    cmd = " BODY.PEEK[TEXT]"
  end
  if (nLines ~= 0) then
    local rc, _ = sendCmd("fetch " .. msgid .. cmd, f)
  end
  
  internalState.cbInfo = nil
  return POPSERVER_ERR_OK

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

  internalState.strUser = user

  -- Override the domain variable if it is set in the login parameter
  --
  local val = (freepops.MODULE_ARGS or {}).domain or nil
  if val ~= nil then
    log.dbg("Fastmail: Using overridden domain: " .. val)
    internalState.strDomain = val
  else
    internalState.strDomain = domain
  end

  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder or globals.strInbox
  mbox = string.gsub(mbox, " ", "+") 
  internalState.strMBox = mbox

  -- Get the view to use in STAT (ALL, UNREAD or FLAG)
  --
  local strView = (freepops.MODULE_ARGS or {}).view or "All"
  local str = string.match(strView, globals.strViewAllPat)
  if str ~= nil then
    internalState.strView = globals.strViewAll
  else
    str = string.match(strView, globals.strViewUnreadPat)
    if str ~= nil then
      internalState.strView = globals.strViewUnread
    else
      internalState.strView = globals.strViewFlagged
    end
  end
  
  -- If the flag keepmsgstatus=1 is set, then we won't touch the status of 
  -- messages that we pull.
  --
  val = (freepops.MODULE_ARGS or {}).keepmsgstatus or 0
  if val == "1" then
    log.dbg("Fastmail: All messages pulled will have its status left alone.")
    internalState.bKeepMsgStatus = true
  end

  return POPSERVER_ERR_OK
end

-- Perform login functionality
--
function pass(pstate, password)
  -- Store the password
  --
  internalState.strPassword = password
  return login()
end

-- Quit abruptly
--
function quit(pstate)
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
  local cnt = get_popstate_nummesg(pstate)

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      local uidl = get_mailmessage_uidl(pstate, i)
      local msgid = internalState.msgids[uidl]
	  -- Copy the message to the trash
	  --
      local rc, str = sendCmd("copy " .. msgid .. " " .. globals.strTrash, nil)
	  
	  if (string.match(str, "OK ")) then
	    -- Mark it as deleted
	    --
        local rc, str = sendCmd("store " .. msgid .. [[ +FLAGS \Deleted ]], nil)
	    log.dbg("Marking message: " .. uidl .. " as deleted")
	  else 
	    log.error_print("Delete operation failed.  Unknown trash folder name.")
	    return POPSERVER_ERR_UNKNOWN
	  end
    end
  end

  -- Logout
  --
  local rc, str = sendCmd("logout", nil)
  
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
  internalState.bStatDone = true
  
  -- Initialize the state
  --
  set_popstate_nummesg(pstate, 0)

  -- Select the folder
  --
  local rc, str = sendCmd("select " .. internalState.strMBox, nil)
  if (rc ~= POPSERVER_ERR_OK) then
	log.error_print("Error Received selecting folder: " .. str .. "\n")
	return POPSERVER_ERR_NETWORK 
  end

  local f = function(l)
    internalState.nTotMsgs = internalState.nTotMsgs + 1
    if (string.match(l, "\Deleted")) then
	  log.dbg("Found a deleted message.  Ignoring!")
	  return POPSERVER_ERR_OK
	end
	if (internalState.strView == globals.strViewUnread and 
	    string.match(l, globals.strViewUnread) ~= nil) then
	  return POPSERVER_ERR_OK
    end
	if (internalState.strView == globals.strViewFlagged and 
	    string.match(l, globals.strViewFlagged) == nil) then
	  return POPSERVER_ERR_OK
    end
	
	local nMsgs = internalState.nMsgs
	local size, uidl = string.match(l, "UID (%d+) RFC822.SIZE (%d+)")
	if (size ~= nil and uidl ~= nil) then
      nMsgs = nMsgs + 1
      log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size)
      set_popstate_nummesg(pstate, nMsgs)
      set_mailmessage_size(pstate, nMsgs, size)
      set_mailmessage_uidl(pstate, nMsgs, tostring(uidl))
	  internalState.msgids[uidl] = internalState.nTotMsgs
	end
	internalState.nMsgs = nMsgs
	return POPSERVER_ERR_OK
  end
  
  local rc, _ = sendCmd("fetch 1:* (flags uid RFC822.SIZE)", f)
    
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
	
  -- MIME Parser/Generator
  --
  require("mimer")

  -- Common module
  --
  require("common")

  -- Common module
  --
  require("psock")
  
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
