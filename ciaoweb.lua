-- ************************************************************************** --
--  FreePOPs @ciaoweb webmail interface
-- 
--  $Id: ciaoweb.lua,v 1.5 2007/04/01 01:04:07 gareuselesinge Exp $
-- 
--  Released under the GNU/GPL license
--  Written by Pietro Bonf√ - <pietro_bonfa (at) yahoo (dot) it>
--  Edited by Francesco (Ciccio) Donati <donciccio (at) simail (dot) it>
-- ************************************************************************** --

PLUGIN_VERSION = "0.0.4"
PLUGIN_NAME = "ciaoweb.it"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://freepops.sourceforge.net/download.php?contrib=ciaoweb.lua"
PLUGIN_HOMEPAGE = "http://ciaoweb.prometeo.ath.cx/"
PLUGIN_AUTHORS_NAMES = {"Pietro Bonfa'"}
PLUGIN_AUTHORS_CONTACTS = {"pietro.bonfa (at) yahoo (dot) it"}
PLUGIN_DOMAINS = {"@ciaoweb.it"}
PLUGIN_PARAMETERS = { 
	-- {name="no parameters", description={en="no parameters",it=="non ci sono parametri"}},
}
PLUGIN_DESCRIPTIONS = {
	it=[[Questo plugin serve per leggere le mail che avete in una mailbox @ciaoweb.it. Per usare questo plugin dovete usare il vostro indirizzo email completo come user name e la vostra password reale come password. ]],
	en=[[This is the webmail support for @ciaoweb.it mailboxes. To use this plugin you have to use your full email address as the user name and your real password as the password.]]
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

user_glob = {
username="nothing",
password="nothing"
}

ciaoweb_glob = {
browser = nil,
session_id="nothing",
stat_done = boolean
}

UserAgentsStrings = {"Mozilla/4.0 (compatible; MS IE 6.0; Windows NT 5.1; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 5.00; Window 98)",
"Mozilla/4.0 (compatible; MSIE 5.00; Windows 98)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows 98)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0; AUTOSIGN W2000 WNT VER03)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0; Maxthon)",
"Mozilla/4.0 (compatible; MSIE 5.01; Windows NT)",
"Mozilla/4.0 (compatible; MSIE 5.0; Linux 2.4.26 i686) Opera 6.12",
"Mozilla/4.0 (compatible; MSIE 5.0; Mac_PowerPC)",
"Mozilla/4.0 (compatible; MSIE 5.17; Mac_PowerPC)",
"Mozilla/4.0 (compatible; MSIE 5.22; Mac_PowerPC)",
"Mozilla/4.0 (compatible; MSIE 5.23; Mac_PowerPC)",
"Mozilla/4.0 (compatible; MSIE 5.23; Mac_PowerPC) Opera 7.54",
"Mozilla/4.0 (compatible; MSIE 5.5; AOL 9.0; Windows 98; Win 9x 4.90)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 95)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; FREEvip)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; METL)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Wanadoo 6.0)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Win 9x 4.90)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Win 9x 4.90; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Win 9x 4.90; H010818)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Win 9x 4.90; NOOS)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0; FR 09/05/2000)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0; Cox High Speed Internet Customer; T312461)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0; Maxthon)",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0; T312461; (R1 1.3))",
"Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0; T312461; DOJ3jx7bf)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 7.0; Windows NT 5.1)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 8.0; Windows NT 5.1; SV1)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows 98)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; FunWebProducts; Hotbar 4.5.1.0)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; SV1)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; SV1; FunWebProducts; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.1; SV1; iebar)",
"Mozilla/4.0 (compatible; MSIE 6.0; AOL 9.0; Windows NT 5.2; .NET CLR 1.1.4322)",
"Mozilla/4.0 (compatible; MSIE 6.0; fr-FR; Windows NT 5.1)",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows 98)",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows 98) Opera 7.23",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows 98) Opera 7.54",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0) Opera 7.22",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0) Opera 7.23",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0) Opera 7.54",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0) Opera 7.54",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.21",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.23",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.50",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.53",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.54",
"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Opera 7.54",
"Mozilla/5.0 (BeOS; U; BeOS BePC; en-US; rv:1.8a) Gecko/20040515 Firefox/0.8.0+",
"Mozilla/5.0 (compatible; Konqueror/2.1.1; X11)",
"Mozilla/5.0 (compatible; Konqueror/3.1; Linux)",
"Mozilla/5.0 (compatible; Konqueror/3.2) (KHTML, like Gecko)",
"Mozilla/5.0 (compatible; Konqueror/3.2; Linux) (KHTML, like Gecko)",
"Mozilla/5.0 (compatible; Konqueror/3.3; Linux) (KHTML, like Gecko)",
"Mozilla/5.0 (compatible; Konqueror/3.3; Linux) KHTML/3.3.2 (like Gecko)",
"Mozilla/5.0 (compatible; Konqueror/3; Linux)",
"Mozilla/5.0 (Linux; fr) Gecko/20040707 Firefox/0.9.2",
"Mozilla/5.0 (Linux; U; Linux; fr-FR; rv:1.7.5) Gecko/20041108 Firefox/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.6) Gecko/20040206 Firefox/0.8",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.6a) Gecko/20031030",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040614 Firefox/0.8",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040614 Firefox/0.9",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040616",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040626 Firefox/0.9.1",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040707 Firefox/0.9.2",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040803 Firefox/0.9.3",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.1) Gecko/20040707",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.2) Gecko/20040803",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.2) Gecko/20040804 Netscape/7.2 (ax)",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.3) Gecko/20040910",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0 (ax)",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0 StumbleUpon/1.999",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0 StumbleUpon/1.9991",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 MSIE/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041109 Firefox/1.0 (MOOX M2)",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041109 Firefox/1.0 (MOOX M3)",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041115 Firefox/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041217",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041220 K-Meleon/0.9",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20050209 Firefox/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5;ME) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8a5) Gecko/20041122",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8a6) Gecko/20050106 Firefox/1.0+",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b) Gecko/20050118 Firefox/1.0+ (MOOX M1)",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b) Gecko/20050207 Firefox/1.0+",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b) Gecko/20050208 Firefox/1.0+",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b) Gecko/20050211 Firefox/1.0+",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b) Gecko/20050212 Firefox/1.0+",
"Mozilla/5.0 (Windows; U; Windows NT 5.1; it-IT; rv:1.7.5) Gecko/20041110 Firefox/1.0",
"Mozilla/5.0 (Windows; U; WinNT4.0; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (Windows; U; WinNT4.0; fr-FR; rv:1.7.3) Gecko/20041027 Firefox/1.0RC1",
"Mozilla/5.0 (Windows; U; WinNT4.0; fr-FR; rv:1.7.5) Gecko/20041108 Firefox/1.0",
"Mozilla/5.0 (Windows; U; WinNT4.0; fr; rv:1.6) Gecko/20040113",
"Mozilla/5.0 (Windows; U; WinNT4.0; pl-PL; rv:1.7.5) Gecko/20041108 Firefox/1.0",
"Mozilla/5.0 (Windows; U; WinNT5.0; en-US; 1.2.1) Gecko/20021130",
"Mozilla/5.0 (Windows; U; WinNT; en; rv:1.0.2) Gecko/20030311 Beonex/0.8.2-stable",
"Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.7.5) Gecko/20041222 Firefox/1.0",
"Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.7.5) Gecko/20050125 Firefox/1.0",
"Mozilla/5.0 (X11; U; HP-UX 9000/785; en-US; rv:1.3) Gecko/20030321",
"Mozilla/5.0 (X11; U; Linux i586; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; chrome://navigator/locale/navigator.properties; rv:1.7.5) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; de-DE; rv:1.7.5) Gecko/20041122 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.4) Gecko/20011022 Netscape6/6.2",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.0.0) Gecko/20020623 Debian/1.0.0-0.woody.1",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.0.1) Gecko/20020830",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.2.1) Gecko/20021204",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.3.1) Gecko/20030425",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030806",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5) Gecko/20031007 Firebird/0.7",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.6) Gecko/20040115",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.6) Gecko/20040413 Debian/1.6-5",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.6) Gecko/20040510",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7) Gecko/20040803 Firefox/0.9.3",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7) Gecko/20040809 Firefox/0.9.3",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.2) Gecko/20040803",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.2) Gecko/20040804",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20040913",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20041008",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20041020",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20041110",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20041112 Firefox/1.0RC1",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041103 Firefox/1.0RC2",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041105 Firefox/1.0RC2",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041109 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041111 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041116 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041116 Firefox/1.0 (Ubuntu) (Ubuntu package 1.0-2ubuntu3)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041117 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041118 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041119 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041119 Firefox/1.0 (Debian package 1.0-3)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041125 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041128 Firefox/1.0 (Debian package 1.0-4)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041130 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041203 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041204 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041209 Firefox/1.0 (Ubuntu) (Ubuntu package 1.0-2ubuntu4-warty99)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041219 Firefox/1.0 (Debian package 1.0+dfsg.1-1)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041224 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20041231",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050105 Epiphany/1.4.7",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050105 Galeon/1.3.19 (Debian package 1.3.19-3)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050110 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050110 Firefox/1.0 (Debian package 1.0+dfsg.1-2)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050118 Firefox/1.0",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050128 Firefox/1.0 (Ubuntu) (Ubuntu package 1.0+dfsg.1-2ubuntu5)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050202 Firefox/1.0 (Debian package 1.0+dfsg.1-4)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050206 Firefox/1.0 (Debian package 1.0+dfsg.1-5)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050208",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.5) Gecko/20050210 Firefox/1.0 (Debian package 1.0+dfsg.1-6)",
"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8a6) Gecko/20041223",
"Opera/7.51 (Windows NT 5.1; U)",
"Opera/7.51 (X11; Linux i686; U)",
"Opera/7.54 (Windows NT 4.0; U)",
"Opera/7.54 (Windows NT 5.0; U)",
"Opera/7.54 (Windows NT 5.0; U)",
"Opera/7.54 (Windows NT 5.0; U)",
"Opera/7.54 (Windows NT 5.1; U)",
"Opera/7.54 (Windows NT 5.1; U)",
"Opera/7.54 (X11; Linux i686; U)",
"Opera/7.54 (X11; Linux x86_64; U)",
"Opera/7.54u1 (Windows NT 5.1; U)",
"Opera/7.54u1 (Windows NT 5.1; U)",
"Opera/7.60 (Windows NT 5.1; U; en)",
"Opera/8.0 (X11; Linux i686; U; en)",
"Opera/8.00 (Windows 98; U; en)"}


