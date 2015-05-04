-- ************************************************************************** --
--  FreePOPs @inbox.net webmail interface
-- 
--  Released under the GNU/GPL license
--  Written by Neil Smith <neilsmith@despammed.com>
-- ************************************************************************** --

PLUGIN_VERSION = "0.4"
PLUGIN_NAME = "inbox.lua"
PLUGIN_REQUIRE_VERSION = "0.0.97"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=inbox.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Neil Smith"}
PLUGIN_AUTHORS_CONTACTS = {"neilsmith (at) despammed (.) com"}
PLUGIN_DOMAINS = {
    "@212.com", "@aah.net", "@adios.net", "@allalone.com", "@asm.net",
    "@backwards.com", "@blink182.net", "@bombdiggity.com", "@bonzo.com",
    "@bounce.net", "@bounty.net", "@breakbeat.com", "@brigid.com", "@broken.org",
    "@businessman.net", "@businesswoman.net", "@c4.org", "@captain.net",
    "@chatonline.com", "@cindy.org", "@cookiemonster.com", "@cps.org",
    "@danger.org", "@dangerous.net", "@davis.org", "@deadman.com", "@devoid.org",
    "@discover.org", "@dnb.net", "@donjuan.com", "@dragonballz.net", "@drug.org",
    "@duet.net", "@elmer.com", "@explorer.org", "@five.net", "@freshman.net",
    "@friction.net", "@geography.net", "@highquality.com", "@hurting.com",
    "@hut.net", "@i386.net", "@inbox.net", "@insecure.net", "@intimate.net",
    "@javascript.org", "@kermit.net", "@kernel.net", "@lab.org", "@lakmail.com",
    "@lauren.net", "@leanne.com", "@lebaron.com", "@lemonheads.com",
    "@limpbizkit.net", "@melt.com", "@meth.com", "@misery.net", "@myst.net",
    "@negative.org", "@netromance.com", "@nill.net", "@nix.org",
    "@nocturnal.com", "@outerlimits.net", "@penguins.org", "@pez.net",
    "@phantom.org", "@playtime.org", "@punks.net", "@revert.com", "@roms.net",
    "@sad.net", "@scared.org", "@sedate.com", "@simpsons.com", "@skating.net",
    "@slayer.org", "@so.org", "@sof.net", "@sparcs.com", "@stallion.net",
    "@stigmata.com", "@strangers.com", "@stullers.com", "@theunknown.com",
    "@twinkie.com", "@typo.net", "@vga.net", "@vrv.com", "@ys.com"
}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
    en=[[freepops plugin for inbox.net and associated domains]]
}

local globals = {
    strStartPage = "http://www.inbox.net/startpage.cgi",
    strLoginPage = "<title>Login to your account</title>",
    sessionTimeout = 3600
}

