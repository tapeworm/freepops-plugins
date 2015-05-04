-- ************************************************************************** --
--  FreePOPs @ananzi.co.za webmail interface
--
--  $Id: skeleton.lua,v 1.12 2007/01/14 16:49:37 gareuselesinge Exp $
--
--  Released under the GNU/GPL license
--  Written by Francois Botha <igitur@gmail.com>
-- ************************************************************************** --

PLUGIN_VERSION = "1.0.0.0"
PLUGIN_NAME = "Ananzi"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = ""
PLUGIN_HOMEPAGE = ""
PLUGIN_AUTHORS_NAMES = {"Francois Botha"}
PLUGIN_AUTHORS_CONTACTS = {"igitur@gmail.com"}
PLUGIN_DOMAINS = {"@ananzi.co.za"}
PLUGIN_REGEXES = {"@..."}
URL = "http://www.freepops.org/download.php?contrib=plugin.lua"
PLUGIN_PARAMETERS = {
   {name="---name---",
   description={en="---desc-en---",it=="---desc-it---"}},
}
PLUGIN_DESCRIPTIONS = {
   it=[[---desc-it---]],
   en=[[---desc-en---]]
}


-- ************************************************************************** --
--  strings
-- ************************************************************************** --

-- this are the webmail-dependent strings
--
-- Some of them are incomplete, in the sense that are used as string.format()
-- (read sprintf) arguments, so their %s and %d are filled properly
--
-- C, E, G are postfix respectively to Captures (lua string pcre-style
-- expressions), mlex expressions, mlex get expressions.
--
local ananziStrings = {
   loginURI = "http://mail.ananzi.co.za/",
   loginPostData= "Username=%s&Password=%s",
   loginFail="(incorrect password or account name.)",
   loginSuccess = "(Redirecting to your Inbox)",
   sessionIdRX = "http://mail.ananzi.co.za/Session/(.*)/Hello.wssp?",
   
   inboxListURI = "http://mail.ananzi.co.za/Session/%s/Mailbox.wssp?Mailbox=INBOX",
   inboxListPostData = "Limit=1000",
   inboxSuccess = "Viewing messages in INBOX",
   messageCountRX = "(%d*) messages, (%d*) unread",
   messagesE = "<tr>.*<td>.*</td>.*<td>.*<input>.*</td>.*<td>.*<img>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*<td><td>.*</td>.*<td>.*<a>.*</a>.*</td>.*</tr>", --"<tr>.*<td>.*</td>.*<td>.*<input>.*</td>.*<td>.*<img>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*</tr>",
   messagesG = "<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>X<O>O<O>O<O>O<O><O>O<O>",
   
   sourceURI = "http://mail.ananzi.co.za/Session/%s/MessagePart/INBOX/%s-P.txt",
   headerURI = "http://mail.ananzi.co.za/Session/%s/MessagePart/INBOX/%s-H.txt",
   
   delete_url = "http://mail.ananzi.co.za/Session/%s/mailbox.wssp",
   delete_post = "FormCharset=ISO-8859-1&Mailbox=Inbox&Purge=Purge&MailboxName=select+folder%s&RedirectAddresses=&Limit=1000&Delete.x=10&Delete.y=3",
   delete_next = "&Msg=%s",
   
   temp = "false"
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized
-- and saved to remember the state.
internalState = {
   stat_done = false,
   login_done = false,
   popserver = nil,
   sessionID = nil,
   domain = nil,
   name = nil,
   password = nil,
   b = nil
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Checks if a message number is in range
--
function checkRange(pstate,msg)
   local n = get_popstate_nummesg(pstate)
   return msg >= 1 and msg <= n
end

--------------------------------------------------------------------------------
-- Serialize the internalState
--
-- serial. serialize is not enough powerfull to correcly serialize the
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the
-- serial module to know how to serialize this. so we call b:serialize
-- method by hand hacking a bit on names
--
function serializeState()
   internalState.stat_done = false;
   
   return serial.serialize("internalState",internalState) ..
   internalState.b:serialize("internalState.b")
end

--------------------------------------------------------------------------------
-- The key used to store session info
--
-- Ths key must be unique for all webmails, since the session pool is one
-- for all the webmails
--
function key()
   return (internalState.name or "")..
   (internalState.domain or "")..
   (internalState.password or "")
end

function ananziLogin()
   if internalState.loginDone then
      return POPSERVER_ERR_OK
   end
   
   -- build the uri
   local password = internalState.password
   local domain = internalState.domain
   local user = internalState.name
   local uri = ananziStrings.loginURI
   local post = string.format(ananziStrings.loginPostData, user, password)
   
   -- the browser must be preserved
   internalState.b = browser.new()
   
   local b = internalState.b
   
   --	b.curl:setopt(curl.OPT_VERBOSE,1)
   
   local extract_f = support.do_extract(internalState, "loginURL", ananziStrings.loginSuccess)
   local check_f = support.check_fail
   local retrieve_f = support.retry_n(3,support.do_post(internalState.b,uri,post))
   if not support.do_until(retrieve_f,check_f,extract_f) then
      log.error_print("Login failed\n")
      return POPSERVER_ERR_AUTH
   end
   
   if internalState.loginURL == nil then
      log.error_print("Unable to get '" .. loginSuccess .. "'")
      return POPSERVER_ERR_AUTH
   end
   
   local returnUrl = internalState.b:whathaveweread()
   
   -- search the session ID
   local _,_,id = string.find(returnUrl, ananziStrings.sessionIdRX)
   
   if id == nil then
      return POPSERVER_ERR_AUTH
   end
   internalState.sessionID = id
   
   -- save all the computed data
   internalState.loginDone = true
   
   -- log the creation of a session
   log.say("Session started for " .. internalState.name .. "@" ..
   internalState.domain .. "\n")
   
   return POPSERVER_ERR_OK
end


-- ************************************************************************** --
--  Ananzi functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
   
   -- extract and check domain
   local domain = freepops.get_domain(username)
   local name = freepops.get_name(username)
   
   -- save domain and name
   internalState.domain = domain
   internalState.name = name
   
   return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
   -- save the password
   internalState.password = password
   
   -- eventually load session
   local s = session.load_lock(key())
   
   -- check if loaded properly
   if s ~= nil then
      -- "\a" means locked
      if s == "\a" then
         log.say("Session for "..internalState.name..
         " is already locked\n")
         return POPSERVER_ERR_LOCKED
      end
      
      -- load the session
      local c,err = loadstring(s)
      if not c then
         log.error_print("Unable to load saved session: "..err)
         return ananziLogin()
      end
      
      -- exec the code loaded from the session tring
      c()
      
      log.say("Session loaded for " .. internalState.name .. "@" ..
      internalState.domain .. "\n")
      
      return POPSERVER_ERR_OK
   else
      -- call the login procedure
      return ananziLogin()
   end
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
   session.unlock(key())
   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
   -- we need the stat
   local st = stat(pstate)
   if st ~= POPSERVER_ERR_OK then return st end
   
   -- shorten names, not really important
   local session_id = internalState.sessionID
   local b = internalState.b
   
   --log.say("Session id=" .. session_id .. "\n")
   local uri = string.format(ananziStrings.delete_url, session_id)
   --log.say("delete url=" ..uri.."\n")
   
   -- here we need the stat, we build the uri and we check if we
   -- need to delete something
   local delete_something = false
   local deleted_messages = ""
   
   for i=1,get_popstate_nummesg(pstate) do
      if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
         deleted_messages = deleted_messages .. string.format(ananziStrings.delete_next, get_mailmessage_uidl(pstate,i))
         delete_something = true
      end
   end
   
   --log.say("Delete arguments = " ..  deleted_messages .. "\n")
   
   
   if delete_something then
      local post = string.format(ananziStrings.delete_post, deleted_messages)
      
      --log.say("Full post = " .. post .. "\n")
      -- Build the functions for do_until
      
      local extract_f = function(s) return true,nil end
      local check_f = support.check_fail
      local retrieve_f = support.retry_n(3,support.do_post(internalState.b,uri,post))
      if not support.do_until(retrieve_f,check_f,extract_f) then
         log.error_print("Unable to delete messages\n")
         return POPSERVER_ERR_UNKNOWN
      end
   end
   
   -- save fails if it is already saved
   --session.save(key(),serialize_state(),session.OVERWRITE)
   -- unlock is useless if it have just been saved, but if we save
   -- without overwriting the session must be unlocked manually
   -- since it would fail instead overwriting
   session.unlock(key())
   
   log.say("Session saved for " .. internalState.name .. "@" ..
   internalState.domain .. "(" ..
   internalState.sessionID .. ")\n")
   
   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
   -- check if already called
   if internalState.stat_done then
      return POPSERVER_ERR_OK
   end
   
   -- shorten names, not really important
   local b = internalState.b
   
   -- this string will contain the uri to get. it may be updated by
   -- the check_f function, see later
   local uri = string.format(ananziStrings.inboxListURI, internalState.sessionID)
   local data = ananziStrings.inboxListPostData
   
   local extract_f = support.do_extract(internalState, "returnText", ".*")
   local check_f = support.check_fail
   local retrieve_f = support.retry_n(3,support.do_post(internalState.b,uri,data))
   if not support.do_until(retrieve_f,check_f,extract_f) then
      log.error_print("Login failed\n")
      return POPSERVER_ERR_AUTH
   end
   
   if internalState.returnText == nil then
      log.error_print("Unable to get '" .. inboxSuccess .. "'")
      return POPSERVER_ERR_AUTH
   end
   
   local _, _, messageCount, unreadCount = string.find(internalState.returnText, ananziStrings.messageCountRX)
   
   log.say("Inbox claims " .. messageCount .. " messages and " .. unreadCount .. " unread\n")
   
   local x = mlex.match(internalState.returnText, ananziStrings.messagesE, ananziStrings.messagesG)

   --x:print()

   log.say("Regular expression parsed " .. x:count() .. " rows\n")
   set_popstate_nummesg(pstate,x:count())
   for i=1,x:count() do
      --log.say(i .. " " .. x:get(0, i-1) .. " " .. x:get(1, i-1).."\n")
      
      local _,_,uidl = string.find(x:get(0,i-1),"MSG=(%d+)")
      
      local _,_,size = string.find(x:get(1,i-1),"(%d+)")
      local _,_,size_mult_k = string.find(x:get(1,i-1),"([Kk][Bb]*)")
      local _,_,size_mult_m = string.find(x:get(1,i-1),"([Mm][Bb]*)")      

      if size_mult_k ~= nil then
         size = size * 1024
      end
      
      if size_mult_m ~= nil then
         size = size * 1024 * 1024
      end

      log.say("uidl="..uidl..", size="..size.."\n")      

      set_mailmessage_size(pstate,i,size)
      set_mailmessage_uidl(pstate,i,uidl)
   end
   
   internalState.stat_done = true
   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate,msg)
   return common.uidl(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
   return common.uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate,msg)
   return common.list(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Fill all messages size
function list_all(pstate)
   return common.list_all(pstate)
end
-- -------------------------------------------------------------------------- --
-- Unflag each message marked for deletion
function rset(pstate)
   return common.rset(pstate)
end
-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
function dele(pstate,msg)
   return common.dele(pstate,msg)
end
-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
   return common.noop(pstate)
end
-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata)
   -- we need the stat
   local st = stat(pstate)
   if st ~= POPSERVER_ERR_OK then return st end
   
   local uidl = get_mailmessage_uidl(pstate, msg)
   local b = internalState.b
   
   if lines == 0 then
      
      local uri = string.format(ananziStrings.headerURI, internalState.sessionID, uidl)
      -- the callback
      local cb = common.retr_cb(pdata)
      -- some local stuff
      
      -- tell the browser to pipe the uri using cb
      local f,rc = b:pipe_uri(uri,cb)
      if not f then
         log.error_print("Asking for "..uri.."\n")
         log.error_print(rc.."\n")
         return POPSERVER_ERR_NETWORK
      end
      return POPSERVER_ERR_OK
   else
      -- some local stuff
      local size = get_mailmessage_size(pstate,msg)
      
      local uri = string.format(ananziStrings.sourceURI, internalState.sessionID, uidl)
      
      return common.top(b,uri,key(),size,lines,pdata,false)
   end
end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
   -- we need the stat
   local st = stat(pstate)
   if st ~= POPSERVER_ERR_OK then return st end
   
   local uidl = get_mailmessage_uidl(pstate, msg)
   
   local uri = string.format(ananziStrings.sourceURI, internalState.sessionID, uidl)
   
   log.dbg("Retr URI = " .. uri .. "\n")
   
   -- the callback
   local cb = common.retr_cb(pdata)
   
   -- some local stuff
   local b = internalState.b
   
   -- tell the browser to pipe the uri using cb
   log.dbg("Starting pipe...\n")
   local f,rc = b:pipe_uri(uri,cb)
   if not f then
      log.error_print("Asking for "..uri.."\n")
      log.error_print(rc.."\n")
      return POPSERVER_ERR_NETWORK
   end
   return POPSERVER_ERR_OK
end

--------------------------------------------------------------------------------

function init(pstate)
   freepops.export(pop3server)
   
   log.dbg("FreePOPs plugin '"..
   PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")
   
   -- the serialization module
   require("serial")
   
   -- the browser module
   require("browser")
   
   -- the MIME mail generator module
   require("mimer")
   
   -- the common implementation module
   require("common")
   
   -- checks on globals
   freepops.set_sanity_checks()
   
   return POPSERVER_ERR_OK
end