-- Is called to initialize the module
function init(pstate)
	freepops.export(pop3server)
	
	log.dbg("FreePOPs plugin '"..
		PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started!\n")

	-- the serialization module (edited by DonCiccio - originally "serialize.lua")
	if freepops.dofile("serial.lua") == nil then
		return POPSERVER_ERR_UNKNOWN 
	end 

	-- the browser module (edited by DonCiccio - originally "browser.lua")
	if freepops.dofile("browser//browser.lua") == nil then
		return POPSERVER_ERR_UNKNOWN 
	end

	-- the common module
	if freepops.dofile("common.lua") == nil then 
		return POPSERVER_ERR_UNKNOWN 
	end
	
	-- checks on globals
	freepops.set_sanity_checks()

	-- creo il nuovo browser

	local brw = browser.new(GenerateUA())

	--salvo il browser nelle variabili globali

 	--  brw:verbose_mode()
	ciaoweb_glob.browser = brw

	return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
-- Must save the mailbox name
function user(pstate,username)
	user_glob.username = string.sub(username,1, string.find(username,"@") -1)
	-- print("USERNAME: " .. user_glob.username)
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)

   user_glob.password = password

	-- creo il browser
   local brw = ciaoweb_glob.browser   
   local file,err = nil, nil

--Login su topmail.ciaoweb.it

   local pdata = "b_password=".. user_glob.password .. "&g_ActionToDo=0&MailAddr=http%3A%2F%2Ftopmail.ciaoweb.it%2Fowa%2F&b_username="..user_glob.username .."&b_pass=&accedi=accedi"
   file,err = brw:post_uri("http://topmail.ciaoweb.it/AuthFiles/login.asp", pdata)

	-- print("Pagina: " .. file)
	
   local nsID

   if file ~= nil then	

	--becco il session id
	
	 _,nsID = string.find(file, "HomeSecBody.asp%?")
	if nsID == nil then
	   log.error_print("Login failed\n")
	   log.error_print("Password errata!\n")
   	   return POPSERVER_ERR_AUTH	    
	end
   else
	log.error_print("Login failed\n")
	log.error_print("Server Ciaoweb intasato!\n")
   	return POPSERVER_ERR_AUTH
   end

   local sID = string.sub(file,nsID+1,nsID + 30)

   log.dbg("sID: "..sID.."\n")


	-- Not needed!!
	-- file,err = brw:get_uri("http://topmail.ciaoweb.it/AuthFiles/HomeSecHeader.asp?"..sID)
	-- file,err = brw:get_uri("http://topmail.ciaoweb.it/AuthFiles/HomeSecFooter.asp?"..sID)


   -- scarico questa pagina solo per il referer; volendo si potrebbe togliere, ma si sa, a ciaoweb fanno presto ad aggiungere controlli..
   file,err = brw:get_uri("http://topmail.ciaoweb.it/AuthFiles/HomeSecBody.asp?"..sID)

	-- print("Pagina: " .. file)


