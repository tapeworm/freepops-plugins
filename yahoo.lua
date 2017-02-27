-- ************************************************************************** --
--  FreePOPs @yahoo webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russell822@yahoo.com>
-- ************************************************************************** --

--require("base.util")

-- Globals
--
PLUGIN_VERSION = "0.4.20110625"
PLUGIN_NAME = "yahoo.lua"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=yahoo.lua"
PLUGIN_HOMEPAGE = "http://freepops.sourceforge.net/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager", "Kevin Edwards"}
PLUGIN_AUTHORS_CONTACTS = {"russell822 (at) yahoo (.) com", "ingenuus (at) users (.) sf (.) net"}
PLUGIN_DOMAINS = {"@yahoo.com"}
PLUGIN_PARAMETERS = {
    {name = "folder", description = {
        it = [[
Viene usato per scegliere la cartella (Inbox &egrave; il 
default) con cui volete interagire. Le cartelle disponibili sono quelle 
standard di Yahoo, chiamate 
Inbox, Draft, Sent, Bulk e 
Trash (per domini yahoo.it potete usare gli stessi nomi per oppure 
quelli corrispondenti in Italiano: InArrivo, Bozza, 
Inviati, Anti-spam, Cestino). Se avete creato delle 
cartelle potete usarle con i loro nomi.]],
        en = [[
Parameter is used to select the folder (Inbox is the default)
that you wish to access. The folders that are available are the standard 
Yahoo folders, called 
Inbox, Draft, Sent, Bulk and 
Trash (for yahoo.it domains you may use the same folder names or the 
corresponding names in Italian: InArrivo, Bozza, 
Inviati,Anti-spam, Cestino). For user defined folders, use their name as the value.]]
        }   
    },
    {name = "view", description = {
        it = [[ Viene usato per determinare la lista di messaggi da scaricare. I valori possibili sono All (tutti), Unread (non letti) e Flag.]],
        en = [[ Parameter is used when getting the list of messages to 
pull.  It determines what messages to be pulled.  Possible values are All, Unread and Flag.]]
        }
    },
    {name = "emptytrash", description = {
        it = [[ Viene usato per forzare il plugin a svuotare il cestino quando ha finito di scaricare i messaggi. Se il valore &egrave; 1 questo comportamento viene attivato.]],
        en = [[
Parameter is used to force the plugin to empty the trash folder when it is done
pulling messages.  Set the value to 1.]]
        }   
    },
    {name = "emptybulk", description = {
        it = [[ Viene usato per forzare il plugin a svuotare la cartella AntiSpam quando ha finito di scaricare i messaggi. Se il valore &egrave; 1 questo comportamento viene attivato.]],
        en = [[
Parameter is used to force the plugin to empty the bulk folder when it is done
pulling messages.  Set the value to 1.]]
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
    it=[[
Questo plugin vi per mette di leggere le mail che avete in una 
mailbox con dominio come @yahoo.com, @yahoo.ca o @yahoo.it.
Per usare questo plugin dovete usare il vostro indirizzo email completo come
user name e la vostra password reale come password.]],
    en=[[
This is the webmail support for @yahoo.com, @yahoo.ca and @yahoo.it and similar mailboxes. 
To use this plugin you have to use your full email address as the user 
name and your real password as the password.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  host = 'imap.mail.yahoo.com',
  port = 143,

  strInbox = "INBOX",
  strTrash = "Trash",

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

-- *** Replacement for psock.lua that returns actual line length of recv
--     Required because yahoo doesn't always include CR at end of line
--     and decoding IMAP requires an exact count.

function connect(host, port, verbose)
	local handler = socket.tcp()
	local rc, err = handler:connect(host,port)
	if rc ~= 1 then 
		log.error_print(err) 
		return nil, err
	end
	return {handler = handler,
		send = function(self,s)
			local msg = s..'\r\n'
			if verbose then log.dbg('SEND: '..msg) end
			local len = string.len(msg)
			local i,err,j=1,nil,1
			repeat 
				j, err = self.handler:send(msg,i)
				if j then i=i+j end
			until (j == nil or i > len)
			if not j then return -1 else return len end
		end,
		recv = function(self)
			local llength = 0;
			local line = '';
			repeat
				local data = self.handler:receive(1)
				if data == nil then 
					line = nil
					llength = 0
					break
				end
				llength = llength + 1
				if data:byte(1) == 10 then
					break
				elseif data:byte(1) ~= 13 then
					line = line .. data
				end
			until ( false );		

			if verbose then 
				log.dbg('RECV: '..(data or 'nil')..'\r\n') 
			end
			return line, llength
		end}
end


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

  -- let's connect -- use local version of connect
  --
  internalState.socket = connect(globals.host, globals.port, false)
  if not internalState.socket then
    log.error_print("Yahoo: Connection failed!")
    return POPSERVER_ERR_NETWORK
  end
    
  local str = nil
  str = internalState.socket:recv()
  log.dbg("   rcvd: "..tostring(str))
  -- * OK IMAP4rev1 server ready (3.6.11)
  --- OR ---
  -- * OK [CAPABILITY IMAP4rev1 ID NAMESPACE X-ACL-ID AUTH=PLAIN AUTH=LOGIN AUTH=XYMCOOKIE AUTH=XYMECOOKIE AUTH=XYMCOOKIEB64 AUTH=XYMPKI STARTTLS] IMAP4rev1 ymail_nginx-0.7.65_8 imap161.mail.ne1.yahoo.com
--  if str:match("ymail_nginx") then
--    log.error_print("New style server for " .. username)
--    log.error_print(str)
--  end
  if not str or string.match(str, "^[%s%*%+]+OK") == nil then
    log.error_print("Error receiving the welcome")
    log.error_print(str)
    return POPSERVER_ERR_NETWORK
  end

  local rc, str = sendCmd('id ("GUID" "1")', nil)
  -- * ID ("name" "imapgate" "support-url" "http://help.yahoo.com/" "version" "3.6.11")
  -- 1001 OK ID completed
  --- OR ---
  -- * ID ("name" "ymail_nginx" "version" "0.7.65_8" "support-url" "http://help.yahoo.com/")
  -- 1001 OK completed
  if (rc ~= POPSERVER_ERR_OK or
      string.match(str, internalState.cnt .. " OK") == nil) then
    log.error_print("Unable to initialize server")
    log.error_print(str)
    return POPSERVER_ERR_NETWORK
  end
  
  rc, str = sendCmd("login " .. username .. "@" .. domain .. " " .. password, nil)
  -- 1002 OK LOGIN completed
  if (rc ~= POPSERVER_ERR_OK or
      string.match(str, internalState.cnt .. " OK") == nil) then
    log.error_print("Login failed")
    log.error_print(str)
    return POPSERVER_ERR_AUTH
  end

---- 20091212 (Kevin) Yahoo has become very finicky and will not allow us to
----  store flags if we examine the folder before selecting it.  It's like
----  Yahoo gets stuck in examine's read-only state.
--  rc, str = sendCmd("examine " .. internalState.strMBox, nil)
--  if (rc ~= POPSERVER_ERR_OK or string.match(str, "NO EXAMINE failure") ~= nil) then
--    log.error_print("Folder: " .. internalState.strMBox .. " is invalid.")
--    return POPSERVER_ERR_AUTH
--  end
  
  -- Return Success
  --
  return POPSERVER_ERR_OK
end

function sendCmd(cmd, f)
  internalState.cnt = internalState.cnt + 1
  cmd = internalState.cnt .. " " .. cmd

  -- don't show the password when debug logging
  -- if we could test for debug mode, this could be in an "if" block
  local logLine = cmd
  local username = internalState.strUser
  local domain = internalState.strDomain
  local loginCmd = "login " .. username .. "@" .. domain .. " "
  if string.match(cmd, loginCmd) then
    logLine = loginCmd .. "PASSWORD"
  end
  
  log.dbg("sendCmd: "..logLine)

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
    local newstr, llength = internalState.socket:recv()
    log.dbg("   rcvd: "..tostring(newstr))
    if f then 
      f(newstr, llength)
      if (string.match(newstr, internalState.cnt .. " OK") or 
          string.match(newstr, internalState.cnt .. " BAD")) then
        done = true
      end
    else
      if (newstr == nil) then
        str = "-ERR network error"
        done = true
      end
    
      if (done == false) then
        if (string.match(newstr, internalState.cnt .. " OK") or 
            string.match(newstr, internalState.cnt .. " BAD") or
            string.match(newstr, internalState.cnt .. " NO")) then
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


-- sends a line to the popserver_callback
function send_line(cbInfo, line)
  cbInfo.nLinesReceived = cbInfo.nLinesReceived + 1
--  log.dbg("dothack before: " .. line:len())
--  log.dbg(line)

--  line = line:gsub("^%.$", "..")
  -- faster:
  if line == "." then
    line = ".."
  end
  
  line = cbInfo.strHack:dothack(line) .. "\r\n\0"
  
--  log.dbg("dothack after: " .. line:len())
--  log.dbg(line)
--  line = cbInfo.strHack:dothack(line) .. "\r\n\0"
  if (cbInfo.nLinesReceived <= cbInfo.nLinesRequested or
      cbInfo.nLinesRequested < 0) then
    popserver_callback(line, cbInfo.dataptr)
  end
end

-- tracks the imap state for lines received from imap.
function imap_fetch_rcv(cbInfo, line, llength)
  if cbInfo.strState == "prefix" then
    cbInfo.nBytesReceived = 0
    cbInfo.nLinesReceived = 0
    -- get the size of the data to receive
    cbInfo.nBytes = tonumber( string.match(line, "{(%d+)}") )
    log.dbg("imap_fetch_rcv bytes to receive: " .. cbInfo.nBytes)
    if cbInfo.nBytes == nil then
      log.error_print("imap_fetch_rcv bad prefix received in " .. cbInfo.strName)
      log.error_print(line)
    end
    cbInfo.strState = "data"
    -- do not pass the line on to client.
  
  elseif cbInfo.strState == "data" then
    cbInfo.nBytesReceived = cbInfo.nBytesReceived + llength
    log.dbg("imap_fetch_rcv line_len: " .. llength)
    if cbInfo.nBytes <= cbInfo.nBytesReceived then
      log.dbg("imap_fetch_rcv received all bytes: " .. cbInfo.nBytesReceived)
      cbInfo.strState = "postfix"
    end
    -- pass the line on to client.
    return true
  
  elseif cbInfo.strState == "postfix" then
    -- 1004 OK FETCH completed
    if (not string.match(line, internalState.cnt .. " OK") and
        not string.match(line, "%* ") and
	-- Removed $ in pattern because there is no \n in line.
        not string.match(line, "^%)") ) then
      log.error_print("imap_fetch_rcv unknown postfix received in " .. cbInfo.strName)
      log.error_print(line)
    end
    -- do not pass the line on to client.
    
  else
    log.error_print(
      "imap_fetch_rcv BAD STATE!:" .. cbInfo.strName .. ", " .. cbInfo.strState
    )
    log.error_print(line)
  end

  return false
end

-- tracks the imap state for lines received from imap.
function new_cbInfo(name, nLines, data, uidl)
  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- String hacker
    strHack = stringhack.new(),

    -- Number of total bytes (octets) to receive from IMAP.
    nBytes = 0,
    
    -- Number of bytes received from IMAP so far.
    nBytesReceived = 0,
    
    -- IMAP receive state.
    strState = "prefix",

    -- Name of current task.
    strName = name,
    
    -- Lines requested (-2 means not limited)
    nLinesRequested = nLines,

    -- Lines Received - Not really used for anything
    nLinesReceived = 0,
    
    -- data
    dataptr = data,
    
    -- uidl
    uidlptr = uidl
  }
  
  return cbInfo
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

  -- fetch the header
  local cmd = " BODY[HEADER]"
  if (internalState.bKeepMsgStatus) then
    cmd = " BODY.PEEK[HEADER]"
  end
  -- -2 == get all header lines
  internalState.cbInfo = new_cbInfo(cmd, -2, data, uidl)
  local f = function (line, llength)
    local cbInfo = internalState.cbInfo
    if imap_fetch_rcv(cbInfo, line, llength) then
      -- append FREEPOPS header field at the end (marked by the empty line)
      if llength == 2 then
        -- there's already an implicit \r\n that will be sent, but we add
        -- another one here to also send the empty line we are replacing.
        line = "X-FREEPOPS-UIDL: " .. cbInfo.uidlptr .. "\r\n"
      end
      send_line(cbInfo, line)
    end
    return POPSERVER_ERR_OK
  end
  local rc, _ = sendCmd("fetch " .. msgid .. cmd, f)

  -- fetch the body
  cmd = " BODY[TEXT]"
  if (internalState.bKeepMsgStatus) then
    cmd = " BODY.PEEK[TEXT]"
  end
  internalState.cbInfo = new_cbInfo(cmd, nLines, data, uidl)
  local f = function (line, llength)
    local cbInfo = internalState.cbInfo
    if imap_fetch_rcv(cbInfo, line, llength) then
      send_line(cbInfo, line)
    end
    return POPSERVER_ERR_OK
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
    log.dbg("Yahoo: Using overridden domain: " .. val)
    internalState.strDomain = val
  else
    internalState.strDomain = domain
  end

  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder or globals.strInbox
  mbox = string.gsub(mbox, "+", " ") 
  if (string.match(mbox, " ")) then
    mbox = '"' .. mbox .. '"'
  end
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
    log.dbg("Yahoo: All messages pulled will have its status left alone.")
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
        log.dbg("Marking message: " .. uidl .. " as deleted")

---- 20091212 (Kevin) Yahoo has become very finicky and will not allow
----  whitespace at the end of a command.
        local rc, str = sendCmd("store " .. msgid .. [[ +FLAGS (\Deleted)]], nil)
        
      else 
        log.error_print("Delete operation failed.  Unknown trash folder name.")
        return POPSERVER_ERR_UNKNOWN
      end
    end
  end

  -- CLOSE - this also EXPUNGEs the emails marked as \Deleted
  local rc, str = sendCmd("close", nil)
  
  -- LOGOUT
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

  -- Test for response "* 0 EXISTS"
---- alternative solution if we wanted to extract nMsgs:
--  local nMsgs = tonumber( string.match(str, "%* (%d+) EXISTS") )
--  if (nMsgs == 0) then
  if (string.match(str, "%* 0 EXISTS")) then
    log.dbg("stat: 'select' response indicates no messages available.")
    internalState.nMsgs = 0
    return POPSERVER_ERR_OK
  end
  
  local f = function(l)
    internalState.nTotMsgs = internalState.nTotMsgs + 1
    if (string.match(l, [[\Deleted]])) then
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
    local size = string.match(l, "RFC822.SIZE (%d+)")
    local uidl = string.match(l, "UID (%d+)")
    if (size ~= nil and uidl ~= nil) then
      nMsgs = nMsgs + 1
      log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size)
      set_popstate_nummesg(pstate, nMsgs)
      set_mailmessage_size(pstate, nMsgs, size)
      set_mailmessage_uidl(pstate, nMsgs, tostring(uidl))
      internalState.msgids[uidl] = internalState.nTotMsgs
--    else
--      log.dbg("FAILED to match RFC822.SIZE ("..tostring(size)..") or UID ("..tostring(uidl)..") in: " .. tostring(l))
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

  -- Common module (Not used due to line length issues)
  --
  --  require("psock")
  
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
