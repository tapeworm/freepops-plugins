-- ************************************************************************** --
--  FreePOPs @monitor webmail interface
-- 
--  $Id$
-- 
--  Released under the GNU/GPL license
--  Written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.1"
PLUGIN_NAME = "monitor"
PLUGIN_REQUIRE_VERSION = "0.2.6"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org"
PLUGIN_HOMEPAGE = "http://www.freepops.org/download.php?module=monitor.lua"
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge@users.sourceforge.net"}
PLUGIN_DOMAINS = {"@monitor"}
PLUGIN_REGEXES = {}
PLUGIN_PARAMETERS = { 
	{name="command", 
	 description={en="one of: stats"}},
}
PLUGIN_DESCRIPTIONS = {
	en=[[Monitors the internal state and statistics of freepops]]
}

internal_state = {
	stat_done = false,
	username=nil,
}

function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	require("stats")
	require("stringhack")
	require("common")
	
	-- checks on globals
	freepops.set_sanity_checks()
		
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
	internal_state.username = username
	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	local pwd = os.getenv("FREEPOPSLUA_STATS_PWD")

	if pwd ~= nil then
		if password == pwd then 
			return POPSERVER_ERR_OK 
		else 
			return POPSERVER_ERR_AUTH
		end
	end

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

function uidl(pstate,msg)
        return common.uidl(pstate,msg)
end
function uidl_all(pstate)
        return common.uidl_all(pstate)
end
function list(pstate,msg)
        return common.list(pstate,msg)
end
function list_all(pstate)
        return common.list_all(pstate)
end
function rset(pstate)
        return common.rset(pstate)
end
function dele(pstate,msg)
        return common.dele(pstate,msg)
end
function noop(pstate)
        return common.noop(pstate)
end
function stat(pstate)
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	else
		local d = os.date("*t")
		set_popstate_nummesg(pstate,1)
		set_mailmessage_size(pstate,1,100)
		set_mailmessage_uidl(pstate,1,
			d.year..d.month..d.day..d.hour..d.min..d.sec)
	end
	return POPSERVER_ERR_OK
end

function top(pstate,msg,lines,pdata)
	return retr(pstate,msg,pdata)
end

function retr(pstate,msg,pdata)
	local a = stringhack.new()
	local function send(s) 
		s = a:dothack(s).."\0"
		popserver_callback(s,pdata)
	end
	send("Date: "..os.date().."\r\n")
	send("Subject: FreePOPs monitor report\r\n")
	send("From: freepops@monitor\r\n")
	send("To: "..freepops.get_name(internal_state.username).."@"..
		freepops.get_domain(internal_state.username).."\r\n")
	send("\r\n")

	local args = freepops.get_args(internal_state.username)

	if args['command'] == 'stats' then
		local t = {}
		for name in pairs(stats) do table.insert(t,name) end
		table.sort(t)
		for _,name in ipairs(t) do
			if name == "session_err" then
			  -- really ugly and strong assumptions
			  -- over POPSERVER_* representation in lua (int)
			  local errs = {
			    --["POPSERVER_ERR_OK"]=POPSERVER_ERR_OK,
			    --["POPSERVER_ERR_SYNTAX"]=POPSERVER_ERR_SYNTAX,
			    ["POPSERVER_ERR_NETWORK"]=POPSERVER_ERR_NETWORK,
			    ["POPSERVER_ERR_AUTH"]=POPSERVER_ERR_AUTH,
			    ["POPSERVER_ERR_INTERNAL"]=POPSERVER_ERR_INTERNAL,
			    --["POPSERVER_ERR_NOMSG"]=POPSERVER_ERR_NOMSG,
			    ["POPSERVER_ERR_LOCKED"]=POPSERVER_ERR_LOCKED,
			    --["POPSERVER_ERR_EOF"]=POPSERVER_ERR_EOF,	
			    --["POPSERVER_ERR_TOOFAST"]=POPSERVER_ERR_TOOFAST,
			    ["POPSERVER_ERR_UNKNOWN"]=POPSERVER_ERR_UNKNOWN,
			  }
			  local errs_k = {}
			  for name in pairs(errs) do 
				  table.insert(errs_k,name) 
			  end
			  table.sort(errs_k)
			  for _,v in ipairs(errs_k) do
			  	send(name..": "..v..": "..
			  		stats["session_err"](errs[v])..'\r\n')
			end

			else
				send(name..": "..stats[name]().."\r\n")
			end
		end
		send('\r\n')
		send('Derived data:\r\n')
		send(' Connections refused because of no threads left: '..
			stats['connection_established']() -
			stats['session_created']() ..'\r\n')
		send(' Connections per account (approx, cookies based): '..
			stats['session_created']() /
			math.max(stats['cookies'](),1)..'\r\n')
	else
		send("Unsupported command:"..(args['command'] or "nil")..'\r\n')
		send("Sample username: foo@monitor?command=cmd&params=prms\r\n")
		send("Supported commands:\r\n")
		send("\tstats (no params)\r\n")
	end

	return POPSERVER_ERR_OK
end

-- ====================================================================== --
--                                  COMMAND LINE CLIENT
-- ====================================================================== --

function assert_ok(s,ifnot)
	if (not(string.match(s or "","^+OK"))) then
		print(s)
		print("Command failed: "..ifnot)
		os.exit(1)
	end
end

function main(args)
	require "psock"
	require "stringhack"
	require "stats"

	local host = args[1] or "localhost"
	local port = args[2] or 2000
	local pwd = args[3] or "no_pwd_set"
	local command = args[4] or "help"

	if command == "help" then
		print("usage: freepopsd -e monitor host port pwd command")
		print()
		print("defaults are host=localhost port=2000 command=help")
		print()
		print("commands are:")
		print("\tstats")
		return 1
	end

	s = psock.connect(host,port,psock.NONE)
	if s == nil then
		print("Error connecting to "..host.." port "..port)
		return 1
	end
	assert_ok(s:recv(), "")
	s:send("user user@monitor?command="..command)
	assert_ok(s:recv(), "user")
	s:send("pass "..pwd)
	assert_ok(s:recv(), "pass")
	s:send("retr 1")
	assert_ok(s:recv(), "retr")

	local lines = function() return s:recv() end

	for l in lines do
		if l == "." then
			s:send("quit")
			assert_ok(s:recv() ,"Failed 'quit'") 
			break
		end
		print(l)
	end

	return 0
end
