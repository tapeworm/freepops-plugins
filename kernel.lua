-- ************************************************************************** --
--  FreePOPs kernel.org changelog plugin
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Simone Vellei <simone_vellei@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.4"
PLUGIN_NAME = "kernel.org Changelog viewer"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=kernel.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Simone Vellei"}
PLUGIN_AUTHORS_CONTACTS = {"simone_vellei (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@kernel.org","@kernel.org.24","@kernel.org.26"}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it=[[
Questo &egrave; un plugin specializzato per tenersi
aggiornati sulle ultime versioni
del kernel Linux. La pagina ufficiale che pubblica la lista delle versioni
correnti del kernel Linux &egrave; http://kernel.org. Esiste un metodo comune,
per i progetti sviluppati in sistemi GNU, per aggiornare l' utente 
sulle modifiche effettuate nelle nuove versioni di un programma. 
In ogni pacchetto &egrave; infatti presente il file ChangeLog che descrive le 
novit&agrave; apportate dagli autori. Anche
il kernel Linux ha un ChangeLog per ogni versione nuova. Se desideri essere
aggior nato sulle novit&agrave; apportate nelle versioni del kernel e,
quindi, visionare il
ChangeLog, puoi utilizzare questo plugin. Sar&agrave; sufficiente 
inserire come nome
utente qualcosa@kernel.org per essere aggiornato, tramite ChangeLog, su
ogni nuova versione, oppure qualcosa@kernel.org.24 o qualcosa@kernel.org.26
per visualizzare nella propria mailbox, rispettivamente, i ChangeLog
dell'ultima versione del ramo 2.4 e del 2.6. Come password &egrave;
possibile inserire una qualsiasi stringa casuale.]],
	en=[[
This plugin helps in staying up to date with the Linux kernel
releases. http://kernel.org
is the official page with the Linux kernel releases, each with its ChangeLog.
You should use something@kernel.org to receive news about every tree, 
something@kernel.24 or something@kernel.org.26 for a specific tree. 
Password is not used, type a random string.]]
}


-- Configuration:
--
-- Username must be ".....@kernel.org"
--

-- ************************************************************************** --
--  strings
-- ************************************************************************** --

-- Some of them are incomplete, in the sense that are used as string.format()
-- (read sprintf) arguments, so their %s and %d are filled properly
-- 
-- C, E, G are postfix respectively to Captures (lua string pcre-style 
-- expressions), mlex expressions, mlex get expressions.
-- 

local kernel_html
local string_type

local kernel_string = {
	linkE24 =
		"</b>.*</td>.*<td>.*</td>.*"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]<a.*2.4.[[:digit:]]+\">Changelog</a></td>",
	linkE26 =
		"</b>.*</td>.*<td>.*</td>.*"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]<a.*2.6.[[:digit:]]+\">Changelog</a></td>",
	linkE =
		"</b>.*</td>.*<td>.*</td>.*"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]{a.*}.*{/a}[.*]</td>"..
		"<td>[.*]<a.*>Changelog</a></td>",
	linkG = 
		"<O>O<O>O<O>X<O>O"..
		"<O>[O]{O}O{O}[O]<O>"..
		"<O>[O]{O}O{O}[O]<O>"..
		"<O>[O]{O}O{O}[O]<O>"..
		"<O>[O]{O}O{O}[O]<O>"..
		"<O>[O]<X>O<O><O>",
}


-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
stat_done = false,
login_done = false,
domain = nil,
name = nil,
password = nil,
b = nil
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Extracts the account name of a mailaddress
--
function get_name(s)
	local d = string.match(s,"([_%.%a%d]+)@[_%.%a%d]+")
	return d
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Build a mail header date string
--
function build_date(str)
	return(os.date("%a, %d %b %Y %H:%M:%S",str))
	
end

--------------------------------------------------------------------------------
-- Build a mail header
--
function build_mail_header(title,uidl)
	return 
	"Message-Id: <"..uidl..">\r\n"..
	"To: "..internal_state.name.."@kernel.org\r\n"..
	"Date: "..build_date(uidl).."\r\n"..
	"Subject: "..title.."\r\n"..
	"From: freepops@kernel.org\r\n"..
	"User-Agent: freepops "..PLUGIN_NAME..
	" plugin "..PLUGIN_VERSION.."\r\n"..
	"MIME-Version: 1.0\r\n"..
	"Content-Disposition: inline\r\n"..
	"Content-Type: text/plain;   charset=\"iso-8859-1\"\r\n"..
	"\r\n"
end

