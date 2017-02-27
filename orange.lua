-- ************************************************************************** --
--  FreePOPs @fsmail.net webmail interface
--  
--  Released under the GNU/GPL license
--  Written by TheMarco <themarco (at) fsmail (.) net>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.0.8g"
PLUGIN_NAME = "Orange (ex Wanadoo)"
PLUGIN_REQUIRE_VERSION = "0.0.99"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=orange.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/en/viewplugins.php"
PLUGIN_AUTHORS_NAMES = {"TheMarco","Ernst Vaarties"}
PLUGIN_AUTHORS_CONTACTS = {"themarco (at) fsmail (.) net","evaarties (at) xs4all (.) nl"}

-- Four initial domains. 1  for .co.uk and 3 for .nl 
-- if more domains & countries are added, the code in  
-- function user(pstate, username) needs to be updated accordingly
--
PLUGIN_DOMAINS = {"@fsmail.net","@wanadoo.nl","@orange.nl","@bedrijfsnaam.nl"}
PLUGIN_PARAMETERS = {
	{name="folder", description={
		it=[[La cartella da ispezionare. Quella di default &egrave; inbox, gli altri valori possibili sono: junk, sent, trash, draft o cartella definita dall'utente.]],
		en=[[The folder to interact with. Default is inbox, other values are: junk, sent, trash, draft or user defined folder.]]}
	},
	{name = "emptytrash", description = {
		it =[[Non raccomandato. Forza il plugin a svuotare il cestino quando ha finito di scaricare i messaggi. Attivato dal valore 1.]],
		en =[[Not recommended. Forces the plugin to empty the trash when it is done pulling messages.  Set it to 1 to activate it.]]
		}	
	},

}

PLUGIN_DESCRIPTIONS = {
	it=[[Plugin per Orange webmail (ex Wanadoo ). Usate il vostro indirizzo email completo come 
nome utente e la vostra vera password come password. Per supporto, chiedete nel forum.]],
	en=[[Orange ( ex Wanadoo ) webmail plugin. Use your full email address as the username
and your real password as the password.  For support, please post your questions to the forum.]]
}

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Server URL
  --
  -- strLoginUrl = "http://email01.orange.co.uk/webmail/en_GB/login.html ",
  -- http://email01.orange.nl/webmail/nl_NL/

  strBaseUrl ="http://fsmail%s%d.orange.%s/webmail/%s/",
  strLogin = "connexion_submit.html",
  
  --strLoginGood = "http://email01.orange.co.uk/webmail/en_GB/inbox.html",

  -- Login strings
  --
  strLoginPostData = "LOGIN=%s&PASSWORD=%s&DOMAINE=%s&URL_REDIRECT_TO=connexion_submit.html&Email=%s&Password=%s&FLAG=E",
  strLoginFailed = "MESSAGE=AUTH_FAILED",

  strSessionExpired = '<div id="infoLoginMessage',

  -- Default mailboxes
  --
  strInbox = "inbox",
  strMBoxes = "inbox junk sent trash draft", -- the standard 'folder' options
  
  -- User mailboxes - example : folder.html?FOLDER=UF_mybox
  strUsrBox = "folder.html?FOLDER=UF_%s",
  strErrUsrBox = "MESSAGE=ERROR_IMAP",
  
  -- Used by Stat
  --
  strMsgLinePattern = [[<td.-class="mailTxt".-title=".-read.html','(.-)'.-</a>.-</a>.-false">(.-[MmKkBb])]],  
  strDraftLinePattern = [[<td.-class="mailTxt".-title=".-EditDraft%('(.-)'.-</a>.-</a>.-false">(.-[MmKkBb])]], 

  strNextPage="%s%sPAGE=%s",
  strNextPagePattern = [[&gt;&gt;.-goToPage%('(%d-)'.->&gt;|</a>]],
  
  -- Used by DownloadMsg
  --
  strHeaderPattern = '<td[^>]-%sclass%s-=%s-"mailHeader".->(.-)</td.->',
  strMsgBodyPattern = '<%s-div.-%sid%s-=%s-"message".->%s*(.-)%s*</div>.-</td>.-</tr>.-<tr>.-<td[^>]-%s-class%s-=%s-"col2">',

  -- two variables needed due to the way gsub handles "?" 
  strInlineBase = "download/Download.html",
  strInlinePattern = [[<.-%s[Ss][Rr][Cc]%s-=%s-"download/Download.html.(.-)".->]],
	  
  strAttachmentPattern = 'ADR_ATTACH.-</td>%s-<td.->(.-)</td>',
  strAttachmentUrlPattern = '%shref="(.-)"',
  strAttachmentName = "NAME=(.-)&",
  strMailAttachmentName = '%stitle="(.-)"',
  
  -- from wanadoo.lua - they seem to work! :)
  attachmentsearchexpression = ".*<img>.*<a>.*</a>.*",
  attachmentmatchexpression = "O<O>O<X>O<O>O",
    
  -- Used by Quit_Update
  -- 
  
  -- MESSAGE= specifies the string used as a section header on the feedback page... can use the CONFIRM_DELETE message for multiple mails
  -- CONFIRM_DELETE= specifies if we need to see a confirmation page in order to proceed (it's not the same CONFIRM_DELETE as above!)
  -- trash folder should autodelete after 7 days
  --
  strCmdDelete = "delete_submit.html",
  strCmdDeletePost =[[REDIRECT_REFRESH=%s&URL_VALID=delete_submit.html&CONFIRM_DELETE=false&PAGE=1&FOLDER=%s&MESSAGE=CONFIRM_DELETE&PARAM1=%s&uids=%s&REDIRECT_SUCCESS=%s&SAVE_INTO_TRASH=%d]],
  
  strLogout = "logout.html"

}

-- Orange Mimer - custom mimer with extensions for proper inline mime handling
-- all the other omimer definitions(Private and omimer) can be found after line 800
--
local omimer = {}

-- Orange specific constants
--
omimer.strImagePattern = "STREAM_TYPE=IMAGE"
--[[
omimer.strFwdHeaderPattern = '(<%s-div.-%sclass%s-=%s-"address".->.-<%s-/div.->)'
omimer.strFwdBodyPattern = '(<%s-div.-%sid%s-=%s-"message".->%s*.-%s*</div>).-</td>.-</tr>.-<tr>.-<td[^>]-%s-class%s-=%s-"col2">'
omimer.strFwdSkeleton = "<html><head><title>Forwarded Mail</title></head><body>" ..
	"<table width=100%%><tr><td>%s</td></tr><tr><td>"..
	"%s</td></tr></table></body></html>" 
]]
-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  bEmptyTrash = false,
  bUsrBox = false,
  strUser = nil,
  strPassword = nil,
  browser = nil,
  strDomain = nil,
  strGUID = nil, -- Remove
  strMBox = nil,
  strMBoxUrl=nil,
  strBaseCmd = nil,
  strBaseUrl = nil,
  lastMsg = 0,
  msgUrls = {},
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
  if not internalState.bLoginDone then
    
    -- Create a browser to do the dirty work
    --
    internalState.browser = browser.new()
    
	-- Enable SSL
	--
	internalState.browser:ssl_init_stuff()

    -- Define some local variables
    --
    local username = internalState.strUser .. "@" .. internalState.strDomain
    local password = curl.escape(internalState.strPassword)
    local domain = internalState.strDomain 
    local browser = internalState.browser
    
    -- DEBUG - Set the browser in verbose mode
    --
    --browser:verbose_mode()
    
    -- Create the post string
    --
    local post = string.format(globals.strLoginPostData, username, password, domain, username, password)
    
    -- Retrieve the login page.
    --
    log.dbg("Login Url: " .. internalState.strBaseUrl .. globals.strLogin .. "?" .. post .."\n")
    local body, err = browser:post_uri(internalState.strBaseUrl .. globals.strLogin, post)
	
    if body == nil then
      log.error_print("Login Failed: Unable to make connection\n")
      return POPSERVER_ERR_NETWORK
    end
    
	local url = string.match(body, '<p>The document has moved <a href="([^"]+)">')
	if (url ~= nil) then
      body, err = browser:get_uri(url)
	end
	
    local str = browser:whathaveweread() 
    log.dbg ("Login redirected to... " .. str)
    str = string.gsub(str, "/[^/]+$", "/")
    internalState.strBaseUrl = str
    log.dbg ("Server url stored as: " .. str)
    
    local failed = string.find(str,globals.strLoginFailed)
    if failed  then
     log.dbg("Server returned MESSAGE=AUTH_FAILED, login failed.")
     return POPSERVER_ERR_AUTH
    end
    
    -- Check for cookies - the browser object might not return cookies to the website otherwise
    --
    local cookie = browser:get_cookie('SessionStatId')
    cookie = cookie and browser:get_cookie('JSESSIONID')
    if not cookie then
      log.dbg("No session cookies, Orange login procedure has changed.")    -- no cookie found, login failed?
    end
    
    -- do we have a mailbox url already?
    if not internalState.strMBoxUrl then
	    -- make sure we are looking at a mailbox!
	    --
	    local n = string.find (globals.strMBoxes, internalState.strMBox)
	    if n ~= nil then -- a 'normal' mailbox (inbox,  junk, or sent) !  trash & draft  are beyond the scope of this initial release
	          internalState.strMBoxUrl = internalState.strMBox .. ".html"
	    else
	          --is this a user mailbox?
	          
	          str = string.format(globals.strUsrBox,internalState.strMBox)
	          log.dbg(internalState.strBaseUrl .. str)
	          body, err = browser:get_uri(internalState.strBaseUrl .. str)
	          n = string.find (browser:whathaveweread(),globals.strErrUsrBox)
	          if n then
		          -- error, redirect to the default mailbox
		          internalState.strMBox = globals.strInbox
		          internalState.strMBoxUrl = globals.strInbox .. ".html"
	          else
		          -- no error, we're looking at a user defined mailbox
		          internalState.bUsrBox = true
		          internalState.strMBoxUrl = str
	          end
	    end
    end
    
    
    body, err = browser:get_uri(internalState.strBaseUrl .. internalState.strMBoxUrl )
    if not body then  --no mailbox?, they must have changed their html...
          log.say("Orange module has encountered a problem immediately after login.\n")
          return nil, "Could not find mail folders.  Unable to recover"
    end
    
    log.dbg("Now viewing the following URL: " .. internalState.strBaseUrl  .. internalState.strMBoxUrl .. "\n")
    
    -- We have logged in successfully
    --
    internalState.bLoginDone = true
    log.dbg("Created session (ID: " .. hash() .. ", User: " .. 
	          internalState.strUser .. "@" .. internalState.strDomain .. ")\n");
    
  end
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

	local browser = internalState.browser  
	--log.dbg ("getting message" .. msg .."\n")
	local uidl = get_mailmessage_uidl(pstate, msg)
	local url = internalState.msgUrls[uidl];
	log.dbg("Getting message: " .. uidl .. ", URL: " .. url .. "\n")
	local f,rc = browser:get_uri(url)
  
	if not f then
		return POPSERVER_ERR_NETWORK
	end

	local _, _, header = string.find(f,globals.strHeaderPattern)
	local _, _, body = string.find(f,globals.strMsgBodyPattern)
	if not (header and body) then
		local err="header"
		if header then err="body" end
		log.say("Orange module may need updating, could not read email " .. err ..".\n")
        return POPSERVER_ERR_NETWORK
	end

	header = string.gsub(header, "<strong>", "\n") -- make it a hard return. Needed!
	-- clean up the 'html' characters from the header
	header = string.gsub(header, "<.->", "")
	header = string.gsub(header, "&quot;", '"')
	header = string.gsub(header, "&lt;", "<")
	header = string.gsub(header, "&gt;", ">")
	header = string.gsub(header, "&nbsp;", " ")
	header = string.gsub(header, "\r", "")
	--now remove the first return and add one at the end, to avoid parsing errors
	header=string.sub(header,2) .. "\n"
	header = string.gsub(header, "\n", "\r\n")
    -- log.dbg("Header: " .. tostring(header))
	
	-- if ctype == nil the default is "iso-8859-1"
	--
	local _,_,ctype = string.find(header,
		"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:"..
		"%s*[^;\r]+;%s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=\"?([^\"\r]*)")

	local isText, _ , strTextType = string.find (header, "[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:" .. 
		"%s*[Tt][Ee][Xx][Tt]/(.-)\r\n")
	

	-- base_uri needed when converting html mail to text 
	--
	-- local base_uri, txt =  internalState.strBaseUrl , nil 
	local base_uri = "http//" .. browser:wherearewe()
	local cb = omimer.callback_mangler(common.retr_cb(data))
	local attachments = {} --  array holding all the attachments (inline, forwarded emails or normal)
	local inline = {} -- array holding the inline elements
	local forwarded = {} --  array holding the forwarded emails
	
	local txt
	
	if isText then
		local isPlain = string.find (strTextType, "[Pp][Ll][Aa][Ii][Nn].-")
		--escape the carriage returns properly, don't add any hyperlink 
		if isPlain then
			txt=omimer.html2txtplain(body,base_uri)
			body = nil
		end
	else
		-- Check if it's multipart/related
		local isRelated = string.find(body, globals.strInlinePattern)
		if isRelated then
			log.dbg("Multipart/Related message...")
			local n,i,name = "pt00000",1
			--local newbody = body
			for url in string.gfind(body, globals.strInlinePattern) do
				name= n .. i 
				body = string.gsub (body, globals.strInlineBase .. "." .. url,"cid:" .. name)
				inline[name] = name
				 -- the gsub below escapes user defined folder name with spaces
				attachments[name] = internalState.strBaseUrl .. globals.strInlineBase .. "?" .. string.gsub(url,' ','+')
				--log.dbg(" Inline attachment url: " .. attachments[name])
				i=i+1
				table.setn(attachments,i)
				--log.dbg(name .. " ::" .. inline[name])
				table.setn(inline,i)
			end
		else --provide a plaintext alternative...	
			txt=omimer.html2txtplain(body,base_uri)
		end
		-- now remove the old content-type -- done inside mimer now
		--header = omimer.remove_lines_in_proper_mail_header(header,{"content%-type"})
	end
	--log.dbg ("istext " .. tostring(isText) .. " type: " .. tostring(strTextType) .. " body: " .. tostring (body))
	
	-- Now find the (other) attachments
	--
	local _,_, attachmentstring = string.find(f, globals.strAttachmentPattern)
	local nr_of_attachments = 0
	if attachmentstring ~= nil then
	    -- use mlex to put all attachments in a array if there are any
	    --log.dbg("The attachmentstring: " .. attachmentstring)
	    local result = mlex.match(attachmentstring, globals.attachmentsearchexpression, globals.attachmentmatchexpression)
	    if result:count() > 0 then
	      nr_of_attachments = result:count()
	      local attachmenturl,n
		  local j=1
		  for i=1, nr_of_attachments do		
	        -- grab just the url part
	        _, _, attachmenturl = string.find(result:get(0,i-1),globals.strAttachmentUrlPattern)
			-- complete the url with the domain
			attachmenturl =  internalState.strBaseUrl .. attachmenturl
			--get the name of the attached file
			_,_,n = string.find(attachmenturl, globals.strAttachmentName)
			if not n then -- it's a forwarded email
				_,_, n = string.find(result:get(0,i-1),globals.strMailAttachmentName)
				n= n .. ".html"
				--local nMsgs = internalState.lastMsg
				--nMsgs = nMsgs + 1
				--internalState.lastMsg = nMsgs
				--set_mailmessage_uidl(pstate, nMsgs, uidl..".00"..j)
				--log.dbg ( "set the mail message" )
				--forwarded[n] = downloadMsg(pstate, nMsgs, nLines, data)
				--log.dbg ( "forwarded " .. n .." - body: " .. tostring(forwarded[n]) )
				forwarded[n] = n
				attachmenturl = string.gsub (attachmenturl, "/read%.html","/pfRead.html")
				j=j+1
				table.setn(forwarded,j)
			end
	        
	        -- add the url to the attachment array
	        attachments[n] = attachmenturl
			table.setn(attachments,table.getn(attachments) + 1)
	        log.dbg("Attachment: " .. n .. " - URL : " .. attachmenturl)
	      end
	    end
	end
	log.dbg("This email has " .. nr_of_attachments .. " attachment(s) of which " .. table.getn(forwarded) .. " are forwarded.")
  
	-- done inside mimer now
	--if nr_of_attachments > 0 then
		-- make sure we don't have the old content-type 
		-- header = omimer.remove_lines_in_proper_mail_header(header, {"content%-type"})
	--end
	
	--log.dbg ("inline " .. tostring(inline))
	--log.dbg ("sending to mimer - txt " .. tostring(txt ~= nil) .. " body: " .. tostring(body ~=nil) )
	omimer.pipe_msg(header, txt, body,  base_uri, attachments, browser, cb, inline,ctype,forwarded)
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
  local country , language, leading
  
  if (domain =="fsmail.net") then
    leading="0"
  	country="co.uk"
	language="en_GB"
  else  --everything else is dutch! :)
    leading=""
  	country="nl"
	language="nl_NL"
  end
  
  -- copied from the javascript code on the orange webpage: assign server number randomly
  -- (os.time()%3)+1 -- ... 1 to 3
  internalState.strBaseUrl= string.format(globals.strBaseUrl, leading, math.fmod(os.time(),3)+1 , country, language)
  
  log.dbg ("Domain: " .. domain .. " Initial login uri: " .. internalState.strBaseUrl .. "\n")

  internalState.strDomain = domain
  internalState.strUser = user

  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder
  if mbox then
	internalState.strMBox = curl.escape(mbox)
  else
	internalState.strMBox = globals.strInbox
  end

  log.dbg ("user mailbox: " .. internalState.strMBox)
	
  local val = (freepops.MODULE_ARGS or {}).emptytrash or 0
  if val == "1" then
    log.dbg("Emails read will be queued for permanent deletion.\n")
    internalState.bEmptyTrash = true
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
  log.dbg("entered quit_update")
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
  local dcnt = 0
  local ids, post, boxName = "" -- ,nil ,nil
  
  --if false then -- debugging in progress! Don't delete anything!!!!
  if internalState.strMBox ~='trash' or internalState.bEmptyTrash then
	  -- Cycle through the messages and see if we need to delete any of them
	  -- 
	  for i = 1, cnt do
		
	    if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
	      local uidl = get_mailmessage_uidl(pstate, i)
	      local url = internalState.msgUrls[uidl];
	      local body,err = browser:get_uri(url);
		  local bName,uid
		  
		  if body then
			_, _, bName, uid = string.find (uidl,"(.-)&IDMSG=(.*)")
			-- If it's got forwarded emails as attachment (didn't process it properly) we don't delete it! 
			dcnt=dcnt+1
			boxName = boxName or bName
			ids = ids .. uid .. ","
			--log.dbg ("Cleanup phase - marking message for deletion - uidl: " .. uidl .. "\n")
	      else
	        --log.dbg ( "Cleanup phase - could not find message on server - uidl: " .. uidl .. " , URL" .. url.. "\n")
	      end
		  
	    end
	  end

	  if dcnt > 0 then
		local body
		local n=1
		if internalState.bEmptyTrash then
			n=0
		end
	  	post = string.format(globals.strCmdDeletePost, internalState.strMBoxUrl,boxName,dcnt,ids,internalState.strMBoxUrl,n)
		-- and now send deleted mail to the trash folder - orangemail clears it after 7 days of sending it there
		log.dbg("Deletion URL:\n\n" .. internalState.strBaseUrl .. globals.strCmdDelete .. "?" .. post .."\n")
		body = browser:post_uri(internalState.strBaseUrl .. globals.strCmdDelete, post)
		if not body then
			log.say("Message(s) deletion failed. The Orange plugin may need updating.\n")
		end
	  else
		if cnt > 0 then
			log.dbg ("Cleanup - none of the mail marked for deleting was found on the server!\n")
		end
	  end
  else
	log.dbg ("Cleanup -  trash folder -> trash folder = no action needed!")
  end
  
  -- Killing the session
  --
  log.dbg (internalState.strBaseUrl .. globals.strLogout)
  local body, err= browser:get_uri(internalState.strBaseUrl .. globals.strLogout)
  internalState.bLoginDone = false
  session.remove(hash())

  log.dbg("Logged out: " .. internalState.strUser ..  "@" .. internalState.strDomain .. "\n")

  return POPSERVER_ERR_OK
