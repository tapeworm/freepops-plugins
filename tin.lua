-- ************************************************************************** --
--  FreePOPs @virgilio.it, @tin.it webmail interface
--  
--  Released under the GNU/GPL license
--  Originally written by Enrico Tassi <gareuselesinge@users.sourceforge.net>
-- ************************************************************************** --


-- these are used in the init function
PLUGIN_VERSION = "0.2.32"
PLUGIN_NAME = "Tin.IT"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=tin.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Enrico Tassi"}
PLUGIN_AUTHORS_CONTACTS = {"gareuselesinge (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@tin.it","@virgilio.it","@alice.it","@tim.it","@atlantide.it"}
PLUGIN_PARAMETERS = {
	{name = "folder", description = {
		it = [[
Visto che potresti aver bisogno di scaricare altre cartelle oltre alle 
INBOX (che &egrave; quella di default) il plugin accetta il parametro folder. 
Ecco un esempio di user name per controllare la 
cartella Spam: foo@virgilio.it?folder=Spam]],
		}	
	},
	{name = "limit", description = {
		it = [[
    Se si hanno tante e-mail da scaricare, ad esempio a seguito di un lungo periodo
    in cui non si &egrave; pi&ugrave; scaricata la posta, si potrebbe voler decidere di scaricare
    un tot di messaggi alla volta, anche per evitare che eventuali errori di comunicazione
    in fase di scaricamento di tutti i messaggi compromettano la corretta cancellazione
    degli stessi sul server, con conseguente necessit&agrave; di riscaricarli tutti dall'inizio.
    Ad esempio, per scaricare un massimo di 100 e-mail alla volta, si pu&ograve; specificare
    come nome utente: foo@virgilio.it?limit=100 . Da notare che il limite citato &egrave;
    indicativo e che il numero esatto di e-mail effettivamente scaricate potrebbe
    essere superiore al valore specificato (dipende dal numero di messaggi per pagina da visualizzare,
    impostato nelle opzioni della webmail per la propria casella di posta).]],
		}	
	},
	{name = "webmail", description = {
		it = [[
    Se si vole si puע contribuire allo sviluppo del plugin per la nuova webmail usando il parametro new
	L'unico parametro ammesso per nuova webmail ט new 
	tutti gli altri parametri permettono l'uso della nuova webmail 
	Ad esempio, per scaricare dalla nuova webmail, si pu&ograve; specificare
    come nome utente: foo@virgilio.it?webmail=new
	]],
		}	
	},
}
PLUGIN_DESCRIPTIONS = {
	it="Questo plugin vi permette di leggere le mail che avete "..
	   "in una mailbox @virgilio.it, @tin.it, @alice.it o @tim.it. "..
	   "Per usare questo plugin dovete usare il vostro indirizzo email "..
	   "completo come username e la vostra password reale come password.",
	en="This plugin is for italian users only."
}
 require("table2xml")


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
local tin_string = {
	prelogin = "https://aaacsc.%s/piattaformaAAA/aapm/amI",
        prelogin_post = "usernameDisplay=%s&".. -- USER
                        "password=%s&".. -- PASSWORD
                        "dominio=%s&".. -- 	@DOMAIN
                        "imageField.x=35&"..
                        "imageField.y=15&"..
                        "login=%s&".. -- USER@DOMAIN
                        "pwd=%s&".. -- 	PASSWORD
                        "channel=Vmail&".. 	
                        "URL_OK=https://authsrs.alice.it/aap/aap_redir.jsp?entry=Vmail&"..
                        "URL_KO=https://authsrs.alice.it/aap/aap_redir_ko.jsp?entry=Vmail&"..
                        "servizio=mail&"..
                        "msisdn=%s&".. -- 	USER
                        "username=%s&".. -- 	USER@DOMAIN
                        "user=%s&".. -- 	USER@DOMAIN
                        "a3afep=http://mail.virgilio.it/common/iframe_mail/pf/ps/ManageCodError.html?code=470&channel=Vmail&"..
                        "DOMAIN=&"..
                        "PASS=%s&".. -- 	PASSWORD
                        "self=true&"..
                        "a3si=none&"..
                        "a3st=VCOMM&"..
                        "totop=true&"..
                        "nototopa3ep=true&"..
                        "a3aid=lvmes&"..
                        "a3flag=0&"..
                        "a3ep=http://webmail.virgilio.it/cp/ps/Main/login/SSOLogin&"..
                        "a3epvf=http://webmail.virgilio.it/cp/ps/Main/login/SSOLogin&"..
                        "a3se=http://mail.virgilio.it/common/iframe_mail/pf/ps/ManageCodError.html?code=470&channel=Vmail&"..
                        "a3dcep=http://communicator.alice.it/asp/homepage.asp?s=005&"..
                        "a3l=%s&".. -- 	USER@DOMAIN
                        "a3p=%s&", -- 	PASSWORD

	login2 = "http://webmailcommunicator.%s/cp/ps/Main/login/AAAPreLogin?d=%s&style=light&l=it",
	login2C = 'src="(/cp/ps/Mail/MailFrame[^"]*)"',
	login2Ct="&t=([^&]+)",
	login2Cs="&s=([%d]+)",
	-- mesage list mlex
	statE = ".*<tr>.*<td>.*<input>.*</td>.*<td>.*<a>.*<img>.*</a>.*</td>.*<td>.*<a>.*<img>.*</a>.*</td>.*<td>.*<a>.*<img>.*</a>.*</td>.*<td>.*<a.*>.*</a>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*</tr>",
	statG = "O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>",

	-- The uri for the first page with the list of messages
	-- parameters all %s except fi that is %d: 
	-- folder, domain, username, username, t, s, fi
	first = "http://%s/cp/ps/Mail/EmailList?"..
		"fp=%s&d=%s&an=&u=%s&t=%s&style=light"..
		"&l=it&s=%s&fi=%d&sc=&sd=",
	-- The regex that, if not found, means we are on the last stat page
	no_next = "href%s*=%s*'/cp/ps/Mail/EmailList[^']*fi=[^']*'>&gt;&gt;",
	list_href = "href%s*=%s*'/cp/ps/Mail/EmailList",
	-- The capture to understand if the session ended
	timeoutC = '(window.parent.location.*/mail/main?.*err=24)',
	
	--webmail address
	alice_webmail="webmail.communicator.alice.it",
	virgilio_webmail="webmailcommunicator.virgilio.it",
	---new webmail
	rnd="http://webmail.virgilio.it/cp/ps/Main/login/SSOLogin",
	new_webmail_login="http://webmail.virgilio.it/cp/ps/Main/login/PreLogin?u=%s&d=%s&rnd=%s",
	listC="/cp/ps/mail/SLcommands/SLEmailList.-&l=it",
	message_list="http://webmail.virgilio.it%s&start=0&limit=%s&fp=%s",
	
	-- The uri to save a message (read download the message)
	--   wherearewe(), mailbox, domain, username, username, uidl, t, s
	save = "http://%s/cp/ps/Mail/EmailSecure"..
		"?sh=&fp=%s&d=%s&sd=&sc=&an=%s&u=%s&"..
		"uid=%s&t=%s&style=light&l=it&s=%s&sl=%d",	
	save_attach = "http://%s/cp/ps/Mail/Email"..
		"?sh=&fp=%s&d=%s&sd=&sc=&an=%s&u=%s&"..
		"uid=%s&t=%s&style=&l=it&s=%s&sl=%d",	
	body_start = [[%s-</script>%s-<br>%s-<br>%s-</div>.-<table bgcolor=.?#FFFFFF.-=.?testogrigio10verdana.?>%s*]],
	body_end = [[</td></tr> %s*</table>%s*<.?.?.?.?DO NOT REMOVE THIS USED TO CALC LENGHT OF PAGE .->]],
	 attachE = ".*<a.*href='/cp/ps/Mail/ViewAttachment>.*<img>.*</a>",
	 attachG = "O<X>O<O>X<O>",
	-- by nvhs for html image
	 imageE = "<.?.?[Ii][Mm][Gg].*cp/ps/Mail/SecureViewAttachment.*>",
	 imageG = "<X>",
	-- by nvhs for attach  mail
	 mailE = ".*<a.*href *= *'/cp/ps/Mail/Email>.*<img>.*</a>",
	 mailG = "O<X>O<O>X<O>",
	-- The uri to delete some messages
	--  whearewe(), domain, user, t, s
        delete = "http://%s/cp/ps/Mail/Delete?d=%s&u=%s&t=%s&style=light&s=%s",
	-- user, folder, idx, uid
	delete_post = "an=%s&fp=%s&sl=%s&uid=%s&dellist=",
	error_title = "<title>An error has occurred</title>",


}

tin_domains = {
	["virgilio.it"] = true,
	["tin.it"] = true,
	["alice.it"] = true,
	["tim.it"] = true,
	["atlantide.it"] = true
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {
	stat_done = false,
	login_done = false,
	popserver = nil,
	session_id_s = nil,
	session_id_t = nil,
	session_id_rnd = nil,
	domain = nil,
	name = nil,
	password = nil,
	b = nil,
	folder="INBOX",
	limit=nil,
	webmail="new",
	reverse_lookup = {},
	list_begin = -1
}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

--------------------------------------------------------------------------------
-- Checks if a message number is in range
--
function check_range(pstate,msg)
	local n = get_popstate_nummesg(pstate)
	return msg >= 1 and msg <= n
end

--------------------------------------------------------------------------------
-- checks domain validity
--
function check_domain(s)
	return tin_domains[s]
end

--------------------------------------------------------------------------------
-- we don't want to break the webmail
--
function check_sanity(name,domain,pass)
	-- FIXME no domain check for subdomains of tin.it
	if string.len(name) < 3 or string.len(name) > 30 then
		log.error_print("username must be from 3 to 30 chars")
		return false
	end
	local x = string.match(name,"([^0-9a-z%.%_%-])")
	if x ~= nil then
		log.error_print("username contains invalid character "..x.."\n")
		return false
	end	
	if string.len(pass) < 4 or string.len(pass) > 24 then
		log.error_print("password must be from 4 to 24 chars")
		return false
	end
	local x = string.match(pass,"[^0-9A-Za-z%.%_%-אטילעש]")
	if x ~= nil then
		log.error_print("password contains invalid character "..x.."\n")
		return false
	end
	return true
end

function toGMT(d)
	log.say("FIXME: GMT time conversion")
	return os.date("%c",d)
end

function mk_cookie(name,val,expires,path,domain,secure)
	local s = name .. "=" .. curl.escape(val)
	if expires then
		s = s .. ";expires=" .. toGMT(expires)
	end
	if path then
		s = s .. ";path=" .. path
	end
	if domain then
		s = s .. ";domain=" .. domain
	end
	if secure then
		s = s .. ";secure"
	end
	return s
end

function asc2hex(d)
	local t = {}
	-- FIXME may be faster :)
	for i=1,string.len(d) do
		table.insert(t,string.format("%X",string.byte(d,i)))
	end
	return table.concat(t)
end

function aaa_encode(u,p,s)
	return asc2hex(curl.escape(base64.encode(u.."|"..p.."|"..s.."|")))
end

function add_webmail_in_front(s)
	if string.match(s, '^webmail') then
		return s
	else
		return "webmail."..s
	end
end

--------------------------------------------------------------------------------
-- Serialize the internal_state
--
-- serial. serialize is not enough powerfull to correcly serialize the 
-- internal state. the problem is the field b. b is an object. this means
-- that is a table (and no problem for this) that has some field that are
-- pointers to functions. this is the problem. there is no easy way for the 
-- serial module to know how to serialize this. so we call b:serialize 
-- method by hand hacking a bit on names
--
function serialize_state()
	internal_state.stat_done = false;
	internal_state.reverse_lookup = {}
	internal_state.list_begin = -1
	
	return serial.serialize("internal_state",internal_state) ..
		internal_state.b:serialize("internal_state.b")
end

--------------------------------------------------------------------------------
-- The key used to store session info
--
-- Ths key must be unique for all webmails, since the session pool is one 
-- for all the webmails
--
function key()
	return (internal_state.name or "")..
		(internal_state.domain or "")..
		(internal_state.password or "")..
		(internal_state.folder or "")
end


--------------------------------------------------------------------------------
-- Detect if the page is an error page
--
function is_an_error_page(data)
	local c = string.find(data, tin_string.error_title)
	if c == nil then
		return false
	else
		return true
	end
end

--------------------------------------------------------------------------------
-- Login to the tin website
--
function dec(s, i) 
	local tmp = base64.decode(s)
	local rc = {}
	while tmp ~= nil do
		local start, stop = string.find(tmp,"|")
		if start == nil then
			table.insert(rc,tmp)
			tmp = nil
		else
			
			table.insert(rc,string.sub(tmp,1,start-1))
			tmp = string.sub(tmp,stop+1,-1)
		end
	end
	return rc[i]
end

function hex2ascii(s)
	local tab = {
		["0"]=0;  ["1"]=1;  ["2"]=2;  ["3"]=3;
		["4"]=4;  ["5"]=5;  ["6"]=6;  ["7"]=7;
		["8"]=8;  ["9"]=9;  ["A"]=10; ["B"]=11;
		["C"]=12; ["D"]=13; ["E"]=14; ["F"]=15
	}
	s = string.upper(s)
	local rc = {}
	local i=1
	while i <= string.len(s) do
		local a = tab[string.char(string.byte(s,i))]
		local b = tab[string.char(string.byte(s,i+1))]
		if a == nil or b == nil then
			log.error_print("invalid hex")
			return ""
		end
		table.insert(rc,string.char(a*16+b))
		i = i + 2
	end
	return table.concat(rc)
end

function geta3p(b, email)
	local url, post = nil,nil
	
	local CPTX = b:get_cookie("CPTX")
	if CPTX == nil then
		log.error_print("unable to get CPTX")
		return nil
	else
		local sCPTX = curl.unescape(CPTX.value)
		sCPTX = hex2ascii(sCPTX)
		local a3p = dec(sCPTX,2);
		url = "http://aaacsc.alice.it/piattaformaAAA/controller/AuthenticationServlet"
		post=string.format("a3l=%s&a3p=%s&a3si=-1&percmig=100&a3st=VCOMM&a3aid=comhpma&a3flag=0&a3ep=http://communicator.alice.it/asp/login.asp&a3afep=http://communicator.alice.it/asp/login.asp&a3se=http://communicator.alice.it/asp/login.asp&a3dcep=http://communicator.alice.it/asp/homepage.asp?s=005",email,a3p)
	end

	
	return url, post
end

function tin_http_login()
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
	-- svrdomain will be changed later
	local svrdomain = internal_state.domain
	
	-- browser must be set to some modern one
	internal_state.b = browser.new("Mozilla/5.0")
	-- enable SSL
	internal_state.b:ssl_init_stuff()

--	if SSLEnabled then
--	   internal_state.b:ssl_init_stuff()
--	else
--	   log.dbg("Error: SSL not enabled in browser!")
--	end

        local SSLEnabled = browser.ssl_enabled()

	local b = internal_state.b
 	--b:verbose_mode()

	-- select mail server according to the mail domain
	if (domain == "virgilio.it") then
	  svrdomain = "virgilio.it"
        else
	  svrdomain = "alice.it"
        end

	-- step 0: send login data to obtain back some cookies
	local post = string.format(tin_string.prelogin_post, user, password, domain, user_at_domain, password, user, user_at_domain, user_at_domain, password, user_at_domain, password)

	local prelogin_url = string.format(tin_string.prelogin, svrdomain)
	local body, err = b:post_uri(prelogin_url, post)
	if body == nil then
		log.error_print("Error getting "..
			tin_string.prelogin..": "..err)
		return POPSERVER_ERR_AUTH
	end

	-- step 2: get session rnd ,id_s and id_t
	
	local uri=tin_string.rnd
	local body,err=b:get_uri(uri)

	if body ~= nil then
		internal_state.session_id_rnd = string.match(body, "rnd=(%d-)\"")
	end	
		
	-- id_s and id_t

	local login2_url = string.format(tin_string.login2, svrdomain, domain)
    local body, err = b:get_uri(login2_url)
	if body == nil then
		log.error_print("Error getting "..tin_string.login2..": "..err)
		return POPSERVER_ERR_AUTH
	     end

	local capt = string.match(body, tin_string.login2C)
	local t = string.match(capt, tin_string.login2Ct) 
	local s = string.match(capt, tin_string.login2Cs) 
	
	internal_state.session_id_s = s
	internal_state.session_id_t = t
		
	if internal_state.session_id_s == nil or
	   internal_state.session_id_t == nil then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end

	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. 
		"(" .. internal_state.session_id_t .. ", " .. 
			internal_state.session_id_s .. ")\n")

	return POPSERVER_ERR_OK
end

function tin_https_login()
        ----------------------------------------
        -- THIS FUNCTION IS OLD
        -- AND NEED TO BE UPDATED Or MAYBE CAN
        -- BE SIMPLY DELETED
        ----------------------------------------
	if internal_state.login_done then
		return POPSERVER_ERR_OK
	end

	-- build the uri
	local password = internal_state.password
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
	
	-- the browser must be preserved
	internal_state.b = browser.new()

	local b = internal_state.b
 	--b:verbose_mode()

	local initial_uri = "http://pf.rossoalice.alice.it/Vpf.html?"
	local body, err = b:get_uri(initial_uri)

	local post =
"usernameDisplay=" .. user .. "&password="..password.. 
"&dominio="..domain.."&imageField.x=31&imageField.y=13&"..
"login="..user_at_domain.."&pwd="..password.."&channel=Vmail&"..
"URL_OK=https%3A%2F%2Fauthsrs.alice.it%2Faap%2Faap_redir.jsp%3Fentry%3DVmail&"..
"URL_KO=https%3A%2F%2Fauthsrs.alice.it%2Faap%2Faap_redir_ko.jsp%3Fentry%3DVmail&"..
"servizio=mail&msisdn="..user.."&username="..user_at_domain.."&user="..user_at_domain..
"&a3afep=http%3A%2F%2Fportale.rossoalice.alice.it%2Fps%2FManageCodError.do%3Fcode%3D470%26channel%3DVmail&"..
"DOMAIN=&PASS="..password.."&self=true&a3si=none&a3st=VCOMM&totop=true&nototopa3ep=true&a3aid=lvmes&a3flag=0&"..
"a3ep=http%3A%2F%2Fdise.alice.it%2Fdest%2Fwebmail&"..
"a3se=http%3A%2F%2Fportale.rossoalice.alice.it%2Fps%2FManageCodError.do%3Fcode%3D470%26channel%3DVmail&"..
"a3dcep=http%3A%2F%2Fcommunicator.alice.it%2Fasp%2Fhomepage.asp%3Fs%3D005&"..
"a3l="..user_at_domain.."&a3p="..password.."&rememberUsernameChk=checkbox"

	local login_uri = "https://aaacsc.alice.it/piattaformaAAA/aapm/amI"
	local body, err = b:post_uri(login_uri, post)
	if body == nil then
		log.error_print("Error getting "..login_uri.. ": "..err)
		return POPSERVER_ERR_AUTH
	end

	-- look for redirect
	local newurl_match = "window%.[a-z%.]*%.href%s=%s\"([^\"]+)\""
	local newurl = string.match(body, newurl_match)
	if newurl == nil then 
		log.error_print("Error matching "..newurl_match)
		return POPSERVER_ERR_AUTH
	end
	
	local body, err = b:get_uri(newurl)
	if body == nil then
		log.error_print("Error getting "..newurl..": "..err)
		return POPSERVER_ERR_AUTH
	end
	local newurl = string.match(body, newurl_match)
	if newurl == nil then 
		log.error_print("Error matching "..newurl_match)
		return POPSERVER_ERR_AUTH
	end
	
	local body, err = b:get_uri(newurl)
	if body == nil then
		log.error_print("Error getting "..newurl..": "..err)
		return POPSERVER_ERR_AUTH
	end

	-- step 2: get session id_s and id_t
	local tincctoken = assert(b:get_cookie("tincctoken"),
		"unable to find cookie tincctoken").value
	local url = string.format(tin_string.login2, domain,
		curl.escape(user_at_domain), curl.unescape(tincctoken))
	local body,err = b:get_uri(url)
	if body == nil then
		log.error_print("Error getting "..url..": "..err)
		return POPSERVER_ERR_AUTH
	end
	local capt = string.match(body, tin_string.login2C)
	local t = string.match(capt, tin_string.login2Ct) 
	local s = string.match(capt, tin_string.login2Cs) 
	
	internal_state.session_id_s = s
	internal_state.session_id_t = t
	
	if internal_state.session_id_s == nil or
	   internal_state.session_id_t == nil then
		log.error_print("Login failed\n")
		return POPSERVER_ERR_AUTH
	end

	-- save all the computed data
	internal_state.login_done = true
	
	-- log the creation of a session
	log.say("Session started for " .. internal_state.name .. "@" .. 
		internal_state.domain .. 
		"(" .. internal_state.session_id_t .. ", " .. 
			internal_state.session_id_s .. ")\n")

	return POPSERVER_ERR_OK
end

function tin_login()
	local rc = tin_http_login()
	if rc ~= POPSERVER_ERR_OK then
		return tin_https_login()
	else
		return rc
	end
end
		
-- ************************************************************************** --
--  Tin functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract and check domain
	local domain = freepops.get_domain(username)
	local name = freepops.get_name(username)

	-- check if the domain is valid
	if not check_domain(domain) then
		return POPSERVER_ERR_AUTH
	end

	-- save domain and name
	internal_state.domain = domain
	internal_state.name = name
	internal_state.folder = freepops.MODULE_ARGS.folder or "INBOX"
	-- set maximun number of mail
	internal_state.limit = tonumber(freepops.MODULE_ARGS.limit) or math.huge
	-- set new or old  webmail
	internal_state.webmail = freepops.MODULE_ARGS.webmail or "old"
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
	-- save the password
	internal_state.password = password

	-- check if the domain is valid
	if not check_sanity(internal_state.name,
			internal_state.domain,
			internal_state.password) then
		return POPSERVER_ERR_AUTH
	end

	-- eventually load session
	local s = session.load_lock(key())

 	-- check if loaded properly
	if s ~= nil then
		-- "\a" means locked
		if s == "\a" then
			log.say("Session for "..internal_state.name..
				" is already locked\n")
			return POPSERVER_ERR_LOCKED
		end
	
		-- load the session
		local c,err = loadstring(s)
		if not c then
			log.error_print("Unable to load saved session: "..err)
			return tin_login()
		end
		
		-- exec the code loaded from the session tring
		c()

		log.say("Session loaded for " .. internal_state.name .. "@" .. 
			internal_state.domain .. 
			"(" .. internal_state.session_id_s .. ", " ..
			internal_state.session_id_t .. ")\n")
		
		return POPSERVER_ERR_OK
	else
		-- call the login procedure 
		return tin_login()
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
	local b = internal_state.b
	local popserver = add_webmail_in_front(b:wherearewe())
	local session_id_s = internal_state.session_id_s
	local session_id_t = internal_state.session_id_t
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
	local folder = internal_state.folder
	
	local uri = string.format(tin_string.delete, popserver, domain, 
		user, session_id_t, session_id_s)
	
	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			local uidl = get_mailmessage_uidl(pstate,i)
			local post = string.format(tin_string.delete_post,
				user, folder, i, uidl)
			local body, err = b:post_uri(uri, post)
			if body == nil then
				log.error_print("Error getting "..uri..":"..err)
				return POPSERVER_ERR_UNKNOWN
			end
		end
	end

	-- save fails if it is already saved
	session.save(key(),serialize_state(),session.OVERWRITE)
	-- unlock is useless if it have just been saved, but if we save 
	-- without overwriting the session must be unlocked manually 
	-- since it wuold fail instead overwriting
	session.unlock(key())

	log.say("Session saved for " .. internal_state.name .. "@" .. 
		internal_state.domain .. "(" .. 
		internal_state.session_id_t .. ", " .. 
		internal_state.session_id_s .. ")\n")

	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat_new(pstate)
		-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end
	-- shorten names, not really important
	local session_id_s = internal_state.session_id_s
	local session_id_t = internal_state.session_id_t
	local b = internal_state.b
	local domain = internal_state.domain
	local user = internal_state.name
	local limit=internal_state.limit
	--limit input parameter
	if limit==math.huge then limit=10000 end
	--new webmail login
	local uri= string.format(tin_string.new_webmail_login,user,domain,internal_state.session_id_rnd)
	local body,err = b:get_uri(uri)
	--get email list
	local sub_uri=string.match(body,tin_string.listC)
	if sub_uri==nil then
		return  POPSERVER_ERR_UNKNOWN 
	end
	uri=string.format(tin_string.message_list,sub_uri,limit,internal_state.folder)
	local message_l,err = b:get_uri(uri)
	--delete secondary information, take only message list
	message_l=string.match(message_l,"%s*{.-%[(.+)%]}%s*")
	--insert message in the table
	local i=1
	local mail_table= {}
	while message_l~=nil   do
		--inizialize table
		mail_table[i]= {}
		--extract first mail
		local mail=string.match(message_l,"{.-}")
		--delete first mail
		message_l=string.match(message_l,"%s*{.-}(.+)%s*")
		--exstract uid and size
		mail_table[i]["uid"]=string.match(mail,"\"uid\":\"(%d-)\"")
		mail_table[i]["size"]=tonumber(string.match(mail,"\"size\":(%d-),"))
		i=i+1
	end
	--initialize message list on pop3 server
	local n=i-1
	set_popstate_nummesg(pstate,n)
	--send message from table to pop3 server
	i=1
	while i<=n do
		set_mailmessage_size(pstate,i,mail_table[i]["size"])
		set_mailmessage_uidl(pstate,i,mail_table[i]["uid"])
		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		internal_state.reverse_lookup[mail_table[i]["uid"]] = i
		i=i+1
	end

	--return to old webmail
	internal_state.login_done=false
	tin_login()
	internal_state.stat_done=true
	return POPSERVER_ERR_OK
end

function stat_old(pstate)
	-- check if already called
	if internal_state.stat_done then
		return POPSERVER_ERR_OK
	end

	-- shorten names, not really important
	local session_id_s = internal_state.session_id_s
	local session_id_t = internal_state.session_id_t
	local b = internal_state.b
	local popserver = add_webmail_in_front(b:wherearewe())
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
        
	-- number of messages per page
	local msg_per_page = 10

	-- this string will contain the uri to get. it may be updated by 
	-- the check_f function, see later
	local page = 1
	local uri = string.format(tin_string.first,
		popserver, internal_state.folder,
		domain, user, session_id_t, session_id_s, page)
	
	-- The action for do_until
	--
	-- uses mlex to extract all the messages uidl and size
	local stop = false
	local function action_f (s) 
		-- calls match on the page s, with the mlexpressions
		-- statE and statG
		local x = mlex.match(s,tin_string.statE,tin_string.statG)
	
		--x:print()
		
		-- the number of results
		local n = x:count()
		if n < msg_per_page then 
			stop = true 
		end
		

		if n == 0 then
			return true,nil
		end 
		
		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		local nmesg_old = get_popstate_nummesg(pstate)
		local nmesg = nmesg_old + n
		set_popstate_nummesg(pstate,nmesg)

		-- gets all the results and puts them in the popstate structure
		for i = 1,n do
			local uidl = x:get (0,i-1) 
			local size = x:get (1,i-1)

			-- arrange message size
			local k,m = nil,nil
			k = string.match(size,"([Kk][Bb])")
			m = string.match(size,"([Mm][Bb])")
			size = string.match(size,"([%.%d]+)")
			uidl = string.match(uidl,"read%s*%(%s*'"..internal_state.folder.."'%s*,%s*'([%d]+)'")

			if not uidl or not size then
				return nil,"Unable to parse page"
			end

			-- arrange size
			size = tonumber(size)
			if k ~= nil then
				size = size * 1024
			elseif m ~= nil then
				size = size * 1024 * 1024
			end

			-- set it
			set_mailmessage_size(pstate,i+nmesg_old,size)
			set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
			internal_state.reverse_lookup[uidl] = i+nmesg_old
		end

		return true,nil
	end 

	-- check must control if we are not in the last page and 
	-- eventually change uri to tell retrive_f the next page to retrive
	local function next_page()
		page = page + msg_per_page
		uri = string.format(tin_string.first,
			b:wherearewe(), internal_state.folder,
			domain, user, session_id_t, session_id_s, page)
		return false
	end
	local function check_f (s)
		if get_popstate_nummesg(pstate) >= internal_state.limit then 
			-- if a limit was set, stop
			return true 
		end
		if stop then return true end
		return next_page()
	end

	-- this is simple and uri-dependent
	local function retrive_f ()  
		-- print("getting "..uri)
		local f,err = b:get_uri(uri)
		if f == nil then
			return f,err
		end
		
		local c = string.match(f,tin_string.timeoutC)
		if c ~= nil then
			internal_state.login_done = nil
			session.remove(key())

			local rc = tin_login()
			if rc ~= POPSERVER_ERR_OK then
				return nil,"Session ended,unable to recover"
			end
			
			session_id_s = internal_state.session_id_s
			session_id_t = internal_state.session_id_t
			b = internal_state.b
			-- popserver has not changed
			page = 1
			uri = string.format(tin_string.first,
				internal_state.folder,
				domain, user, session_id_t, session_id_s, page)
			return b:get_uri(uri)
		end
		
		return f,err
	end

	-- this to initialize the data structure
	set_popstate_nummesg(pstate,0)

	-- do it
	if not support.do_until(retrive_f,check_f,action_f) then
		log.error_print("Stat failed\n")
		session.remove(key())
		return POPSERVER_ERR_UNKNOWN
	end

	-- save the computed values
	internal_state["stat_done"] = true
	
	return POPSERVER_ERR_OK
end

function stat(pstate)
	if internal_state.domain =="virgilio.it" and internal_state.webmail=="new" then
		return stat_new(pstate)
	else
		return stat_old(pstate)
	end
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
-- 
--
function tin_parse_webmessage(wherearewe, data, data_attach)
	local head, body, body_html, attach ,inlineids = nil, nil, nil, {} , {}

	-- extract headers 
	local headersE = ".*<script>.*var *hd *=</script>.*<br>.*<br>.*</div>"
	local headersG = "O<O>X<O>O<O>O<O>O<O>"
	local x = mlex.match(data, headersE, headersG)
	assert(x:count() > 0,"Unable to mlex "..data )
	local headers = x:get(0,0)
	assert(headers ~= nil, "Unable to mlex " .. data)
	local head = string.match(headers, 'var%s*hd%s*=%s*"([^"]+)"%s*;')
	head = string.gsub(head, "\\n\\n", "")
	head = string.gsub(head, "\\r", "\r")
	head = string.gsub(head, "\\n", "\n")
	head = string.gsub(head, "        ", "\t")
	head = string.gsub(head, "\\&quot;", "\"")
	head = string.gsub(head, "&lt;", "<")
	head = string.gsub(head, "&gt;", ">")
	head = string.gsub(head, "\r([^\n])", 
		function(capture) return "\r\n" .. capture end)
	head = string.gsub(head, "([^\r])\n","%1\r\n")
	-- patch by galdom
	head = string.gsub(head, "\\&#39;", "'")
	head = string.gsub(head, "&amp;", "&")
	
	head=string.gsub(head,"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Rr][Aa][Nn][sS][fF][ee][Rr]%-[eE][Nn][Cc][Oo][dD][Ii][Nn][Gg].-[;\n ]","")		
	
	-- locate body
	local _, begin_body = string.find(data, tin_string.body_start)
	local end_body, _ = string.find(data, tin_string.body_end)

	-- check if it is a plain text message
	local found = string.find(head,
		"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:%s*"..
		"[Tt][Ee][Xx][Tt]/[Pp][Ll][Aa][Ii][Nn]")
	if found == nil then
		body_html = string.sub(data, begin_body + 1, end_body - 1)
		-- body_html = string.gsub(data, "</td></tr>%s*</table>%s-%s*", "")
		head = mimer.remove_lines_in_proper_mail_header(head,
			{"content%-type"})
	else
		body = string.sub(data, begin_body + 1, end_body - 1)
		body = string.gsub(body, "^%s+", "")
            body = string.gsub(body, "%s+$", "")
		body = string.gsub(body, "<br/>", "\r\n");
		body = string.gsub(body, "<a href[^>]*>", "");
		body = string.gsub(body, "</a>", "");
		body = string.gsub(body, "&lt;", "<")
		body = string.gsub(body, "&gt;", ">")
		body = string.gsub(body, "&quot;", "\"")
            body = string.gsub(body, "&#39;", "'")
            body = string.gsub(body, "&amp;", "&")
	end
	
	
	-- Added to nvhs to delete scroll bar 
	if not (body_html == nil) then 
		body_html  = string.gsub(body_html, "auto;width:570px;height", "auto;height")
		body_html  ="<html>  <body> "..body_html.."</body> </html>"
	end

	-- extract attachments
	local x = mlex.match(data_attach,tin_string.attachE,tin_string.attachG) 
	--x:print()
	for i = 1, x:count() do
		local url = x:get(0,i-1)
		local name = x:get(1,i-1)
		local name = string.match(name, "^(.*) %(")
		local url = string.match(url,
			"href%s*=%s*'(/cp/ps/Mail/ViewAttachment[^']*)'")
		attach[name] = "http://"..wherearewe..url
	end
	
	-- by nvhs extract attach mail
	
	local x = mlex.match(data_attach, tin_string.mailE, tin_string.mailG) 
	--x:print()
	for i = 1, x:count() do
		local url = x:get(0,i-1)
		local name = x:get(1,i-1)
		local name = string.match(name,"%s*%p*(.*)")
		name=name..".html"
		local url = string.match(url,
			"href%s*=%s*'(/cp/ps/Mail/Email[^']*)'")
		attach[name] = "http://"..wherearewe..url

	end

	-- by nvhs for html image
	
	local y = mlex.match(data, tin_string.imageE, tin_string.imageG)
	-- y:print()
	for i = 1, y:count() do
		local url = y:get(0,i-1)
		print(url)
		url = string.match(url,
			"/cp/ps/Mail/SecureViewAttachment?.-&id=%d*")
		if url ~= nil then 
			attach[url] = "http://"..wherearewe..url
			inlineids[url]=url
		end
		
	end
	-- replace url with cid
	if body_html ~= nil then
		body_html  = string.gsub(body_html,
			"src%s*=%s*\".-(/cp/ps/Mail/SecureViewAttachment.-&id=%d*).-\"",'src="cid:%1"')	
	end
	
	return head, body, body_html, attach ,inlineids
end

function is_a_list_needed(msg, uidl)
	-- first retr
	if internal_state.list_begin == -1 then return true, 1 end
	
	local position = internal_state.reverse_lookup[uidl]
	local delta = position - internal_state.list_begin + 1
	
	-- before the begin of the list
	if delta < 0 then return true, 1 end
	-- in the following 9 items 
	if delta < 10 then return false, delta end
	
	return true, 1
end


function retr(pstate,msg,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local session_id_t = internal_state.session_id_t
	local session_id_s = internal_state.session_id_s
	local b = internal_state.b
	local popserver =add_webmail_in_front(b:wherearewe())
	if internal_state.domain=="virgilio.it" then
		popserver =tin_string.virgilio_webmail
	end
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
	local folder = internal_state.folder
	local uidl = get_mailmessage_uidl(pstate,msg)

	-- It seems the webmail keeps a status of your current listing
	-- and allows you to see only the messages that the last listing showed
	-- so, if needed, we relist. If the mail client asks messages from 
	-- 1 to n this minimizes network usage... if it goes from n to 1 this
	-- is a shit.
	local relist, sl = is_a_list_needed(msg, uidl)
	if relist then
		-- we do a list that begins with our message
		local uri_l = string.format(tin_string.first,
			popserver, internal_state.folder,
			domain, user, session_id_t, session_id_s, msg)
		local _,_ = b:get_uri(uri_l)
		internal_state.list_begin = msg
	end
	-- whearewe, mailbox, username, username, uidl, t, s
	local uri = string.format(tin_string.save,popserver,
		folder, domain, user, user, uidl, session_id_t, session_id_s,sl)
	-- tell the browser to fetch
	local head,f = b:get_head_and_body(uri)
	if head == nil then
		log.error_print("Error fetching "..uri..": ".. (f or 'nil'))
		return POPSERVER_ERR_UNKNOWN
	end
	local found,_,ctype = string.find(head,
		"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:"..
		"%s*[^;\r]+;%s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=\"?([^\"\r]*)")
	if found == nil then
		ctype = "UTF-8"
	end
	
	if f == nil then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		return POPSERVER_ERR_NETWORK
	end
		
	if is_an_error_page(f) then
		log.error_print("Asking for "..uri.."\n")
		log.error_print("Internal plugin error, erroneous uri\n")
		--b:show()
		return POPSERVER_ERR_UNKNOWN
	end
	
	local uri = string.format(tin_string.save_attach,popserver,
		folder, domain, user, user, uidl, session_id_t, session_id_s,sl)
	
	-- tell the browser to fetch
	local f_attach, err = b:get_uri(uri)
	if f_attach == nil then
		log.error_print("Error fetching "..uri..": ".. (err or 'nil'))
		return POPSERVER_ERR_UNKNOWN
	end

	local wherearewe = add_webmail_in_front(b:wherearewe())
	local head,body,body_html,attach,inlineids = tin_parse_webmessage(wherearewe, f, f_attach)
	local cb = mimer.callback_mangler(common.retr_cb(data))
	head = string.gsub(head,"([Cc][Hh][Aa][Rr][Ss][Ee][Tt]%s*=).-([;\n])","%1\""..ctype.."\"%2")
	mimer.pipe_msg(head,body,body_html,"http://"..wherearewe,attach,b,cb,inlineids,ctype)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function top(pstate,msg,lines,data)
	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- some local stuff
	local session_id_t = internal_state.session_id_t
	local session_id_s = internal_state.session_id_s
	local b = internal_state.b
	local popserver = add_webmail_in_front(b:wherearewe())
	local domain = internal_state.domain
	local user = internal_state.name
	local user_at_domain = user .. "@" .. domain
	local folder = internal_state.folder
	local uidl = get_mailmessage_uidl(pstate,msg)
	
	-- It seems the webmail keeps a status of your current listing
	-- and allows you to see only the messages that the last listing showed
	-- so, if needed, we relist. If the mail client asks messages from 
	-- 1 to n this minimizes network usage... if it goes from n to 1 this
	-- is a shit.
	local relist, sl = is_a_list_needed(msg, uidl)
	if relist then
		-- we do a list that begins with our message
		local uri_l = string.format(tin_string.first,
			popserver, internal_state.folder,
			domain, user, session_id_t, session_id_s, msg)
		local _,_ = b:get_uri(uri_l)
		internal_state.list_begin = msg
	end
	-- whearewe, mailbox, username, username, uidl, t, s
	local uri = string.format(tin_string.save,popserver,
		folder, domain, user, user, uidl, session_id_t, session_id_s,sl)
	
	-- tell the browser to fetch
	local head,f = b:get_head_and_body(uri)
	if head == nil then
		log.error_print("Error fetching "..uri..": ".. (f or 'nil'))
		return POPSERVER_ERR_UNKNOWN
	end
	local found,_,ctype = string.find(head,
		"[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]%s*:"..
		"%s*[^;\r]+;%s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=\"?([^\"\r]*)")
	if found == nil then
		ctype = "UTF-8"
	end
	
	if f == nil then
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		return POPSERVER_ERR_NETWORK
	end

	local uri = string.format(tin_string.save_attach,popserver,
		folder, domain, user, user, uidl, session_id_t, session_id_s,sl)
	
	-- tell the browser to fetch
	local f_attach, err = b:get_uri(uri)
	if f_attach == nil then
		log.error_print("Error fetching "..uri..": ".. (err or 'nil'))
		return POPSERVER_ERR_UNKNOWN
	end

	local wherearewe = add_webmail_in_front(b:wherearewe())
	local head,body,body_html,attach,inlineids = tin_parse_webmessage(wherearewe, f, f_attach)
	local global = common.new_global_for_top(lines,nil)
	local cb = mimer.callback_mangler(common.top_cb(global,data,true))
	head = string.gsub(head,"([Cc][Hh][Aa][Rr][Ss][Ee][Tt]%s*=).-([;\n])","%1\""..ctype.."\"%2")
	mimer.pipe_msg(head,body,body_html,"http://"..wherearewe,attach,b,cb,nil,ctype)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
--  This function is called to initialize the plugin.
--  Since we need to use the browser and save sessions we have to use
--  some modules with the dofile function
--
--  We also exports the pop3server.* names to global environment so we can
--  write POPSERVER_ERR_OK instead of pop3server.POPSERVER_ERR_OK.
--  
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the serialization module
	require("serial")

	-- the browser module
	require("browser")

	-- the common implementation module
	require("common")
	
	-- the mimer module
	require("mimer")
	
	-- checks on globals
	freepops.set_sanity_checks()

	freepops.need_ssl()

	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