--------------------------------------------------------------------------------
-- retr and top aree too similar. discrimitaes only if lines ~= nil
--
function retr_or_top(pstate,msg,data,lines)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	local uidl = get_mailmessage_uidl(pstate,msg)
	
	local b = internal_state.b
	local uri=string.match(uidl,"UTC(.*)")
	uidl=string.gsub(uidl,uri,"")
	--yyyy-mm-dd hh:mm
	--mm/dd/yyyy hh:mm:ss 
	local year=string.match(uidl,"(%d*)%-")
	local month=string.match(uidl,year.."%-(%d*)%-")
	local day=string.match(uidl,year.."%-"..month.."%-(%d*)")
	local hour=string.match(uidl,day.." (%d*):")
	local mins=string.match(uidl,hour..":(%d*)")
	local dd=month.."/"..day.."/"..year.." "                           
	..hour..":"..mins..":00"
	
	dd=getdate.toint(dd)
	
	local body = b:get_uri(uri)

	if body == nil then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.error.."\n")
		return POPSERVER_ERR_NETWORK
	end
									

	--build it
	local title=string.match(uri,".*/(.*)")
	local s = build_mail_header(title,dd) .. 
		body.. "\r\n"

	--hack it
	local a = stringhack.new()
	if lines ~= nil then
		s = a:tophack(s,lines)
	end
	s = a:dothack(s,a)
	
	--end it
	s = s .. "\0"
		
	--send it
	popserver_callback(s,data)
	
	return POPSERVER_ERR_OK
end

-- ************************************************************************** --
--  kernel.lua functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract username
	local name = get_name(username)

	-- save name
	internal_state.name = name

	if(name == "linux24") then
		string_type = kernel_string.linkE24
	elseif (name == "linux26") then
		string_type = kernel_string.linkE26
	else
		string_type = kernel_string.linkE
	end	
		
		
		
	
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- save the password
	if (freepops.MODULE_ARGS ~= nil) then
	if (freepops.MODULE_ARGS.host ~= nil) then
	log.say("ARGS "..freepops.MODULE_ARGS.host)
		if(freepops.MODULE_ARGS.host == "24") then
			string_type = kernel_string.linkE24
		elseif (freepops.MODULE_ARGS.host == "26") then
			string_type = kernel_string.linkE26
		end
	end
	end

	internal_state.password = "http://kernel.org"
						
	-- build the uri
	local user = internal_state.name
	
	-- the browser must be preserved
	internal_state.b = browser.new()
--	b:verbose_mode()
	
	internal_state.login_done = true
	
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

	-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end
	
	-- shorten names, not really important
	local b = internal_state.b

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later
	local uri = internal_state.password
	
	
	-- extract all the messages uidl
	local function action_f (s) 
		--	
		-- sets global var rss
		kernel_html=s

		s=string.gsub(kernel_html,
		"<td>&nbsp;","<td><a href=\"#\">void</a>")
		local a=0
		local start=0
		local nmess=0
		local x = mlex.match(s,string_type,kernel_string.linkG)
			
		local n=x:count()

		nmess=n
		--nmess=1	
		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		set_popstate_nummesg(pstate,nmess)
		

		-- gets all the results and puts them in the popstate structure
		local s2=s
		local starts2
		local ends2
		for i = 1,n do
			local strtmp1=string.gsub(x:get(0,i-1),"\n","")
			local strtmp2=string.gsub(x:get(1,i-1),"a href=","")
			strtmp2=string.gsub(strtmp2,"\"","")
			strtmp2="http://kernel.org"..strtmp2
			local strtmp=strtmp1..strtmp2
			
			
			local uidl = strtmp
			local b = internal_state.b
			local header=b:get_head(strtmp2)
			local size=string.match(header,
				"Content--Length: (%d*)");

			if not uidl or not size then
				return nil,"Unable to parse uidl"
			end

			-- set it
			set_mailmessage_size(pstate,i,size)
			set_mailmessage_uidl(pstate,i,uidl)
		end
		
		return true,nil
	end

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local  check_f = support.check_fail

	-- this is simple 
	local retrive_f = support.do_retrive(b,uri)

	-- this to initialize the data structure
	set_popstate_nummesg(pstate,0)

	-- do it
	if not support.do_until(retrive_f,check_f,action_f) then
		log.error_print("Stat failed\n")
		return POPSERVER_ERR_UNKNOWN
	end

	-- save the computed values
	internal_state["stat_done"] = true
	
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
-- Do nothing
function noop(pstate)
	return common.noop(pstate)
end

-- -------------------------------------------------------------------------- --
-- Unflag each message merked for deletion
function rset(pstate)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Mark msg for deletion
function dele(pstate,msg)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get first lines message msg lines, must call 
-- popserver_callback to send the data
function retr(pstate,msg,data)
	return retr_or_top(pstate,msg,data)
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	return retr_or_top(pstate,msg,data,lines)
end

-- -------------------------------------------------------------------------- --
--  This function is called to initialize the plugin.
--  Since we need to use the browser we have to use
--  some modules with the dofile function
--
--  We also exports the pop3server.* names to global environment so we can
--  write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
--  
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the browser module
	require("browser")
	
	-- the common implementation module
	require("common")
	
	-- checks on globals
	freepops.set_sanity_checks()

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