--creo il POST per la connessione a webmail.ciaoweb.it

    --urlencode del POST
	  sID = string.gsub(sID, "=", "%%3D")
	  sID = string.gsub(sID, "&", "%%26") -- @ = %%40

    local post_data = string.format("login_username=%s%%40ciaoweb.it&secretkey=%s&sessionlogin=%s&js_autodetect_results=1&just_logged_in=1",user_glob.username, user_glob.password,sID)

    local url = "http://webmail.ciaoweb.it/src/redirect.php"

    file,err = brw:post_uri(url, post_data)
	
	-- print("we received this webpage: ".. file)

	if file ~= nil then
	    local lgnerror = string.find(file, "Errore")
	
	    if lgnerror ~= nil then
		log.error_print("Login failed\n")
		log.error_print("Sessione scaduta!\n")
      		return POPSERVER_ERR_AUTH
	    end
	
	else
		log.error_print("Login failed\n")
		log.error_print("Server Ciaoweb intasato!\n")
      		return POPSERVER_ERR_AUTH
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

	-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end

	-- shorten names, not really important
	local brw = ciaoweb_glob.browser
	local post_uri = "http://webmail.ciaoweb.it/src/move_messages.php"

	-- here we need the stat, we build the uri and we check if we 
	-- need to delete something
	local delete_something = false;

	local post_data="msg=&mailbox=INBOX&startMessage=1&moveButton=&markUnread=&deleteFuffa=1&targetMailbox=INBOX&location=/src/right_main.php?PG_SHOWALL=0&sort=0&startMessage=1&mailbox=INBOX"

	for i=1,get_popstate_nummesg(pstate) do
		if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
			post_data = post_data .. "&msg[" .. i .. "]=" ..
				get_mailmessage_uidl(pstate,i)
			delete_something = true	
		end
	end

	if delete_something then
		local file, err = brw:post_uri(post_uri,post_data)
		-- print ("we received this: " .. file)
		local lgnerror = string.find(file, "You exceeded your mail quota")
	
	    if lgnerror ~= nil then
		log.error_print("Delete failed\n")
		log.error_print("You exceeded your mail quota!\n(I/il messaggio sono troppo grossi per il cestino.\nProvo a cancellarli uno a uno!\n.")
      		
		local logerr = false
		-- provo a cancellare i messaggi uno a uno!
		for i=1,get_popstate_nummesg(pstate) do
			if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
				post_data = "msg=&mailbox=INBOX&startMessage=1&moveButton=&markUnread=&deleteFuffa=1&targetMailbox=INBOX&location=/src/right_main.php?PG_SHOWALL=0&sort=0&startMessage=1&mailbox=INBOX&msg[" .. i .. "]=" ..
					get_mailmessage_uidl(pstate,i)

				local file, err = brw:post_uri(post_uri,post_data)
				local lgnerror = string.find(file, "You exceeded your mail quota")
			
				if lgnerror ~= nil then
					logerr = true
					log.error_print("Delete failed\n")
					log.error_print("Messaggio troppo grosso!\n")
				end
			end
		end
		if logerr == true then
			return POPSERVER_ERR_NETWORK
		end
	    end
		
	end

	return POPSERVER_ERR_OK

