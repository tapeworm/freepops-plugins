-- ************************************************************************** --
--  FreePOPs @mailinator.com webmail interface
-- 
--  $Id: mailinator.lua,v 1.0.3 2014/04/02 00:00:00 dmatyukhin Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Dmitry Matyukhin <nskmda@aol.com>
-- ************************************************************************** --
PLUGIN_VERSION = "1.0.3"
PLUGIN_NAME = "Mailinator.com Web-mail"
PLUGIN_REQUIRE_VERSION = "0.2.9"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=mailinator.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org"
PLUGIN_AUTHORS_NAMES = {"Dmitry Matyukhin"}
PLUGIN_AUTHORS_CONTACTS = {"nskmda@aol.com"}
PLUGIN_DOMAINS = {"@mailinator.com",
"@PutThisInYourSpamDatabase.com",
"@ThisIsNotMyRealEmail.com",
"@binkmail.com",
"@SpamHerePlease.com",
"@SpamHereLots.com",
"@SendSpamHere.com",
"@chogmail.com",
"@SpamThisPlease.com",
"@frapmail.com",
"@obobbo.com",
"@devnullmail.com"}

PLUGIN_REGEXES = {"@..."}
-- No parameters expected 
PLUGIN_PARAMETERS = { }
PLUGIN_DESCRIPTIONS = {
  en=[[This is a POP3 plugin for the Mailinator.com web-site. 
The site provides service to have a non-registered email box. Then you can user that email to receive ocassional emails (like registration confirmation somewhere).
All the emails get accumulated in your email box which can be accessed via http://<username>.mailinator.com. The emails are only kept for a few hours. 
That's why it makes sense to have a plugin to check that email box.

The plugin may be installed without registration in the main FreePops configuration file by placing it in the /lua_unofficial folder.

The plugin needs dkjson.lua module to be added to the FreePOPs installation. The dkjson.lua may be obtained from http://dkolf.de/src/dkjson-lua.fsl.
The dkjson.lua needs to be put into the /lua folder of your FreePOPs installation (along with freepops.lua)
]]
}

mailinator_globals = {username=""}
mailinator_messages_list = {}
mailinator_messages_map = {}

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

  log.dbg("Interpreter version: " .. _VERSION)

  -- the serialization module
  --require("serial")
  --  return POPSERVER_ERR_UNKNOWN 
  --end 

  -- the browser module
  require("browser")
  require("common")
  require("os")
  
  json = require("dkjson")
  
  log.dbg("JSON imported")
  
  -- checks on globals
  freepops.set_sanity_checks()
    
  return POPSERVER_ERR_OK
end


-- Must save the mailbox name
function user(pstate,username)
  logDebugMessage("In user")
  mailinator_globals.username = freepops.get_name(username)
  logDebugMessage("Login user name =[".. mailinator_globals.username .."]")
  return POPSERVER_ERR_OK
end


function pass(pstate,password)
  logDebugMessage("Password  is not needed")
  return POPSERVER_ERR_OK
end

-- Must quit without updating
function quit(pstate)
  logDebugMessage("In quit")
  return POPSERVER_ERR_OK
end

-- Fill msg size
function list(pstate,msg)
  logDebugMessage("In list")
  return common.list(pstate,msg)
end

-- Fill all messages size
function list_all(pstate)
  logDebugMessage("In list_all")
  return common.list_all(pstate)
end

-- Fill msg uidl field
function uidl(pstate,msg)
  logDebugMessage("In uidl")
  return common.uidl(pstate,msg)
end

-- Fill all messages uidl field
function uidl_all(pstate)
  logDebugMessage("In uidl_all")
  return common.uidl_all(pstate)
end