end

-- Stat command - Get the number of messages and their size
--
function stat(pstate)

  -- Have we done this already?  If so, we've saved the results
  --
  if internalState.bStatDone then
	--log.dbg ("Stat for account already fetched, succesfully looked up state.")
    return POPSERVER_ERR_OK
  end
	--log.dbg( "starting Stat")
  -- Local variables
  -- 
  local browser = internalState.browser
  local nMsgs = 0
  local cmdUrl = internalState.strBaseUrl .. internalState.strMBoxUrl ;
  local baseUrl = cmdUrl

  -- Debug Message
  --
  
  --log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state as 0, in case of errors before the end.
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
    -- Cycle through the items and store the msg id and size.  
    ---   
	-- example of orange url:  read.html?FOLDER=SF_INBOX&IDMSG=16 
	-- other standard values for folder are SF_JUNK = spam, SF_SENT, SF_TRASH = deleted & SF_DRAFT
	--The only possible uid is the folder name + the message index within it. the index + folder pair is unique
	--if a message is moved to another folder during the session, IDMSG changes.
	
	local _,_,strCmd = string.find (body, '<input type="hidden" name="FOLDER" value="(.-)"');
	
	if strCmd == nil then
        log.say("Orange module may need updating, could not retrieve folder info.\n")
        return nil, "Unable to parse first half of uidl from the html"
	else
		strCmd = curl.escape(strCmd) -- escape the personal folder name.
    end
	
	local baseUrl = internalState.strBaseUrl .. "read.html?FOLDER="
	internalState.strBaseCmd = strCmd
	local strUrl = strCmd .. "&IDMSG="
	local msgPattern=globals.strMsgLinePattern
	if internalState.strMBox == 'draft' then
		msgPattern=globals.strDraftLinePattern
	end
	
    for uidl, size in string.gfind(body, msgPattern) do
	--log.dbg ( "Loop messages :" .. 
      if not uidl or not size  then
        log.say("Orange module may need updating, could not parse individual messages.\n")
        return nil, "Unable to parse size and uidl from the html"
      end
	
	  uidl = strUrl .. uidl  
      if (internalState.msgUrls[uidl] == nil) then
        internalState.msgUrls[uidl] = baseUrl .. uidl
		--log.dbg ("\n----------- processing url:" .. baseUrl ..uidl .. "  Size: " .. size .."\n")
        -- Convert the size from its string (4KB or 2MB) to bytes
        -- Let's figure out the unit
        --
        local bytes = 1
		local _, _, szUnit = string.find(size, "([Mm])")
				if szUnit then
			bytes = 1024 *1024
		end
		_, _, szUnit = string.find(size, "([Kk])")
	    if szUnit then 
			bytes = 1024
		end
        _, _, size = string.find(size, "([%d%.]+)%s-[MmKkBb]")
		size = math.max(tonumber(size), 0) * bytes
		
		--log.dbg("\n----------- Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size .. "\n")

        -- Save the information
        --
        nMsgs = nMsgs + 1
		set_popstate_nummesg(pstate, nMsgs)
        set_mailmessage_size(pstate, nMsgs, size)
        set_mailmessage_uidl(pstate, nMsgs, uidl)
      end
    end
	internalState.lastMsg = nMsgs
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- See if there are messages remaining
    --
	
    local _, _, str = string.find(body, globals.strNextPagePattern)
	
    if str then
	  local join = "?"
	  if internalState.bUsrBox then
		join="&"
	  end
	  cmdUrl = internalState.strBaseUrl .. string.format (globals.strNextPage, internalState.strMBoxUrl, join , str)
	  log.dbg ("Mailbox on more than one page. Fetching new page: " .. cmdUrl .. "\n")
      --cmdUrl = internalStructure.strBaseUrl .. str
      return false
    end
    return true
  end

  -- Local Function to get the list of messages
  --
  local function funcGetPage()  
    -- Debug Message
    --
    --log.dbg("Debug - Getting page: " .. cmdUrl .. "\n")

    -- Get the page and check to see if we got results
    --
    local body, err = browser:get_uri(cmdUrl)
    if body == nil then
      return body, err
    end

    -- Is the session expired
    --
    local _, _, strSessExpr = string.find(body, globals.strSessionExpired)
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
  
  log.dbg("STAT succeded.\n")
	
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
	
  -- MIME Parser/Generator - use custom Orange mimer instead
  --
  --require("omimer")  

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

-- ************************************************************************** --
--  Orange Mimer - custom mimer with extensions for proper inline mime handling
-- ************************************************************************** --

--<==========================================================================>--
local Private = {}

-- FIXME add more from: http://www.w3.org/TR/html401/sgml/entities.html
Private.html_coded = {

	["szlig"]	= "ß",
	["Ntilde"]	= "Ñ",
	["ntilde"]	= "ñ",
	["Ccedil"]	= "Ç",
	["ccedil"]	= "ç",
	
	["auml"]	= "ä",
	["euml"]	= "ë",
	["iuml"]	= "ï",
	["ouml"]	= "ö",
	["uuml"]	= "ü",
	["Auml"]	= "Ä",
	["Euml"]	= "Ë",
	["Iuml"]	= "Ï",
	["Ouml"]	= "Ö",
	["Uuml"]	= "Ü",
	["aacute"]	= "á",
	["eacute"]	= "é",
	["iacute"]	= "í",
	["oacute"]	= "ó",
	["uacute"]	= "ú",
	["Aacute"]	= "Á",
	["Eacute"]	= "É",
	["Iacute"]	= "Í",
	["Oacute"]	= "Ó",
	["Uacute"]	= "Ú",
	["acirc"]	= "â",
	["ecirc"]	= "ê",
	["icirc"]	= "î",
	["ocirc"]	= "ô",
	["ucirc"]	= "û",
	["Acirc"]	= "Â",
	["Ecirc"]	= "Ê",
	["Icirc"]	= "Î",
	["Ocirc"]	= "Ô",
	["Ucirc"]	= "Û",
	["agrave"]	= "à",
	["igrave"]	= "ì",
	["egrave"]	= "è",
	["ograve"]	= "ò",
	["ugrave"]	= "ù",
	["Agrave"]	= "À",
	["Igrave"]	= "Ì",
	["Egrave"]	= "È",
	["Ograve"]	= "Ò",
	["Ugrave"]	= "Ù",

	["euro"]	= '€',
	["pound"]	= '£',
	["yen"]		= '¥',
	["cent"]	= '¢',
	["iquest"]	= '¿',
	["iexcl"]	= '¡',
	["quot"]	= '"',
	["lt"]		= '<',
	["gt"]		= '>',
	["nbsp"]	= ' ',
	["amp"]		= '&',
}

Private.html_tags = {
	["br"] = '\n',
	["/br"] = '\n',
	["li"] = '\t-',
	["/li"] = '\n',
	["ul"] = "",
	["/ul"] = "",
	["ol"] = "",
	["/ol"] = "",
	["img"] = '[image]',
	["/tr"] = '\n',
	["tr"] = "",
	["td"] = "\t",
	["/td"] = "",
	["th"] = "",
	["/th"] = "",
	["table"] = "",
	["/table"] ="",
	["pre"] = "",
	["/pre"] = "",
	["b"] = " *",
	["/b"] = "* ",
	["i"] = "/",
	["/i"] = "/",
	["big"] = "",
	["/big"] = "",
	["small"] = "",
	["/small"] = "",
	["strong"] = " *",
	["/strong"] = "* ",
	["em"] = "/",
	["/em"] = "/",
	["u"] = " _",
	["/u"] = "_ ",
	["div"] = "",
	["/div"] = "",
	["html"] = "",
	["/html"] = "",
	["head"] = "",
	["/head"] = "",
	["body"] = "",
	["/body"] = "",
	["p"] = "",
	["/p"] = "\n",
	["a"] = function (s,base_uri) 
		local start,stop = string.find(s,'[Hh][Rr][Ee][Ff]%s*=%s*')
		if start == nil or stop == nil then
			return "[" .. s .. "]"
		end
		local _,x = nil,nil
		if string.byte(s,stop+1) == string.byte('"') then
			_,_,x = string.find(string.sub(s,stop+2,-1),'^([^"]*)')
		else
			_,_,x = string.find(string.sub(s,stop+1,-1),'^([^ ]*)')
		end
		x = x or "link"
		if string.sub(x,1,1) == '/' then
			x = (base_uri or '/') .. x
		end
		return "[" .. x .. "]"
		end,
	["/a"] = "",
	["hr"] = "\n" .. string.rep("-",72) .. "\n",
	["font"] = "",
	["/font"] = "",
	["!doctype"] = "",
	["void"] = "",
	["/void"] = "",
	["comment"] = "",
	["/comment"] = "",
	["style"] = "",
	["/style"] = "",
	["meta"] = "",
}

Private.html_tags_plain = {
	["br"] = '\n',
	["/br"] = '\n',
	["li"] = '',
	["/li"] = '',
	["ul"] = "",
	["/ul"] = "",
	["ol"] = "",
	["/ol"] = "",
	["img"] = '',
	["/tr"] = '',
	["pre"] = "",
	["/pre"] = "",
	["b"] = "*",
	["/b"] = "*",
	["i"] = "/",
	["/i"] = "/",
	["big"] = "",
	["/big"] = "",
	["small"] = "",
	["/small"] = "",
	["strong"] = "*",
	["/strong"] = "*",
	["em"] = "/",
	["/em"] = "/",
	["u"] = "",
	["/u"] = "",
	["div"] = "",
	["/div"] = "",
	["html"] = "",
	["/html"] = "",
	["head"] = "",
	["/head"] = "",
	["body"] = "",
	["/body"] = "",
	["p"] = "",
	["/p"] = "",
	["a"] = "",
	["/a"] = "",
	["hr"] = "\n" .. string.rep("-",44) .. "\n",
	["font"] = "",
	["/font"] = "",
	["!doctype"] = "",
	["void"] = "",
	["/void"] = "",
	["comment"] = "",
	["/comment"] = "",
	["style"] = "",
	["/style"] = "",
	["meta"] = "",
	["tr"] = "",
	["td"] = "\t",
	["/td"] = "",
	["table"] = "",
	["/table"] ="",
	["th"] = "",
	["/th"] = "",
}


-- ------------------------------------------------------------------------- --
Private.boundary_chars=
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"

function Private.randomize_boundary()
	local t = {}
	local len = string.len(Private.boundary_chars)

	for i=1,16 do
		table.insert(t,
			string.char(string.byte(Private.boundary_chars,math.random(len))))
	end

	return table.concat(t)
end

-- ------------------------------------------------------------------------- --
function Private.needs_encoding(content_type)
	if content_type ~= "text/plain" and
	   content_type ~= "text/html" then
		return true
	else
		return false
	end
end

-- ------------------------------------------------------------------------- --
function Private.content_transfer_encoding_of(content_type)
	if not Private.needs_encoding(content_type) then
		return "Content-Transfer-Encoding: quoted-printable\r\n"
	else
		return "Content-Transfer-Encoding: base64\r\n"
	end
end

-- ------------------------------------------------------------------------- --
Private.base64wrap = 45

function Private.base64_io_slave(cb)
	local buffer = ""
	return function(s,len)
		buffer = buffer .. s
		
		local todo_table = {}
		while string.len(buffer) >= Private.base64wrap do
			local chunk = string.sub(buffer,1,Private.base64wrap)
			table.insert(todo_table,base64.encode(chunk).."\r\n")
			buffer = string.sub(buffer,Private.base64wrap + 1,-1)
		end
		if table.getn(todo_table) > 0 then
			cb(table.concat(todo_table))
		end

		if len == 0 then
			--empty the buffer
			cb(base64.encode(buffer).."\r\n")
			buffer = ""
		end

		return len
	end
end

-- ------------------------------------------------------------------------- --
Private.qpewrap=73
Private.eq = string.byte("=",1)
Private.lf = string.byte("\n",1)
Private.cr = string.byte("\r",1)

-- ------------------------------------------------------------------------- --
---
-- Encodes the message for mail transfer.
-- must be
function Private.quoted_printable_encode(s)
	local out = {}
	local eq = Private.eq
	
	for i=1,string.len(s) do
		local b = string.byte(s,i)
		if b > 127 or b == eq then
			--FIXME: slow!
			table.insert(out,string.format("=%2X",b))
		else
			table.insert(out,string.char(b))
		end
	end
	return table.concat(out)
end

-- ------------------------------------------------------------------------- --
function Private.qpr_eval_expansion(s)
	local count = 0
	local to = 0
	local eq = Private.eq
	local lf = Private.lf
	local cr = Private.cr
	
	for i=1,string.len(s) do
		local b = string.byte(s,i)

		--FIXME not perfect if "...\r" trunk "\n..."
		if b == cr then
			if i+1 <= string.len(s) and 
				string.byte(s,i+1) == lf then
				return true,true,i+1
			else
				return true,true,i
			end
		end

		if b == lf then
			return true,true,i
		end
		
		if b > 127 or b == eq then
			count = count + 3
		else
			count = count + 1
		end
		if count > Private.qpewrap then	
			return true,false,i
		end
	end

	return false,false,string.len(s)
end

-- ------------------------------------------------------------------------- --
-- a callback that implements the "quoted printable" encoding
function Private.quoted_printable_io_slave(cb)
	local buffer = ""
	return function(s,len)
		local saved_len = len 
		buffer = buffer .. s
		
		local todo_table = {}
		local wrap,forced,len = Private.qpr_eval_expansion(buffer)
		while forced or wrap do
			local chunk = string.sub(buffer,1,len)
			if forced then
				chunk = string.gsub(chunk,"[\r\n]","")
				table.insert(todo_table,
				Private.quoted_printable_encode(chunk).."\r\n")
			else
				table.insert(todo_table,
				Private.quoted_printable_encode(chunk).."=\r\n")
			end
			
			buffer = string.sub(buffer,len + 1,-1)
			wrap,forced,len = Private.qpr_eval_expansion(buffer)
		end
		if table.getn(todo_table) > 0 then
			cb(table.concat(todo_table))
		end
		if len == 0 then
			cb(Private.qpr_eval_expansion(buffer))
			buffer = ""
		end
		return saved_len
	end

end

-- ------------------------------------------------------------------------- --
-- wrapper for the NEW and OLD implementation
function Private.attach_it(browser,boundary,send_cb,inlineids,inline,forwarded)
	-- switch here between the old and tested implementation and
	-- the new and more efficient hack
	forwarded = forwarded or {}
	return Private.attach_it_new(browser,boundary,send_cb,inlineids,inline,forwarded)
	--return Private.attach_it_old(browser,boundary,send_cb)
end

Private.sniffer = {
-- FIXME many more content-types can be addded... :)
["image/gif"]	= "GIF",
["image/jpeg"]	= "\255\216", -- FFD8
["image/png"]	= "\137PNG",
--[[
["text/html"]	= "%s-<%s-[Hh][Tt][Mm][Ll]",
]]
}

-- ------------------------------------------------------------------------- --
-- This is the NEW implementation. 
-- 
-- PRO:  + only one HTTP request, the header callback sets content_type and the
--         body callback chooses on the fly the io slave.
--       + no mere HEAD (sometimes not supported by CGIs)
--       + acts as a browser
-- CONS: - the code is harder
--       - worse HTTP header parsing, no error detection. May find the 
--         404 HTML page attached in your mail if the URL is wrong
--       - more cpu intense, one check and a function call more than before
--       
function Private.attach_it_new(browser,boundary,send_cb,inlineids,inline,forwarded)	
	return function(k,uri)
	  local inlineid = inlineids[k]
	  local isForwarded = forwarded[k]
	  if (inlineid and inline) or (not (inlineid or inline)) then
		-- the 2 callbacks and the shared variable content_type
		local cb_h,cb_b = nil,nil
		local content_type = nil
		
		-- the header parser, simply sets the content_type variable
		cb_h = function(h,len)
			-- FIXME, may be an incorrect URL and not a 200 HTTP
			if not inline then -- ORANGE CODE if inline orange always returns cType="text/html"
			-- try to extract the content type
				local _,_,x = string.find(h or "",
				"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:%s*([^\r]*)")
				-- if x ~= nil then
				content_type = x
				-- end
			end
			--log.dbg(" in cb_h    " .. tostring(content_type))
			return len
		end

		-- a static variable for the callback that contains the real io slave callback
		-- 
		local real_cb = nil
		
		cb_b = function(s,len)
			-- the first time we choose the encoding depending on 
			-- the content_type shared variable set by the cb_h
			local real_s = s
			if real_cb == nil then
				-- ORANGE CODE -- START
				if (inlineid and inline) then -- ORANGE CODE if inline orange always returns cType="text/html"
					content_type = nil
					for n,b in pairs(Private.sniffer) do
						if string.find(s or "", b) == 1 then
							content_type = n
							break
						end
					end
					-- In both outlook and thunderbird image/gif will make the client try all other image encodings
					-- Outlook doesn't look at the content-type at all, & thunderbird 1.5 ignores image/ and image/x
					if string.find (uri,omimer.strImagePattern ) then
						content_type = content_type or "image/gif"
					end
				end
				
				--[[
				if isForwarded then
					--FIXME - need to implement proper forward attachment handling 
					--'Content-Disposition: inline; filename="' .. k .. '"'
					content_type = 'message/rfc822; name="' .. k ..'"'
				end
				]]
				-- ORANGE CODE -- END
	
				content_type = content_type or 
					"application/octet-stream"
					
				--log.dbg(" in cb_b    " .. tostring(content_type))
				if Private.needs_encoding(content_type) then
					real_cb = Private.
					  base64_io_slave(send_cb)
				else
					real_cb = Private.
					  quoted_printable_io_slave(send_cb)
				end
				-- we send the mime header
				
				if (inlineid == nil) then
					send_cb("--"..boundary.."\r\n"..
						"Content-Type: "..content_type.."\r\n"..
						"Content-Disposition: attachment; "..
						"filename=\""..k.."\"\r\n"..
						Private.content_transfer_encoding_of(
							content_type)..
						"\r\n")
				else
					send_cb("--"..boundary.."\r\n"..
						"Content-Type: "..content_type.."\r\n"..
						"Content-Disposition: inline\r\n"..
						"Content-ID: <"..inlineid..">\r\n"..
						Private.content_transfer_encoding_of(
							content_type)..
						"\r\n")
				end
			end

			-- we simply use the real io slave
			return real_cb(real_s,len)
		end
	
		-- do the work
		browser:pipe_uri_with_header(uri,cb_h,cb_b)

		-- flush last bytes
		cb_b("",0)
	  end
	end
end

-- ------------------------------------------------------------------------- --
-- this is the OLD implementation
--
-- PRO:  + safe and tested
--       + less cpu intensive
-- CONS: - more HTTP requests than a real browser
--       - if HEAD is not supported a GET is done
--       
function Private.attach_it_old(browser,boundary,send_cb)	
	return function(k,uri)

		local h,err = browser:get_head(uri,{},true)

		local _,_,x = string.find(h or "",
		"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:%s*([^\r]*)")

		x = x or "application/octet-stream"

		send_cb("--"..boundary.."\r\n"..
			"Content-Type: "..x.."\r\n"..
			"Content-Disposition: attachment; "..
				"filename=\""..k.."\"\r\n"..
			Private.content_transfer_encoding_of(x)..
			"\r\n")
			
		local cb = nil
		if Private.needs_encoding(x) then
			cb = Private.base64_io_slave(send_cb)
		else
			cb = Private.quoted_printable_io_slave(send_cb)
		end
	
		-- do the work
		browser:pipe_uri(uri,cb)

		-- flush last bytes
		cb("",0)
	end
end

-- ------------------------------------------------------------------------- --
function Private.send_alternative(text_encoding,body,body_html,send_cb,isInline,browser,attachments,inlineids,bound)
	local boundary, rc
	if bound then
		boundary = bound
	else
		boundary = Private.randomize_boundary()
		rc = send_cb('Content-Type: Multipart/alternative; boundary="'..boundary..'"\r\n\r\n')
		if rc ~= nil then return rc end
	end 
	rc = send_cb("--"..boundary.."\r\n"..
		"Content-Type: text/plain; charset="..text_encoding.."\r\n"..
		"Content-Transfer-Encoding: quoted-printable\r\n"..
		"\r\n"..
		body)
	if rc ~= nil then return rc end
	
	if isInline then
		rc = Private.send_inline(text_encoding,body_html,send_cb,browser,attachments,inlineids,nil)
	else
		rc = send_cb("--"..boundary.."\r\n"..
			"Content-Type: text/html; charset="..text_encoding.."\r\n"..
			"Content-Transfer-Encoding: quoted-printable\r\n"..
			"\r\n"..
			body_html)
		
	end
	if rc ~= nil then return rc end
	
	if not bound then 
		send_cb("--"..boundary.."--\r\n\r\n")
	end
end

function Private.send_inline(text_encoding,body_html,send_cb,browser,attachments,inlineids,bound)
	local boundary, rc 
	if bound then
		boundary = bound
	else
		boundary = Private.randomize_boundary()
		rc = send_cb('Content-Type: Multipart/Related; boundary="'..boundary..'"\r\n\r\n')
		if rc ~= nil then return rc end
	end

	rc = send_cb("--"..boundary.."\r\n"..
		"Content-Type: text/html; charset="..text_encoding.."\r\n"..
		"Content-Transfer-Encoding: quoted-printable\r\n"..
		"\r\n"..
		body_html)
	if rc ~= nil then return rc end	
	rc = table.foreach(attachments,
		Private.attach_it(browser,boundary,send_cb,inlineids,true))
	if rc ~= nil then return end

	if not bound then 
		send_cb("--"..boundary.."--\r\n\r\n")
	end
end

-- ------------------------------------------------------------------------- --
function Private.token_of(c)
	local _,_,x,y = string.find(c,"^%s*([/!]?)%s*(%a+)%s*")
	return (x or "") .. (y or "")
end

-- ------------------------------------------------------------------------- --
function Private.html2txt(s,base_uri,html_coded,html_tags,all)

	s = string.gsub(s,"<%s*[Ss][Cc][Rr][Ii][Pp][Tt].->.-<%s*/%s*[Ss][Cc][Rr][Ii][Pp][Tt].->","")
	s = string.gsub(s,"<%s*[Ss][Tt][Yy][Ll][Ee].->.-<%s*/%s*[Ss][Tt][Yy][Ll][Ee].->","")
	s = string.gsub(s,"<([^>]-)>",function(c)
		c = string.lower(c)
		local t = Private.token_of(c)
		local r = html_tags[t]
		
		if type(r) == "string" then
			return r
		elseif type(r) == "function" then
			return r(c,base_uri)
		end
		if all then
			return "["..c.."]"
		else
			return "<" .. c ..">"
		end
	end)
	--  moved below, otherwise it gets confused by strings like '&lt;<' 
	s = string.gsub(s,"&(%a-);",function(c)
		c = string.lower(c)
		return html_coded[c] or ("["..c.."]")
	end)
	if all then
		local n = 1
		while n > 0 do 
			s,n = string.gsub(s,"^%s*\n%s*\n","\n")
		end
	end
	return s
end

Private.extra = {
	string.byte("%",1),
	string.byte("-",1)
}

function Private.is_an_extra(c)
	return table.foreach(Private.extra,
		function(_,m) 
			if m == c then 
				return true 
			end 
		end) or false
end

function Private.domatch(b,v,a)
	local vU = string.upper(v)
	local vL = string.lower(v)
	local r = {}
	for i=1,string.len(v) do
		if Private.is_an_extra(string.byte(vU,i)) then
			r[i] = string.char(string.byte(vU,i))
		else
			r[i]="["..string.char(string.byte(vU,i))..
				string.char(string.byte(vL,i)).."]"
		end
	end
	return b .. table.concat(r) .. a
end

function Private.lines_of_string(s)
	local result = {}
	while s ~= "" do
		local a,b = string.find(s,"\n")
		if a == nil then
			table.insert(result,s)
			break
		end
		table.insert(result,string.sub(s,1,a))
		s = string.sub(s,b+1,-1)
	end
	return result
end

---
-- Converts a plain text string to a \r\n encoded message, ready to send as
-- a RETR response.
-- 
function Private.t2mail(s)
	s = string.gsub(s,'\r','')
	s = string.gsub(s,'\n','\r\n')
	s = string.gsub(s,'\r\n%.\r\n','\r\n..\r\n') -- bugfixed from mimer.lua
	if string.sub(s,-2,-1) ~= '\r\n' then
		s = s .. '\r\n'
	end
	return s
end

function Private.txt2mail(s)
	local d = Private.quoted_printable_encode(s)
	return Private.t2mail(d)
end

--<==========================================================================>--
--module("omimer")

---
-- Builds a MIME encoded message and pipes it to send_cb.
-- @param headers string the mail headers, already mail encoded (\r\n) but
--        without the blank line separator.
-- @param body string the plain text body, if null it is inferred from the 
--        html body that must be present in that case.
-- @param body_html string the html body, may be null.
-- @param base_uri string is used to mangle hrefs in the mail html body.
-- @param attachments table a table { ["filename"] = "http://url" }.
-- @param browser table used to fetch the attachments.
-- @param send_cb function the callback to send the message, 
--        may be called more then once and may return not nil to stop 
--        the ending process.
-- @param inlineids table a table { ["filename"] = "content-Ids" } which
-- 	  contains the ids for inline attachments (default {}).
-- @param text_encoding string default "iso-8859-1"	  
-- @param forwarded table a table {["filename"] = "http://url" }. -- ORANGE CODE
function omimer.pipe_msg(headers,body,body_html,base_uri,attachments,browser,send_cb,inlineids,text_encoding,forwarded)
	attachments = attachments or {}
	inlineids = inlineids or {}
	forwarded = forwarded or {} -- ORANGE CODE
	text_encoding = text_encoding or "iso-8859-1"
	local rc = nil

	if not (body or body_html) then
		error("Mimer needs either body or body_html. Email wasn't processed.")
		return
	end

	--body = body or html2txtmail(body_html,base_uri)
	local isAlt, isInline, isAttached, boundary, cType
	--initialize randomize_boundary
	math.randomseed(math.fmod(os.time(),37))
	local j = math.random(67)
	math.randomseed((math.fmod((os.time()/j),73)+1)*j)

	isAttached = table.getn(attachments) > table.getn(inlineids)
	isAlt = body and body_html
	isInline = table.getn(inlineids) > 0
	-- log.dbg( "Mimer - attach: " .. tostring(isAttached) .. " Alt: " .. tostring(isAlt) .. " inline: " .. tostring(isInline))
	
	if table.getn(attachments) > 0 or isAlt then
		boundary = Private.randomize_boundary()
	end

	if isAttached then
		cType = "Multipart/Mixed"
	else
		if isAlt then
			cType = "Multipart/Alternative"
		else
			if body_html == nil then
				cType ="text/plain"
				--body=Private.quoted_printable_encode(body)
			else
				if isInline then
					cType = "Multipart/Related"
				else
					cType= "text/html"
					body, body_html = body_html , nil  
				end
			end
		
		end
	end
	
	local mime
	if boundary then
		mime = 'boundary="' .. boundary .. '"\r\n'
	else
		mime =	"charset="..text_encoding.."\r\n"..
				"Content-Transfer-Encoding: quoted-printable\r\n\r\n"
	end
	
	mime =	"MIME-Version: 1.0 (produced by FreePOPS/MIMER)\r\n" ..
			"Content-Type: " .. cType .. "; " .. mime
	
	-- send headers
	headers=omimer.remove_lines_in_proper_mail_header(headers, {"content%-type","MIME%-Version"})
	rc = send_cb(headers .. mime .. "\r\n")
	if rc ~= nil then return end
	
	if not boundary then
		-- Content-Transfer-Encoding is ignored in this particular case, so we need to
		-- do a txt2mail conversion WITHOUT quoted_printable_encoding
		rc = send_cb(Private.t2mail(body) .. "\r\n")
		if rc ~= nil then return end
	else
		if isAlt then --  two texts
			local bound
			if cType == "Multipart/Alternative" then
				bound = boundary
			else
				rc = send_cb("--"..boundary.."\r\n")
				if rc ~= nil then return end
			end
			rc = Private.send_alternative(text_encoding,
				Private.txt2mail(body),
				Private.txt2mail(body_html),
				send_cb,isInline,browser,attachments,inlineids,bound)
			if rc ~= nil then return end
				
		else -- one text + attachment
			if isInline then
				local bound
				if cType == "Multipart/Related" then
					bound = boundary
				else
					rc = send_cb("--"..boundary.."\r\n")
					if rc ~= nil then return end
				end
				rc = Private.send_inline(text_encoding,Private.txt2mail(body_html),send_cb,browser,attachments,inlineids,bound)
				if rc ~= nil then return end
			else -- non-inline text + attachment -- cType == "Multipart/Mixed"
				local bType
				if body_html then 
					bType = "html"
					body = body_html
				else
					bType="plain"
					--body = Private.quoted_printable_encode(body)
				end
				rc = send_cb('--'..boundary..'\r\nContent-Type: text/' ..
					bType ..'; charset='..text_encoding..'\r\n'..
					"Content-Transfer-Encoding: quoted-printable\r\n\r\n"..
					Private.txt2mail(body))
				if rc ~= nil then return end
			end	
		end
		
		if isAttached then
			if rc ~= nil then return end
			rc = table.foreach(attachments,
				Private.attach_it(browser,boundary,send_cb,inlineids,false,forwarded))
			if rc ~= nil then return end
		end
		
		send_cb("--"..boundary.."--\r\n\r\n")
	end
end

---
-- Tryes to convert an HTML document to a human readable plain text.
--
function omimer.html2txtmail(s,base_uri)
	return Private.html2txt(s,base_uri,Private.html_coded,Private.html_tags,true)
end

---
-- Converts an HTML document to a plain text file, removing tags and
-- unescaping &XXXX; sequences.
--
function omimer.html2txtplain(s,base_uri)
	return Private.html2txt(s,base_uri,Private.html_coded,
		Private.html_tags_plain,false)
end

---
--Removes unwanted tags from an html string.
--@param p table a list of tags in this form {"head","p"}.
--@return string the cleaned html.
function omimer.remove_tags(s,p)
	table.foreachi(p,function(k,v)
		s = string.gsub(s,Private.domatch("<%s*[!/]?",v,"[^>]*>"),"")
	end)
	return s
end

---
-- Deletes some fields in a mail header.
--@param s string a valid mail header.
--@param p table a list of mail headers in this form {"content%-type","date"} 
-- 	(with - escaped with %).
--@return string the cleaned header.
function omimer.remove_lines_in_proper_mail_header(s,p)
	local s1 = Private.lines_of_string(s)
	local remove_next = false
	local result = {}
	
	for i,l in ipairs(s1) do
		local skip = false
		if remove_next then
			if string.byte(l,1)==string.byte(" ") or
				string.byte(l,1)==string.byte("\t")then
				skip = true
			else
				remove_next = false
			end
		end
			
		if not skip then
			local match = table.foreach(p,function(k,m)
				local _,_,x = string.find (l,
					Private.domatch("^(",m,")"))
				if x ~= nil then
					return true
				end
			end)

			if match == nil then
				table.insert(result,l)
			else
				remove_next = true
			end
		end
	end
	return table.concat(result)
end

---
-- Transforms a classical callback f(s,len) to a mimer compliant callback.
--@param f function a function that takes s,len and returns len,error.
--@return function a callback that returns non nil to stop (instead of 
--                 0,"" or nil,"").
function omimer.callback_mangler(f) 
	return function(s)
		local b,err = f(s,string.len(s))
		if b == 0 or b == nil then
			if b == nil then
				log.error_print(err or "bad callback?")
			end
			return true
		else
			return nil
		end
	end
end

-- EOF
-- ************************************************************************** --