end
-- -------------------------------------------------------------------------- --
-- Fill the number of messages and their size
function stat(pstate)

       if ciaoweb_glob.stat_done == true then return POPSERVER_ERR_OK end

	local brw = ciaoweb_glob.browser

	-- local file,err = brw:get_uri("http://webmail.ciaoweb.it/src/webmail.php")
	-- print("we received this webpage: ".. file)

	local file,err = brw:get_uri("http://webmail.ciaoweb.it/src/right_main.php")
	-- print("we received this webpage: ".. file)

	if file == nil then
		log.error_print("STAT failed\n")
		log.error_print("Server Ciaoweb intasato(1)!\n")
      		return POPSERVER_ERR_NETWORK

	elseif string.find(file, "<b>Errore</b><small></small></small></font></td></tr><tr><td align=\"center\"><font face=\"verdana, arial, helvetica, sans-serif\"><small>Per accedere alla pagina e' necessario eseguire l'autenticazione</small>") ~= nil then

		log.error_print("STAT failed\n")
		log.error_print("Login Scaduta!\n")
      		return POPSERVER_ERR_NETWORK
	end	


	if string.find(file,"<td align=\"left\" valign=\"middle\" nowrap>Precedente") ~= nil then
		local startmsgpos = 0
		local startmsg = {}
		local msgfrom = 0
		local i = 0

		while true do
			
			-- right_main.php?use_mailbox_cache=0&amp;startMessage=16&amp;mailbox=INBOX
	
			startmsgpos = string.find(file,"right_main.php%?use_mailbox_cache=0&amp;startMessage=",startmsgpos + 1)
			if startmsgpos == nil then break end
			_,_,msgfrom = string.find(file,"right_main.php%?use_mailbox_cache=0&amp;startMessage=(%d+)",startmsgpos)
			startmsg[i] = msgfrom
			i = i + 1	
		end
		-- print("i: " ..i)
		i = i - 2 		--toglie l'id del link "successivo" (partiamo da 0!!)
		for a=0,i do
		--	print ("A: "..a.." startmsg[a]: "..startmsg[a])
			local morepage,merr = brw:get_uri("http://webmail.ciaoweb.it/src/right_main.php?use_mailbox_cache=0&startMessage="..startmsg[a].."&mailbox=INBOX")
			file = file .. morepage
			
		end

		-- print ("FILE: "..file)

	end

	local e = ".*<tr>.*<td>.*<b>.*<small>.*{img}[.*]</td>[.*]{td}[.*]{img}[.*]{/td}.*<td>[.*]{img}.*</small>.*</b>.*</td>.*<td>.*<input>.*</td>.*<td>[.*]{b}.*<a>.*</a>.*{/b}[.*]</td>.*<td>[.*]{b}.*<a>.*</a>.*{/b}[.*]</td>.*<td >[.*]{b}.*{/b}[.*]</td>.*<td>[.*]{b}.*<small>.*</small>.*{/b}[.*]</td>.*</tr>"

	local g = "<O>O<O>O<O>O<O>O{O}[O]<O>[O]{O}[O]{O}[O]{O}O<O>[O]{O}O<O>O<O>O<O>O<O>O<X>O<O>O<O>[O]{O}O<O>O<O>O{O}[O]<O>O<O>[O]{O}O<O>O<O>O{O}[O]<O>O<O >[O]{O}O{O}[O]<O>O<O>[O]{O}X<O>X<O>O{O}[O]<O>O<O>"


	local x = mlex.match(file,e,g)

	-- x:print()

	set_popstate_nummesg(pstate,x:count())
	
	for i=1,x:count() do
		local size
		if string.find(x:get(1,i-1),",") ~= nil then
			_,_,size = string.find(x:get(1,i-1),"(%d,%d+)")
			size = string.gsub(size,",","%.")
		else
			_,_,size = string.find(x:get(1,i-1),"(%d+)")
		end

		-- print ("size: "..size)
		
				--string.gsub("hello, up-down!", "%A", ".")

		local _,_,size_mult_k = string.find(x:get(2,i-1),"([Kk])")
		local _,_,size_mult_m = string.find(x:get(2,i-1),"([Mm])")
		local _,_,uidl = string.find(x:get(0,i-1),"value=.(%d+)")

		--print (x:get(0,i-1))
		-- print (tonumber(string.gsub(size,",","%.")))
		--print (x:get(2,i-1))
		
		-- size=1

		if size_mult_k ~= nil then
			size = math.ceil(size * 1024)
		-- print ("size: "..size.." size_mult_k: "..size_mult_k.." uidl: "..uidl)
		end
	
		if size_mult_m ~= nil then
			size = math.ceil(size * 1024) * 1024
		-- print ("size: "..size.." size_mult_m: "..size_mult_m.." uidl: "..uidl)
		end

		 set_mailmessage_size(pstate,i,size)
		 set_mailmessage_uidl(pstate,i,uidl)
	 
	end

	ciaoweb_glob.stat_done = true
	return POPSERVER_ERR_OK