-- Fill the number of messages and their size
function stat(pstate)
  logDebugMessage("In stat")
  -- As per manual - avoiding duplicate calls
  if mailinator_globals.stat_done == true then
    logDebugMessage("stat is done already. Returning OK")
    return POPSERVER_ERR_OK
  end

  logDebugMessage("Creating browser object to load messages")
  mailinator_globals.browser = browser.new()
  
  logDebugMessage("Setting up URI to load mailbox access token...")
  local msg_token_uri = "http://www.mailinator.com/settt?box="..mailinator_globals.username

  logDebugMessage("Messages token URI=[".. msg_token_uri .."]")

  local tokenRegexp = "\"address\":[^\\\"]*\"([^\\\"]*)"
  local msg_token_data = mailinator_globals.browser:get_uri(msg_token_uri)

  logDebugMessage("Token data:\n"..msg_token_data)

  local token = string.match(msg_token_data, tokenRegexp)
  logDebugMessage("Token extracted:["..token.."]")

  logDebugMessage("Setting up URI to load messages list...")
  local msg_list_uri = "http://www.mailinator.com/grab?inbox="..mailinator_globals.username.."&address="..token
  logDebugMessage("Messages list URI=[".. msg_list_uri .."]")
  
  local pageData, err
  pageData, err = mailinator_globals.browser:get_uri(msg_list_uri)
  logDebugMessage("Html page data:\n"..pageData)
  logDebugMessage("Html page data size:"..#pageData)

 
  -- Now look up separate messages in the list
  local obj, pos, err = json.decode (pageData)
  --logDebugMessage("JSON parsed to object "..obj)
  if err ~= nil then
    logDebugMessage("JSON not parsed")
	return POPSERVER_ERROR_UNKNOWN
  end
  

  local messagesCount = 0 --#obj.maildir
  -- TODO: verify 'session' statelessness between mailbox checks

  mailinator_globals.messages_list = {}
  mailinator_globals.messages_map = {}
--[[

{"maildir":[
 {"seconds_ago":13572,
"id":"1396433286-5266299-nskmda",
"to":"nskmda@mailinator.com",
"time":1396433286169,
"subject":"Bring in Spring with New Items from P&G and The Home Depot!",
"fromfull":"PGeveryday@email.pgeveryday.com",
"snippet":"If you are having trouble viewing the images ",
"been_read":false,
"from":"P&G everyday",
"ip":"208.70.142.77"},
]]
    logDebugMessage("Messages found. Iterating...")
    for key, msg in pairs(obj.maildir) do
      local message = { }
      message.uidl = msg.id
      message.from = msg.fromfull
      message.subject = msg.subject
      message.sendDate = msg.time/1000
      message.to = msg.to
      logDebugMessage("Next message: "..message.uidl.."-"..message.from.."-"..message.subject)
      messagesCount = messagesCount + 1
      mailinator_globals.messages_list[messagesCount] = message
      mailinator_globals.messages_map[message.uidl] = message
    end

	logDebugMessage("Total messages: "..messagesCount.."="..#mailinator_globals.messages_list)
  set_popstate_nummesg(pstate, messagesCount)
  for idx, message in ipairs(mailinator_globals.messages_list) do
    -- no size available immediately, set to 1Kb
    logDebugMessage("Setting size of "..idx.." message uidl "..message.uidl.." to 1024")
    set_mailmessage_size(pstate, idx, 1024) 
    set_mailmessage_uidl(pstate, idx, message.uidl) 
  end

  
  -- As per the manual - avoiding duplicate calls (see check in the beginning of the method)
  mailinator_globals.stat_done = true
  
  return POPSERVER_ERR_OK
end

-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
  logDebugMessage("In retr")
  -- we need the stat
  local st = stat(pstate)
  if st ~= POPSERVER_ERR_OK then return st end

  local uidl = get_mailmessage_uidl(pstate,msg)
  logDebugMessage("Composing data for uidl="..uidl)

  popserver_callback(getMessageText(uidl, true), pdata)

  logDebugMessage("Message retrieved")
  return POPSERVER_ERR_OK
end


function getMessageText(uidl, terminate)
  terminate = terminate or false
  local msg_data = "Date: "..os.date("%a, %d %b %Y %X",mailinator_globals.messages_map[uidl].sendDate).."Z \r\n"
  logDebugMessage("Formatted date="..msg_data)
  msg_data = msg_data.."From: "..mailinator_globals.messages_map[uidl].from.."\r\n"
  msg_data = msg_data.."Sender: "..mailinator_globals.messages_map[uidl].from.."\r\n"
  msg_data = msg_data.."To: "..mailinator_globals.messages_map[uidl].to.."\r\n"
  msg_data = msg_data.."Subject: "..mailinator_globals.messages_map[uidl].subject.."\r\n"
  msg_data = msg_data.."Message-ID: <"..uidl..">\r\n"
  msg_data = msg_data.."Content-Type: text/plain;charset=UTF-8\r\n"
  msg_data = msg_data.."MIME-Version: 1.0\r\n"
  msg_data = msg_data.." \r\n"
  msg_data = msg_data.."Go to www.mailinator.com\r\n"
  if terminate then
    msg_data = msg_data.."."  
  end
  return msg_data
end

-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata,truncate)
  --logDebugMessage("In top pstate="..pstate.." msg="..msg.." lines="..lines.." pdata="..pdata.." truncate="..truncate)

  local st = stat(pstate)
  if st ~= POPSERVER_ERR_OK then return st end

  local uidl = get_mailmessage_uidl(pstate,msg)

  logDebugMessage("uild="..uidl)
  popserver_callback(getMessageText(uidl), pdata)

  return POPSERVER_ERR_OK
end

-- Unflag each message marked for deletion
function rset(pstate)
  logDebugMessage("In rset")
  return common.rset(pstate)
end

-- Do nothing
function noop(pstate)
  logDebugMessage("In noop")
  return common.noop(pstate)
end

-- Mark msg for deletion
function dele(pstate,msg)
  logDebugMessage("In dele")
  return common.dele(pstate,msg)
end

-- Update the mailbox status (potentially delete marked messages here) and quit
function quit_update(pstate)
  logDebugMessage("In quit_update")
  local st = stat(pstate)
  if st ~= POPSERVER_ERR_OK then return st end
  
  local delete_cb = function(s, len)
    return len, nil
  end

  -- TODO: implement messages deletion
  for i=1,get_popstate_nummesg(pstate) do
    if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
      local uri = "http://www.mailinator.com/api/expunge?lastviewed="..mailinator_globals.messages_list[i].uidl
      logDebugMessage("Deleting message at "..uri)
      mailinator_globals.browser:pipe_uri(uri, delete_cb)
  -- delete message here
    end
  end
  
  return POPSERVER_ERR_OK
end

function logDebugMessage(message)
  log.dbg("-----------------------------------------------")
  log.dbg(message)
  log.dbg("-----------------------------------------------")
end


-- EOF
-- ************************************************************************** --