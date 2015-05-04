-- ************************************************************************** --
--  FreePOPs mbox reading interface
-- 
--  Released under the GNU/GPL license
--  Written by Matt Gruskin <mgruskin@seas.upenn.edu>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.1"
PLUGIN_NAME = "mbox"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=mbox.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/download.php?contrib=mbox.lua"
PLUGIN_AUTHORS_NAMES = {"Matt Gruskin"}
PLUGIN_AUTHORS_CONTACTS = {"mgruskin@seas.upenn.edu"}
PLUGIN_DOMAINS = {"@mbox.xx"}
PLUGIN_REGEXES = {}
PLUGIN_PARAMETERS = { 
	{name="file", 
	 description={en="path to mbox file",it=="---desc-it---"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[---desc-it---]],
	en=[[
This plugin creates a POP3 server which serves the mail from a Mozilla 
Thunderbird style mbox file. It could be useful if you are moving old mail from
Thunderbird to a program that does not support importing mbox files - you could
point the program to freepops and download all your old mail. This plugin is
barely tested and many things are unimplemented, so good luck.

The mbox file to read mail from is specified by the 'file' argument. You should
log in with the username 'start@mbox.xx', where start is the mail number to
start at. The password should be the number of mails to read. I added these
start and limit parameters because I was using a really huge mbox file and it
was taking too long to load the whole thing, so I imported my mail in batches.
]]
}

int_st = {
	messages = {},
	num_messages = 0,
	sizes = {},
	statted = false,
	skip = 0
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
	--require("serial")
	--	return POPSERVER_ERR_UNKNOWN 
	--end 

	-- the browser module
	--require("browser")
	--	return POPSERVER_ERR_UNKNOWN 
	--end
	
	require("common")
	
	-- checks on globals
	freepops.set_sanity_checks()		
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
	
	-- this could probably be smarter to strip off whatever is after the @
	-- so that it would not require mbox.xx
	local s = string.gsub(username,"@mbox.xx","")
	int_st.skip = tonumber(s)

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)

	local msgmax = tonumber(password)

	-- load up mbox file
	log.dbg("starting mbox read of " .. freepops.MODULE_ARGS.file)
	io.input(freepops.MODULE_ARGS.file)
	
	local skip = int_st.skip
	log.dbg("skipping " .. skip .. " messages")
	local count = 0
	local line = ""
	while count < skip do
		line = io.read()
		local i = 0
		local j = 0
		i, j = string.find(line,"From %-")
		if (i == 1) and (j == 6) then count = count + 1 end
	end
	if count > 0 then
		int_st.num_messages = 1
		int_st.messages[int_st.num_messages] = line .. "\n"
		int_st.sizes[int_st.num_messages] = string.len(line) + 1
	end
	
	while true do
		line = io.read()
		if line == nil then break end
		local i = 0
		local j = 0
		
		-- huge messages just take too long and I didn't care to have
		-- them intact so I truncated them. You probably want to
		-- comment this out if you have big messages. Or adding a
		-- max message size argument could be nice.
		if int_st.num_messages ~= 0 and int_st.sizes[int_st.num_messages] > 65536 then			
			i, j = string.find(line,"From %-")
			while not (i==1 and j==6)  do
				line = io.read()
				i, j = string.find(line,"From %-")
			end
		end
				
		i, j = string.find(line,"From %-")
		--if j == nil then j = -1 end
		--if i == nil then i = -1 end
		--log.dbg(line .. "  i " .. i .. "  j " .. j)
		if (i == 1) and (j == 6) then 
			int_st.num_messages = int_st.num_messages + 1
			if int_st.num_messages > msgmax then
				int_st.num_messages = msgmax
				break
			end
		end
		if int_st.messages[int_st.num_messages] == nil then
			int_st.messages[int_st.num_messages] = line .. "\n"
			int_st.sizes[int_st.num_messages] = string.len(line) + 1
		else
			int_st.messages[int_st.num_messages] = int_st.messages[int_st.num_messages] .. line .. "\n"
			int_st.sizes[int_st.num_messages] = int_st.sizes[int_st.num_messages] + string.len(line) + 1			
		end
	end
	log.dbg("finished mbox read of " .. int_st.num_messages .. " messages")

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must quit without updating
function quit(pstate)
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Update the mailbox status and quit
function quit_update(pstate)
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)
	log.dbg("running stat")
	set_popstate_nummesg(pstate,int_st.num_messages)
	
	for i=1,int_st.num_messages do
		set_mailmessage_size(pstate,i,int_st.sizes[i])
		set_mailmessage_uidl(pstate,i,i)
	end
	
	int_st.statted = true
	
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
-- Unflag each message merked for deletion
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
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
	if int_st.statted == false then
		stat(pstate)
	end
	local msgnum = tonumber(get_mailmessage_uidl(pstate,msg))
	local a = stringhack.new()
	local s = a:dothack(int_st.messages[msgnum]) .. "\0"
	popserver_callback(s,pdata)
	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