end
--------------------------------
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

	dwnl_msg(pstate,msg,pdata,lines)

	return POPSERVER_ERR_OK

end
-- -------------------------------------------------------------------------- --
-- Get message msg, must call 
-- popserver_callback to send the data
function retr(pstate,msg,pdata)

	dwnl_msg(pstate,msg,pdata,-2)

	return POPSERVER_ERR_OK
end

function dwnl_msg(pstate,msg,pdata,lines)

		-- we need the stat
	local st = stat(pstate)
	if st ~= POPSERVER_ERR_OK then return st end
	
	-- the callback
	
	local cb = retr_cb(pdata,lines)
	
	-- some local stuff
	local brw = ciaoweb_glob.browser
	local uri = "http://webmail.ciaoweb.it/src/download.php?absolute_dl=true&passed_id="..get_mailmessage_uidl(pstate,msg).."&mailbox=INBOX"
	log.dbg("Start Download.\n")
	-- tell the browser to pipe the uri using cb
	local f,rc = brw:pipe_uri(uri,cb)

	if not f and lines == -2 then
		-- print("Errore!!!")
		log.error_print("Asking for "..uri.."\n")
		log.error_print(rc.."\n")
		return POPSERVER_ERR_NETWORK
	end
	log.dbg("PopServer OK!\n")
	return POPSERVER_ERR_OK