local defaultGlobals = {
    strMlexE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>.*<a>[.*]{b}[.*]{/b}[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}[O]{O}[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>",
    strMsgStart = "<td bgcolor=#ffffff align='left' class='ts'> <font class='ts'>",
    strMsgEnd = "</font> </td>%s+</tr>%s+</table>%s+</td>%s+</tr>%s+</table>%s+</td></tr></table>%s+</td>%s+</tr></table>",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

local blueGlobals = {
    strMlexE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>.*<a>[.*]{b}[.*]{/b}[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}[O]{O}[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>",
    strMsgStart = "\t\t\t\t\t\t\t\t\t\t\t<TD class='ts'><font class='ts'>",
    strMsgEnd = "</font>%s+</TD>%s+</TR>%s+</TABLE>%s+</TD>%s+</TR>%s+</TABLE>%s+</TD>%s+<",
  --strMsgEnd = "</font>%s+</TD>%s+</TR>%s+</TABLE>%s+</TD>%s+</TR>%s+</TABLE>%s+</TD>%s+<\!-- content end -->",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

local orangeGlobals = {
    strMlexE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>.*<a>[.*]{b}[.*]{/b}[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}[O]{O}[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>",
    strMsgStart = "\t\t\t\t<font class='ts'>",
    strMsgEnd = "</font>%s+\t\t\t\t%s+\t\t\t\t</TD></TR>%s+\t\t\t</TABLE>%s+\t\t</TD>%s+\t</TR>%s+\t</TABLE>%s+%s+</td>%s+</tr>%s+</table><br>",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

local slateGlobals = {
    strMlexE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>.*<a>[.*]{b}[.*]{/b}[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}[O]{O}[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>",
    strMsgStart = "\t\t<td class=\"ts\" bgcolor=\"#ffffff\"><font class='ts'>",
    strMsgEnd = "</font></td>%s+\t</tr>%s+\t</table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+<",
  --strMsgEnd = "</font></td>%s+\t</tr>%s+\t</table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+</td></tr></table>%s+<!-- /MAIN -->",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

local straightedgeGlobals = {
    strMlexE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>.*<a>[.*]{b}[.*]{/b}[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}[O]{O}[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>",
    strMsgStart = "            <font class='ts'>",
    strMsgEnd = "</font>%s+</TD>%s+</TR>\t\t%s+</TABLE>%s+</TD>%s+</TR>%s+</TABLE>%s+</BODY>",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

local titaniumGlobals = {
    strMlexE = ".*<tr>.*<td>.*<table>.*<td>.*<input>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</tr>.*<tr>.*<td>.*<span>.*<img>.*<a>[.*]{b}.*{img}[.*]{/b}[.*]</a>.*</span>.*</td>.*<td>.*<span>.*<img>[.*]{b}.*{/b}[.*]</span>.*</td>.*</table>.*</td>.*</tr>",
    strMlexG = "O<O>O<O>O<O>O<O>O<X>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>[O]{O}O{O}[O]{O}[O]<O>O<O>O<O>O<O>O<O>O<O>[O]{O}X{O}[O]<O>O<O>O<O>O<O>O<O>",
    strMsgStart = "   \t   <font class='ts'>",
    strMsgEnd = "</font>%s+</td></tr></table>%s+</td></tr>%s+</table>%s+</td></tr>%s+</table>%s+</td></tr>%s+</table>%s+</body>",
    strNextPage = "<a href=\"([^\"]*)\" style=\"text.decoration: none;\"><b>Next &gt;&gt;</b>"
}

internalState = {
    stat_done=false,
    login_done=false,
    username=nil,
    password=nil,
    domain=nil,
    name=nil,
    browser=nil,
    session_id=nil,
    login_time=nil,
    skin=nil,
    markAsRead=false,
    strMlexE = nil,
    strMlexG = nil,
    strMsgStart = nil,
    strMsgEnd = nil,
    strNextPage = nil
}

-- -------------------------------------------------------------------------- --
-- Hash is used to store session info
function hash()
    return (internalState.username or "") .. (internalState.password or "")
end

-- -------------------------------------------------------------------------- --
-- Serialize the state
function serialize_state()
    internalState.stat_done = false
    return serial.serialize("internalState", internalState) ..
	internalState.browser:serialize("internalState.browser")
end

-- -------------------------------------------------------------------------- --
-- Login and get session_id
function inbox_login()
    log.dbg("function inbox_login entered\n")

    -- Check to see if we've already logged in
    --
    if internalState.login_done then
	return POPSERVER_ERR_OK
    end

    local b = browser.new()
    internalState.browser = b

    local post_uri = globals.strStartPage
    local post_data = string.format("username=%s&password=%s&domain=%s",
	internalState.name, internalState.password, curl.escape(internalState.domain))

    local file,err = b:post_uri(post_uri,post_data)
    if file == nil then
	return POPSERVER_ERR_NETWORK
    end

    local _,_,session_id = string.find(file,"rkey=([^']*)'")
    if session_id == nil then
	log.dbg("Didn't get the session ID\n")
	return POPSERVER_ERR_AUTH
    end
    internalState.session_id = session_id
    log.dbg("Session ID is '"..session_id.. "'\n")

    -- Work out which skin is set
    -- blue/orange/slate/straightedge/titanium/default
    --
    local _,_,skin = string.find(file,"<link rel=\"stylesheet\" href=\"/includes/css/(%w+)/default.css\">")
    internalState.skin = skin
    log.dbg("Skin is '" .. (skin or "") .. "'\n")
    if skin == "blue" then
	log.dbg("Strings set for blue skin")
	internalState.strMlexE = blueGlobals.strMlexE
	internalState.strMlexG = blueGlobals.strMlexG
	internalState.strMsgStart = blueGlobals.strMsgStart
	internalState.strMsgEnd = blueGlobals.strMsgEnd
	internalState.strNextPage = blueGlobals.strNextPage
    elseif skin == "orange" then
	log.dbg("Strings set for orange skin")
	internalState.strMlexE = orangeGlobals.strMlexE
	internalState.strMlexG = orangeGlobals.strMlexG
	internalState.strMsgStart = orangeGlobals.strMsgStart
	internalState.strMsgEnd = orangeGlobals.strMsgEnd
	internalState.strNextPage = orangeGlobals.strNextPage
    elseif skin == "slate" then
	log.dbg("Strings set for slate skin")
	internalState.strMlexE = slateGlobals.strMlexE
	internalState.strMlexG = slateGlobals.strMlexG
	internalState.strMsgStart = slateGlobals.strMsgStart
	internalState.strMsgEnd = slateGlobals.strMsgEnd
	internalState.strNextPage = slateGlobals.strNextPage
    elseif skin == "straightedge" then
	log.dbg("Strings set for straightedge skin")
	internalState.strMlexE = straightedgeGlobals.strMlexE
	internalState.strMlexG = straightedgeGlobals.strMlexG
	internalState.strMsgStart = straightedgeGlobals.strMsgStart
	internalState.strMsgEnd = straightedgeGlobals.strMsgEnd
	internalState.strNextPage = straightedgeGlobals.strNextPage
    elseif skin == "titanium" then
	log.dbg("Strings set for titanium skin")
	internalState.strMlexE = titaniumGlobals.strMlexE
	internalState.strMlexG = titaniumGlobals.strMlexG
	internalState.strMsgStart = titaniumGlobals.strMsgStart
	internalState.strMsgEnd = titaniumGlobals.strMsgEnd
	internalState.strNextPage = titaniumGlobals.strNextPage
    else
	log.dbg("Strings set for global skin")
	internalState.strMlexE = defaultGlobals.strMlexE
	internalState.strMlexG = defaultGlobals.strMlexG
	internalState.strMsgStart = defaultGlobals.strMsgStart
	internalState.strMsgEnd = defaultGlobals.strMsgEnd
	internalState.strNextPage = defaultGlobals.strNextPage
    end

    -- Note that we have logged in successfully
    --
    internalState.login_time = os.clock()
    internalState.login_done = true

    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Callback for the retr function
--
function downloadMsg_cb(cbInfo, data)
    log.dbg("function downloadMsg_cb entered\n")

    return function(body, len)
	log.dbg("function anonymous callback entered\n")

	-- Are we done with Top and should just ignore the chunks
	--
	if (cbInfo.nLinesReceived == -1) then
	    log.dbg("In the callback, but finished already\n")
	    return 0, nil
	end

	-- Add back any bit we saved last time
	--
	body = cbInfo.strBuffer .. body

	-- If we've not got to the start yet, just keep the saved end bit
	--
	local msgStartIdx = 0
	if cbInfo.bFirstBlock then
	    msgStartIdx,_,_ = string.find(body, "("..internalState.strMsgStart..")")
	    if msgStartIdx == nil then
		log.dbg("Not found the start yet\n")
		cbInfo.strBuffer = string.sub(body, -string.len(internalState.strMsgEnd))
		return len, nil
	    else
		log.dbg("Found the start of the message\n")
		cbInfo.bFirstBlock = false
	    end
	end

	-- Did we reach the end of the message
	--
	local msgEndIdx,_,_ = string.find(body, "("..internalState.strMsgEnd..")")
	if msgEndIdx ~= nil
	and not cbInfo.bFirstBlock
	and not (msgEndIdx < (msgStartIdx or 0)) then
	    log.dbg("Found the end of the message\n")
	    cbInfo.nLinesReceived = -1
	    cbInfo.strBuffer = ""
	else
	    -- If not, save the end bit of this string so as
	    -- not to split up our end text and then fail to
	    -- recognise it
	    --
	    log.dbg("We're in the middle of the message\n")
	    local saveLen = string.len(internalState.strMsgEnd)
	    local bodyLen = string.len(body)
	    if bodyLen < saveLen then
		saveLen = bodyLen
	    end
	    cbInfo.strBuffer = string.sub(body, -saveLen)
	    body = string.sub(body, 1, -(saveLen + 1))

	    -- Finally, don't split the string anywhere that
	    -- might split up one of the tokens that gets
	    -- replaced in cleanupBody
	    --
	    while (string.len(body) > 6 and string.find(string.sub(body, -6), "([&<])") ~= nil) do
		cbInfo.strBuffer = string.sub(body, -6) .. cbInfo.strBuffer
		body = string.sub(body, 1, -7)
	    end
	
	end

	body = cleanupBody(body)

	-- Perform our "TOP" actions
	--
	if (cbInfo.nLinesRequested ~= -2) then
	    body = cbInfo.strHack:tophack(body, cbInfo.nLinesRequested)

	    -- Check to see if we are done and if so, update things
	    --
	    if cbInfo.strHack:check_stop(cbInfo.nLinesRequested) then
		cbInfo.nLinesReceived = -1
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

-- -------------------------------------------------------------------------- --
function cleanupBody(body)
    log.dbg("function cleanupBody entered\n")

    -- get rid of the HTML before and after message text
    --
    body = string.gsub(body, "^.*"..internalState.strMsgStart.."[%s]*", "")
    body = string.gsub(body, internalState.strMsgEnd..".*", "")

    -- Clean up the end of line, and replace HTML tags
    --
    body = string.gsub(body, "\n", "\r\n")
    body = string.gsub(body, "<br>", "\r\n")
    body = string.gsub(body, "&amp;", "&")
    body = string.gsub(body, "&lt;", "<")
    body = string.gsub(body, "&gt;", ">")
    body = string.gsub(body, "&quot;", "\"")
    return body
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function downloadMsg(pstate, msg, nLines, data)
    log.dbg("function downloadMsg entered\n")

    -- we need the stat
    local st = stat(pstate)
    if st ~= POPSERVER_ERR_OK then
	return st
    end

    -- some local stuff
    local session_id = internalState.session_id
    local b = internalState.browser
    local uidl = get_mailmessage_uidl(pstate,msg)
    local uri = "http://" .. b:wherearewe() .. "/viewsource.cgi?rkey="..session_id..
	"&m=0x"..uidl

    -- Define a structure to pass between the callback calls
    --
    local cbInfo = {
	-- Whether this is the first call of the callback
	--
	bFirstBlock = true,

	-- String hacker
	--
	strHack = stringhack.new(),

	-- Lines requested (-2 means not limited)
	--
	nLinesRequested = nLines,

	-- Lines Received - Not really used for anything
	--
	nLinesReceived = 0,

	-- Buffer
	--
	strBuffer = ""
    }

    -- Define the callback
    --
    local cb = downloadMsg_cb(cbInfo, data)

    -- Start the download on the body
    -- 
    local f, _ = b:pipe_uri(uri, cb)
    if not f then
	-- An empty message.  Throw an error
	--
	return POPSERVER_ERR_NETWORK
    end

    -- Handle whatever is left in the buffer
    --
    local body = cbInfo.strBuffer
    if (string.len(body) > 0 and not cbInfo.bFirstBlock) then
	log.dbg("Something's left over in the buffer\n")
	body = cleanupBody(body)
	body = cbInfo.strHack:dothack(body) .. "\0"
	popserver_callback(body, data)
    end

    -- Mark the mail as read for the webmail interface
    --
    if internalState.markAsRead then
	uri = "http://" .. b:wherearewe() .. "/mark.cgi"
	local post_data = "rkey=" .. session_id ..
	    "&boxes0x" .. uidl .. "=0x" .. uidl ..
	    "&l=inbox&go=move" 
	log.dbg("Marking mail as read\n")
	log.dbg("uri: '"..uri.."'\n")
	log.dbg("post_data: '"..post_data.."'\n")
	b:post_uri(uri,post_data)
    else
	log.dbg("Mark as read not required\n")
    end
end

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
    log.dbg("function init entered\n")

    freepops.export(pop3server)

    log.dbg("FreePOPs plugin '"..
	PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

    -- Serialization
    --
    require("serial")

    -- Browser
    --
    require("browser")

    -- Common module
    --
    require("common")

    -- Run a sanity check
    --
    freepops.set_sanity_checks()

    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
    log.dbg("function user entered\n")

    -- extract and check domain
    local domain = freepops.get_domain(username)
    local name = freepops.get_name(username)

    internalState.username = username
    internalState.domain = domain
    internalState.name = name

    internalState.username = username
    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
    log.dbg("function pass entered\n")

    -- save the password
    internalState.password = password
    -- start to load session
    local s = session.load_lock(hash())
    -- check if loaded properly
    if s ~= nil then
	-- "\a" means locked
	if s == "\a" then
	    log.say("Session for "..internalState.name.." is already locked\n")
	    return POPSERVER_ERR_LOCKED
	end
	-- load the session
	local func,err = loadstring(s)
	if not func then
	    log.error_print("Unable to load saved session: "..err)
	    return inbox_login()
	end
	-- exec the code loaded from the session string
	func()
	log.say("Session loaded for " .. internalState.name .. "@" ..
	    internalState.domain ..
	    "(" .. internalState.session_id .. ")\n")
	return POPSERVER_ERR_OK
    else
	-- call the login procedure
	return inbox_login()
    end
end

-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
    log.dbg("function quit entered\n")

    session.unlock(hash())
    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
    log.dbg("function quit_update entered\n")

    -- we need the stat
    local st = stat(pstate)
    if st ~= POPSERVER_ERR_OK then
	return st
    end

    -- shorten names, not really important
    local b = internalState.browser
    local post_uri = "http://" .. b:wherearewe() .. "/move.cgi"
    local session_id = internalState.session_id
    local post_data = "rkey=" .. session_id .. "&l=inbox&go=move&f=trash&move1=trash"

    -- here we need the stat, we build the uri and we check if we
    -- need to delete something
    local delete_something = false
    for i=1,get_popstate_nummesg(pstate) do
	if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
	    post_data = post_data .. "&boxes0x" ..
		get_mailmessage_uidl(pstate,i) .. "=0x" ..
		get_mailmessage_uidl(pstate,i) 
	    delete_something = true
	end
    end

    -- if any need deleting, go do it
    if delete_something then
	b:post_uri(post_uri,post_data)
    end

--    local post_uri = "http://" .. b:wherearewe() .. "/mark.cgi"
--    local post_data = "rkey=" .. session_id .. "&l=inbox&go=move"
--
--    -- see if any need marking and build the uri
--    local mark_something = false
--    for i=1,get_popstate_nummesg(pstate) do
--	if get_mailmessage_flag(pstate,i,MAILMESSAGE_MARK) then
--	    post_data = post_data .. "&boxes0x" ..
--		get_mailmessage_uidl(pstate,i) .. "=0x" ..
--		get_mailmessage_uidl(pstate,i) 
--	    mark_something = true
--	end
--    end
--
--    if mark_something then
--	b:post_uri(post_uri,post_data)
--    end

    local curr_time = os.clock()
    local diff = curr_time - internalState.login_time

    if diff > globals.sessionTimeout then
	-- force logout
	post_uri = "http://" .. b:wherearewe() .. "/logout.cgi"
	b:get_uri(post_uri)
	session.remove(hash())
    else
	session.save(hash(),serialize_state(),session.OVERWRITE)
	session.unlock(hash())
    end
    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
    log.dbg("function stat entered\n")

    -- If we've been called already, just return success
    --
    if internalState.stat_done == true then
	return POPSERVER_ERR_OK
    end

    local file,err = nil, nil
    local browser = internalState.browser
    local session_id = internalState.session_id

    -- this string will contain the uri to get. it may be updated by
    -- the check_f function, see later
    local uri = "http://" .. browser:wherearewe() .. "/showmail.cgi?f=inbox"

    -- The action for do_until
    --
    -- uses mlex to extract all the messages uidl and size
    local function action_f (s)
	log.dbg("function action_f entered\n")

	-- calls match on the page s, with the mlexpressions
	-- statE and statG
	local x = mlex.match(s,internalState.strMlexE,internalState.strMlexG)

	-- the number of results
	local n = x:count()

	if n == 0 then
	    return true,nil
	end

	-- this is not really needed since the structure
	-- grows automatically... maybe... don’t remember now
	local nmesg_old = get_popstate_nummesg(pstate)
	local nmesg = nmesg_old + n
	set_popstate_nummesg(pstate,nmesg)

	for i=1,x:count() do
	    local _,_,size = string.find(x:get(1,i-1),"(%d+)")
	    local _,_,size_mult_k = string.find(x:get(1,i-1),"([Kk])")
	    local _,_,size_mult_m = string.find(x:get(1,i-1),"([Mm])")
	    local _,_,uidl = string.find(x:get(0,i-1),"boxes0x(%d+)")

	    if size_mult_k ~= nil then
		size = size * 1024
	    end
	    if size_mult_m ~= nil then
		size = size * 1024 * 1024
	    end
	    set_mailmessage_size(pstate,i+nmesg_old,size)
	    set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
	end

	return true,nil
    end

    -- check must control if we are not in the last page and
    -- eventually change uri to tell retrieve_f the next page to retrieve
    local function check_f (s)
	log.dbg("function check_f entered\n")

	local _,_,next_uri = string.find(s,internalState.strNextPage)
	if next_uri ~= nil then
	    -- change retrieve behavior
	    uri = "http://" .. browser:wherearewe() .. next_uri
	    -- continue the loop
	    return false
	else
	    return true
	end
    end

    -- this is simple and uri-dependent
    local function retrieve_f ()
	log.dbg("function retrieve_f entered\n")

	local file,err = browser:get_uri(uri)

	if file == nil then
	    return file,err
	end

	if string.find(file, globals.strLoginPage) ~= nil then
	    internalState.login_done = false
	    session.remove(hash())
	    local rc = inbox_login()
	    if rc ~= POPSERVER_ERR_OK then
		return nil,"Session ended,unable to recover"
	    end

	    browser = internalState.browser
	    file,err = browser:get_uri(uri)
	end
	return file,err
    end

    -- initialize the data structure
    set_popstate_nummesg(pstate,0)

    -- do it
    if not support.do_until(retrieve_f,check_f,action_f) then
	log.error_print("Stat failed\n")
	session.remove(hash())
	return POPSERVER_ERR_UNKNOWN
    end

    -- flag it done
    internalState.stat_done = true
    return POPSERVER_ERR_OK

end

-- -------------------------------------------------------------------------- --
-- Fill msg uidl field
function uidl(pstate,msg)
    log.dbg("function uidl entered\n")

    return common.uidl(pstate,msg)
end

-- -------------------------------------------------------------------------- --
-- Fill all messages uidl field
function uidl_all(pstate)
    log.dbg("function uidl_all entered\n")

    return common.uidl_all(pstate)
end

-- -------------------------------------------------------------------------- --
-- Fill msg size
function list(pstate,msg)
    log.dbg("function list entered\n")

    return common.list(pstate,msg)
end

-- -------------------------------------------------------------------------- --
-- Fill all messages size
function list_all(pstate)
    log.dbg("function list_all entered\n")

    return common.list_all(pstate)
end

-- -------------------------------------------------------------------------- --
-- Unflag each message merked for deletion
function rset(pstate)
    log.dbg("function rset entered\n")

    return common.rset(pstate)
end

-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
function dele(pstate,msg)
    log.dbg("function dele entered\n")

    return common.dele(pstate,msg)
end

-- -------------------------------------------------------------------------- --
-- Do nothing
function noop(pstate)
    log.dbg("function noop entered\n")

    return common.noop(pstate)
end

-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
--
function top(pstate, msg, nLines, data)
    log.dbg("function top entered\n")

    downloadMsg(pstate, msg, nLines, data)
    return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Retrieve the message
--
function retr(pstate, msg, data)
    log.dbg("function retr entered\n")

    downloadMsg(pstate, msg, -2, data)
    return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
