-- ************************************************************************** --
--  FreePOPs pop3 forwarding plugin
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
--  Written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.5"
PLUGIN_NAME = "POPforward"
PLUGIN_REQUIRE_VERSION = "0.2.7"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=popforward.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@..."}
PLUGIN_PARAMETERS = {
	{name = "realusername", description = {
		it = [[Se lanci il plugin con username foo@popforward.lua hai bisogno di questo per scegliere lo username reale]],
		en = [[If you start the plugin with the username foo@popforward.lua then you need this option to set the real username]],}	
	},
	{name = "host", description = {
		it = [[L'hostname del server POP3 a cui connetterti, puoi anche specificare la porta separandola con :. Esempio: 'in.virgilio.it:110'.If host is a lua function (you can set that changing the config.lua file but not on the fly) it is called with the username and should return both host and port.]],
		en = [[The POP3 server hostname. You can specify the port in the hostname:portnumber way. If host is a lua function (you can set that changing the config.lua file but not on the fly) it is called with the username and should return both host and port.]],}	
	},
	{name = "port", description = {
		it = [[Per specificare la porta dell'host a cui connettersi, se non gia' specificato in host con i :]],
		en = [[To choose to server port to connect to. Use this if you have not specifyed the port in the host parameter.]],}	
	},
	{name = "pipe", description = {
		en = [[Pipe the messages to the specified command before passing them to the mail client. Example: '/usr/bin/spamc -t 10']],
		it = [[Filtra il messaggio con il comando specificato prima di passarlo al client. Esempio: '/usr/bin/spamc -t 10']],}	
	},
	{name = "pipe_limit", description = {
		it = [[Limita i messaggi filtrati a quelli la cui dimensione e' minore di quelle specificata. Con 0 li filtra tutti. Default: 0. ]],
		en = [[Limit the maximum size of piped messages, the default (0) is to pipe all of them.]],}	
	},
}
PLUGIN_DESCRIPTIONS = {
	it=[[Questo e' un proxy POP3. Leggi i parametri per conoscere le 
feature di cui dispone]],
	en=[[This is a POP3 proxy. Read the parameters to know the additional features]]
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

pf_state = {
	socket = nil,
	pipe = nil,
	pipe_limit = 0,
	listed = false,
	stat_done = false,
	is_freepops = false,
}

-- ************************************************************************** --
--  helpers
-- ************************************************************************** --

-- this should be kept in sync with the pop3 server
-- initialized by init()
freepops_pop3_errors = {}

-- ask for command and call f on the result
function single_line(cmd,f)
	local l
	if pf_state.socket ~= nil then
		l = pf_state.socket:send(cmd)
	else 
		l = -1
	end
	
	if l < 0 then 
		log.error_print("Short send of "..l..
			" instead of "..string.len(cmd).."\n")
		return POPSERVER_ERR_NETWORK 
	end

	local l = pf_state.socket:recv() or "-ERR network error"
	if not (string.find(l,"^+OK")) then 
		log.error_print(l)
		if pf_state.is_freepops then
			return freepops_pop3_errors[l] or POPSERVER_ERR_UNKNOWN
		else
			return POPSERVER_ERR_UNKNOWN 
		end
	end

	if f then
		return f(l)
	else
		return POPSERVER_ERR_OK
	end
end

-- pass all to the client until the ".\r\n" is reached
function do_pipe(pdata)
	return function(s)
	local l = nil
	
	while l ~= "." do
		l = pf_state.socket:recv()
		if not l then 
			log.error_print("ERROR??")
			return POPSERVER_ERR_NETWORK 
		end
		
		if l ~= "." then
			popserver_callback(l.."\r\n",pdata)
		end
	end
	return POPSERVER_ERR_OK
	end
end

-- generates a function that repeats f on each line until "." ir reached
function do_repeat(f)
	return function(s)
	local l = nil
	
	while l ~= "." do
		l = pf_state.socket:recv()
		if not l then 
			log.error_print("ERROR?")
			return POPSERVER_ERR_NETWORK 
		end
		
		if l ~= "." then
			f(l)
		end
	end
	return POPSERVER_ERR_OK
	end
end

-- spluits a string "aaa bb cccc" in a table {"aaa","bb","cccc"}
-- usefull for the piping feature
local function pipe_split(s)
	if type(s) == "table" then
		return s
	elseif type(s) == "nil" then
		return nil
	else
		local t = {}
		for x in string.gfind(s,"([^ ]+)") do
			table.insert(t,x)
		end
		return t
	end
end

-- ensure that stat is called
local function ensure_stat(pstate)
	if pf_state.stat_done then
		return POPSERVER_ERR_OK
	end

	return stat(pstate)
end

-- ensure we know all the messages size
local function ensure_list_all(pstate)
	if pf_state.listed then
		return POPSERVER_ERR_OK
	end

	return list_all(pstate)
end

-- ************************************************************************** --
--  here we are!
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)

	pf_state.pipe = pipe_split(freepops.MODULE_ARGS.pipe)
	pf_state.pipe_limit = freepops.MODULE_ARGS.pipe_limit or 0
	pf_state.pipe_limit = tonumber(pf_state.pipe_limit)

	-- sanity checks
	if freepops.MODULE_ARGS.host == nil then
		log.error_print("host must be non null")
		return POPSERVER_ERR_AUTH
	end
	
	local host,port
	if type(freepops.MODULE_ARGS.host) == "string" then
		host,port = string.match(freepops.MODULE_ARGS.host,"(.*):(%d+)")
	elseif type(freepops.MODULE_ARGS.host) == "function" then
	        host,port = freepops.MODULE_ARGS.host(username)
	end
	if host == nil then
		host = freepops.MODULE_ARGS.host
	end
	if port ~= nil and freepops.MODULE_ARGS.port ~= nil then
		log.error_print("you should use host:port or set "..
			"explicity the port, but not both")
		return POPSERVER_ERR_AUTH
	end
	if port == nil and freepops.MODULE_ARGS.port == nil then
		log.error_print("you should use host:port or set "..
			"explicity the port")
		return POPSERVER_ERR_AUTH
	end
	port = port or freepops.MODULE_ARGS.port

	--here we are
	pf_state.socket = psock.connect(host,port,false)
	if not pf_state.socket then
		log.error_print("unable to connect")
		return POPSERVER_ERR_NETWORK
	end
	
	local l = nil
	l = pf_state.socket:recv()
	if not l then
		log.error_print("Error receiving the welcome")
		return POPSERVER_ERR_NETWORK
	end
	
	pf_state.is_freepops = string.match(l,'^+OK FreePOPs')

	return single_line("USER "..
		(freepops.MODULE_ARGS.realusername or username),nil)
end

-- Must login
function pass(pstate,password)
	return single_line("PASS "..password,nil)
end

-- Must quit without updating
function quit(pstate)
	local rc = single_line("QUIT",nil)
	return rc
end

-- Update the mailbox status and quit
function quit_update(pstate)
	return quit(pstate)
end


-- Fill the number of messages and their size
function stat(pstate)
	local f = function(l)
		for n,s in string.gfind(l,"+OK (%d+) (%d+)") do
			set_popstate_nummesg(pstate,n)
			set_popstate_boxsize(pstate,s)
			return POPSERVER_ERR_OK
		end
		log.dbg("Ubale to find +OK in "..l.."\n")
		return POPSERVER_ERR_UNKNOWN
	end

	pf_state.stat_done = true
	
	return single_line("STAT",f)
end

-- Fill msg uidl field
function uidl(pstate,msg)
	local rc = ensure_stat(pstate) 
	if rc ~= POPSERVER_ERR_OK then return rc end
	
	local f = function(l)
		for n,u in string.gfind(l,"+OK (%d+) (%d+)") do
			set_mailmessage_uidl(pstate,n,u)
			return POPSERVER_ERR_OK
		end
		return POPSERVER_ERR_UNKNOWN
	end

	return single_line("UIDL "..msg,f)
end

-- Fill all messages uidl field
function uidl_all(pstate)
	local rc = ensure_stat(pstate) 
	if rc ~= POPSERVER_ERR_OK then return rc end

	local f = do_repeat(function(l)
		for n,u in string.gfind(l,"(%d+) (%d+)") do
			set_mailmessage_uidl(pstate,n,u)
			print(l)
		end
		end)

	return single_line("UIDL",f)
end

-- Fill msg size
function list(pstate,msg)
	local rc = ensure_stat(pstate) 
	if rc ~= POPSERVER_ERR_OK then return rc end

	local f = function(l)
		for n,u in string.gfind(l,"+OK (%d+) (%d+)") do
			set_mailmessage_size(pstate,n,u)
			return POPSERVER_ERR_OK
		end
		return POPSERVER_ERR_UNKNOWN
	end

	return single_line("LIST "..msg,f)
end

-- Fill all messages size
function list_all(pstate)
	local rc = ensure_stat(pstate) 
	if rc ~= POPSERVER_ERR_OK then return rc end

	local f = do_repeat(function(l)
		for n,u in string.gfind(l,"(%d+) (%d+)") do
			set_mailmessage_size(pstate,n,u)
		end
		end)

	pf_state.listed = true
		
	return single_line("LIST",f)
end

-- Unflag each message merked for deletion
function rset(pstate)
	local rc = ensure_stat(pstate) 
	if rc ~= POPSERVER_ERR_OK then return rc end

	return single_line("RSET",nil)
end

-- Mark msg for deletion
function dele(pstate,msg)
	return single_line("DELE "..msg,nil)
end

-- Do nothing
function noop(pstate)
	return single_line("NOOP",nil)
end

-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,pdata)
	return single_line("TOP "..msg.." "..lines,do_pipe(pdata))
end

-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)
	if pf_state.pipe ~= nil then
		if pf_state.pipe_limit ~= 0 then
			ensure_list_all(pstate)
		end
		local size = get_mailmessage_size(pstate,msg)
		if pf_state.pipe_limit == 0 or size < pf_state.pipe_limit then
			-- fetch the message
			local m = {}
			local f = do_repeat(function(l)
				table.insert(m,l)
			end)
			local rc = single_line("RETR "..msg,f)
			if rc ~= POPSERVER_ERR_OK then
				-- fixme
			end
			m = table.concat(m,"\r\n") .. "\r\n"
			-- pipe it 
			local r,w = io.dpopen(unpack(pf_state.pipe))
			if r == nil or w == nil then
				--fixme
			end
			w:write(m)
			w:close()
			-- read it back
			m = r:read("*a")
			r:close()
			-- send it 
			popserver_callback(m,pdata)
			
			return POPSERVER_ERR_OK
		else
			-- too big
			return single_line("RETR "..msg,do_pipe(pdata))
		end
	else
		-- no pipe asked
		return single_line("RETR "..msg,do_pipe(pdata))
	end
end

-- Is called to initialize the module
function init(pstate)
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")
		
	freepops.export(pop3server)
	require "psock"
	
	-- checks on globals
	freepops.set_sanity_checks()

	-- initilize freepops_pop3_errors 
	freepops_pop3_errors = {
        	["-ERR SYNTAX ERROR"] = POPSERVER_ERR_SYNTAX,
        	["-ERR NETWORK ERROR"] = POPSERVER_ERR_NETWORK,
        	["-ERR AUTH FAILED"] = POPSERVER_ERR_AUTH,
        	["-ERR INTERNAL ERROR"] = POPSERVER_ERR_INTERNAL,
        	["-ERR NO SUCH MESSAGE"] = POPSERVER_ERR_NOMSG,
        	["-ERR MAILBOX LOCKED"] = POPSERVER_ERR_LOCKED,
        	["-ERR INTERNAL: END OF STREAM"] = POPSERVER_ERR_EOF,
        	["-ERR DELAY TIME NOT EXPIRED, RETRY LATER"] = POPSERVER_ERR_TOOFAST,
        	["-ERR UNKNOWN ERROR, PLEASE FIX"] = POPSERVER_ERR_UNKNOWN
	}

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