end


--------------------------------------------------------------------------------
-- The callbach factory for retr
--
function retr_cb(data,lines)
	local a = stringhack.new()
	log.dbg ("Start retr_cb.\n")
	return function(s,len)

		log.dbg ("chiamata function di callback: (data,"..len..")\n")

		if (lines ~= -2) then
			
			log.dbg ("Chiamata con righe ~= -2\n")

			s = string.gsub(s,"\n","\r\n")
			s = a:tophack(s,lines)

			
				if a:check_stop(lines) then 
					if(string.sub(s,-2,-1) ~= "\r\n") then
					log.dbg("Non finisce con rn!!\n")
					end

					s = a:dothack(s).."\0"	
					-- print("Invio da check_stop: "..s)
					popserver_callback(s,data)
					
					return 0,nil 
				end
			
			s = a:dothack(s).."\0"	
			
			-- print ("Invio NORMAL: "..s)

			popserver_callback(s,data)

		      return len, nil
		  
    		else

			log.dbg("Chiamata con righe == -2\n")

			s = string.gsub(s,"\n","\r\n")

			s = a:dothack(s).."\0"		
			log.dbg ("Invio dati!: "..s.."\n")
			popserver_callback(s,data)
			
			return len,nil
		end
	
		log.dbg ("Fine funzione callback\n")
	end
	

end

function GenerateUA()

	local ua = UserAgentsStrings[math.mod(math.random(1,200) + os.time(),178)]
	log.dbg ("User-Agent: " .. ua)

   return ua
end
-- EOF
-- ************************************************************************** --