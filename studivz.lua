-- ************************************************************************** --
--  FreePOPs StudiVz.de/MeinVz.de/SchuelerVz.de Plugin - POP3 Server gateway
--  Version: 1.0.28 - 10/27/2014
--
--  Released as Freeware/Donationware - Written by André Martin
--  Copyright (c) 2008-2014 by André Martin - All rights reserved.

-- ************************************************************************** --

-- Deutsche Beschreibung unten/German description below...

-- Read & import all your StudiVz/MeinVz/SchülerVz messages in your favorite
-- Email client such as Outlook/Thunderbird etc. using FreePOPs StudiVz Plugin

-- Installation:
-- 1.) Download & install FreePOPs (http://www.freepops.org)
-- 2.) Copy this file in the LUA_UNOFFICIAL folder of FreePOPs
-- 3.) Launch the FreePOPs daemon
-- 4.) Add a new account in your mail client using the "localhost" as POP3
--     server and "2000" as port and the following usernamen & password:

-- Use "no-reply@studivz.de?email=mylogin-email@domain.com" as login in your
-- mailreader and your StudiVz.de password as your password
-- or "no-reply@meinvz.de?email=mylogin-email@domain.com" as login in your
-- mailreader and your MeinVz.de password as your password
-- or "no-reply@schuelervz.de?email=mylogin-email@domain.com" as login in your
-- mailreader and your SchülerVz.de password as your password

-- If you like this plugin, please join StudiVz/MeinVz group: 1d1388a129089583

-- Lies & importiere all' deine StudiVz/MeinVz/SchülerVz Nachrichten in deinem
-- lieblings Emailclient z.B. Outlook/Thunderbird etc. mit dem FreePOPs
-- StudiVz Plugin.

-- Installation:
-- 1.) Downloade & installiere FreePOPs (http://www.freepops.org)
-- 2.) Kopiere diese Datei in den LUA_UNOFFICIAL Ordner von FreePOPs
-- 3.) Starte FreePOPs
-- 4.) Füge ein neues Emailkonto/account in deinem Emailprogramm hinzu mit
--     "localhost" als POP3 Server, "2000" als Port und den folgenden
--     Benutzernamen und Kennwort:

-- Benutze "no-reply@studivz.de?email=meine-login-email@domain.de" als Login
-- in deinem Emailprogramm und dein StudiVz.de Passwort als Passwort
-- oder "no-reply@meinvz.de?email=meine-login-email@domain.de" als Login
-- in deinem Emailprogramm und dein MeinVz.de Passwort als Passwort
-- oder "no-reply@schuelervz.de?email=meine-login-email@domain.de" als Login
-- in deinem Emailprogramm und dein SchülerVz.de Passwort als Passwort

-- Wenn du dieses Plugin toll findest & nutzt, dann trete bitte der
-- StudiVz/MeinVz Gruppe: 1d1388a129089583 bei:-) Danke.

-- -------------------------------------------------------------------------- --
PLUGIN_VERSION = "1.0.28 - 10/27/2014"
PLUGIN_NAME = "StudiVz.de"
PLUGIN_REQUIRE_VERSION = "0.2.8"
PLUGIN_LICENSE = "Freeware/Donationware"
PLUGIN_URL = "http://www.andremartin.de/studivz.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/en/viewplugin.php?plugin=studivz.lua"
PLUGIN_AUTHORS_NAMES = {"André Martin"}
PLUGIN_AUTHORS_CONTACTS = {"pop3plugin [remove-this-before-emailing-me] @ andremartin(.)de"}
PLUGIN_DOMAINS = {"@studivz.de","@studivz.net","@meinvz.de",
   "@meinvz.net","@schuelervz.de","@schuelervz.net"}
PLUGIN_PARAMETERS = {
   {name="email", description={
      en=[[Your email address you use @ StudiVz.de/MeinVz.de/SchuelerVz.de /
         Deine Emailaddresse bei StudiVz.de/MeinVz.de/SchuelerVz.de]]}},
   {name="folder", description={
      en=[[The folder (Inbox is the default) that you wish to access. You can choose
         between Inbox, Outbox and Wall/ Auswählen der Nachrichtenbox/Pinnwand
         (Standartwert: Inbox) Du kannst wählen zwischen Inbox, Gesendet oder
         Pinnwand (Inbox|Outbox|Wall)]]}},
   {name="SSL", description={
      en=[[Use SSL to login (enabled by default) (true|false) /
         Benutze SSL zum Einloggen (Standartwert: true) (true|false)]]}},
   {name="offset", description={
      en=[[Starting page/offset to ignore the first x pages ( = 15*x messages)
         from your mailbox (1 = by default) (multiple of 15) /
         Ignoriert die x ersten Seiten ( = 15*x neusten Nachrichten) in der Mailbox
         (Standartwert: 1 = erste Seite) (in 15ner Schritten)]]}},
   {name="limit", description={
      en=[[Limits the amount of messages read from your mailbox (-1 = limitless by default)
         (multiple of 15) / Beschränkt die Anzahl der angezeigten Nachrichten in der Mailbox
         (Standartwert: -1 = keine Einschränkung) (mehrfaches von 15)]]}}}
PLUGIN_DESCRIPTIONS = {
      en=[[A message reader for StudiVz.de/MeinVz.de/SchuelerVz.de /
         Ein Email-reader für StudiVz.de/MeinVz.de/SchuelerVz.de]]}
-- -------------------------------------------------------------------------- --
-- 27.10.14 Release 1.0.28
-- 26.10.14   Fixed bug in proper auth success detection due to web ui change
-- 04.09.12 Release 1.0.27
-- 04.09.12   Fixed bug in login URL due to web ui change
-- 01.11.12 Release 1.0.26
-- 01.11.12   Fixed bug in real name of deleted users due to web ui change
-- 07.04.11 Release 1.0.25
-- 07.04.11   Added starting offset parameter to ignore the newest x messages
-- 07.04.11   Fixed bug in wall msg deletion due to web ui change
-- 06.04.11   Fixed bug in outbox msg's body capture due to web ui change
-- 06.07.10 Release 1.0.24
-- 06.07.10   Fixed bug in name capture due to web ui change
-- 06.07.10   Fixed bug in msg index (inbox/outbox)capture due to web ui change
-- 04.07.10 Release 1.0.23
-- 04.07.10   Fixed bug in body capture for outbox messages due to web ui change
-- 04.07.10   Fixed bug in body capture for wall messages due to web ui change
-- 14.12.09 Release 1.0.22
-- 13.12.09   Fixed bug in profile id capture due to profile id pattern change
-- 07.12.09   Fixed bug in name capture for wall posts (no escape in regex)
-- 03.11.09 Release 1.0.21
-- 02.11.09   Fixed bug in profile id retrieval due to profile id pattern change
-- 24.10.09   Added consolidated T&C / migration hack
-- 24.10.09   Fixed minor bugs in error handling code for HTTP posts
-- 10.10.09 Release 1.0.20
-- 10.10.09   Fixed bug in strtrim function
-- 28.09.09   Added new daylight saving dates
-- 28.09.09   Added SFT such as selective retries for connection timeouts/refused
-- 13.09.09   Added limit parameter for mailboxes with a huge amount of msgs
-- 13.09.09   Added T&C hack for schuelervz.de
-- 13.09.09   Fixed bug due to webinterface change: regex for name
-- 09.06.09 Release 1.0.19
-- 09.06.09   Fixed bug due to webinterface change: regex for name
-- 31.05.09   Fixed non-unique message id in header by removing retrieval date
-- 08.04.09 Release 1.0.18
-- 08.04.09   Fixed bug in am/pm 24h-clock conversion
-- 31.03.09   Fixed crash if no write permissions for config file
-- 29.03.09 Release 1.0.17
-- 29.03.09   Added Captcha code detection and "handling" => empty mailbox
-- 29.03.09   Fixed empty mailbox (wall) due to webinterface change
-- 03.02.09 Release 1.0.16
-- 03.02.09   Fixed bug/crash in update checker - THX Chaser
-- 02.02.09 Release 1.0.15
-- 30.01.09   Fixed bug/crash when using special characters in pwds - THX Malte
-- 24.01.09   Added English UI support for meinvz.net
-- 22.01.09   Added email notification when new updates are available
-- 20.01.09 Release 1.0.14
-- 20.01.09   Fixed removed checkcode field due to webinterface change
-- 17.01.09   Added simplified sender/receiver container data structure
-- 17.01.09   Fixed reference when replying to msgs (sendmessage method)
-- 01.12.08 Release 1.0.13
-- 30.11.08   Added multilanguage support (German) to installer
-- 26.11.08   Added online/chat status update to appear as offline
-- 25.11.08   Added deletion for multiple pinboard entries at once
-- 19.10.08 Release 1.0.12
-- 19.10.08   Added multiple recipients feature to message send function
-- 19.10.08   Fixed message deletion & removed obsolete non Ajax version code
-- 10.10.08 Release 1.0.11
-- 10.10.08   Fixed uncropped tid in profile id
-- 26.09.08 Release 1.0.10
-- 26.09.08   Fixed changed checkcode meta variable name
-- 26.06.08 Release 1.0.9
-- 25.06.08   Added support for new StudiVz/MeinVz/SchuelerVz msging interface
-- 12.06.08   Fixed Did not remove line breaks in subjects of wall posts
-- 07.06.08   Moved UTF-8 en/decoder and qp-decoder to mimer package
-- 01.06.08 Release 1.0.8
-- 01.06.08   Fixed bug in pinwall messages from deleted user profiles
-- 01.06.08 Release 1.0.7
-- 31.05.08   Added replaced mlex expressions by gmatch
-- 31.05.08   Fixed messages from deleted user profiles were not listed
-- 25.05.08   Added Pinwall import option (folder=Wall)
-- 25.05.08   Added quoted-printable decoder
-- 24.05.08   Added UTF-8 en/decoder & changed default charset to: ISO-8859-1
-- 23.05.08   Added Ajax support for faster message retrieval
-- 22.05.08   Added send message function for SMTP Server gateway/bridge
-- 21.05.08   Added renamed plugin name from StudiVzDe.lua to studivz.lua
-- 20.05.08 Release 1.0.6
-- 20.05.08   Added temporary hack for Migration page
-- 19.05.08   Added comment for Mimer 0.1.1 backwards compatibility
-- 17.05.08 Release 1.0.5
-- 17.05.08   Fixed Moved SSL check & init to plugin code
-- 07.05.08 Release 1.0.4
-- 07.05.08   Added X-StudiVz.net-Message-Status field
-- 07.05.08   Added message deletion
-- 06.05.08 Release 1.0.3
-- 06.05.08   Added schuelerVz.de
-- 06.05.08   Added Adjusted new StudiVz.de URL format for messages
-- 05.05.08 Release 1.0.2
-- 05.05.08   Added meinVz.de
-- 04.05.08   Added Daylight savings
-- 02.05.08 Release 1.0.1
-- 02.05.08   Added X-StudiVz.net-Sender-Profile-ID field
-- 02.05.08   Added X-StudiVz.net-Receiver-Profile-ID field
-- 02.05.08   Fixed SSL flag bug
-- 01.05.08 First public release StudiVzDe 1.0.0
-- 30.04.08   Added folder parameter
-- 30.04.08   Added SSL parameter
-- 29.04.08   Added year "guessing" / back calculating for Inbox
-- 28.04.08   Initial first working draft
-- -------------------------------------------------------------------------- --
function init(pstate)
   freepops.export(pop3server)

   log.dbg("FreePOPs plugin '"..
      PLUGIN_NAME.."' version '"..PLUGIN_VERSION.."' started.\n")

   require("browser")
   require("common")
   require("mimer")

   -- checks on globals
   freepops.set_sanity_checks()

   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
studivz_globals= {
   name="nothing",
   profile_id="nothing",
   username="nothing",
   password="nothing",
   sender_profile={},
   sender_email={},
   sender_name={},
   receiver_profile={},
   receiver_email={},
   receiver_name={},
   subject={},
   datetime={},
   page={},
   msg_status={},
   commentId={},
   formkey,
   iv,
   useragent="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0) Gecko/20100101 Firefox/4.0",
   useSSL = true,
   retries = 3,
   folder = "Inbox",
   domain = "studivz.net",
   offset = 1,
   limit = -1,
   currentMonth=0,
   currentYear=0,
   charset= "ISO-8859-1",
   pinwall_subject_prexix = "Pinnwand: ",
   use_profile_id = true,
   checkforupdates = false,
   currentversion = PLUGIN_VERSION,
   checksum = true,
   lastcheck = "",
   english_ui = false,
   checksum1 =
"TGllYmVyIEZyZWVQT1BzIFN0dWRpVnovTWVpblZ6L1NjaPxsZXJWeiBQbHVnaW4gTnV0emVyLA0K"..
"ZWluZSBuZXVlIFZlcnNpb24gKCRWRVIpIGlzdCB2ZXJm/GdiYXIgdW5kIGthbm4gaGllciBoZXJ1"..
"bnRlcmdlbGFkZW4gd2VyZGVuOg0KDQogIGh0dHA6Ly93d3cuYW5kcmVtYXJ0aW4uZGUvU3R1ZGlW"..
"elBsdWdpbi9HZXJtYW4uaHRtDQogIGh0dHA6Ly93d3cuZnJlZXBvcHMub3JnL2VuL3ZpZXdwbHVn"..
"aW4ucGhwP3BsdWdpbj1zdHVkaXZ6Lmx1YQ0KDQoNCkRlYXIgRnJlZVBPUHMgU3R1ZGlWei9NZWlu"..
"VnovU2No/GxlclZ6IFBsdWdpbiB1c2VyLA0KQSBuZXcgdmVyc2lvbiAoJFZFUikgaXMgYXZhaWxh"..
"YmxlIGFuZCBjYW4gYmUgZG93bmxvYWRlZCBmcm9tIGhlcmU6DQoNCiAgaHR0cDovL3d3dy5hbmRy"..
"ZW1hcnRpbi5kZS9TdHVkaVZ6UGx1Z2luDQogIGh0dHA6Ly93d3cuZnJlZXBvcHMub3JnL2VuL3Zp"..
"ZXdwbHVnaW4ucGhwP3BsdWdpbj1zdHVkaXZ6Lmx1YQ0KDQoNClRoYW5rcy4NCg==",
   checksum2 =
"TGllYmVyIEZyZWVQT1BzIFN0dWRpVnovTWVpblZ6L1NjaPxsZXJWeiBQbHVnaW4gTnV0emVyLA0K"..
"ZHUgbnV0enQgZGllc2VzIFBsdWdpbiBudW4gc2Nob24gZWluIFdlaWxjaGVuIGJ6dy4gcmVjaHQg"..
"aW50ZW5zaXYgdW5kIGVzIGdpYnQgYmVzdGltbXQgZWluZSBNZW5nZSBHcvxuZGUsIHdhcnVtIGR1"..
"IGRpZXNlcyBQbHVnaW4gbnV0enQ6IFp1bSBrb21mb3J0YWJsZW4gQXJjaGl2aWVyZW4gYnp3LiBW"..
"ZXJ3YWx0ZW4gZGVpbmVyIE5hY2hyaWNodGVuIGJlaSBTdHVkaVZ6L01laW5Wei9TY2j8bGVyVnou"..
"IGV0Yy4gV2FzIHfkcmUsIHdlbm4gZGllc2VzIFBsdWdpbiBuaWNodCBleGlzdGllcmVuIHf8cmRl"..
"PyBX/HJkZXN0IGR1IGRhbm4gZGVpbmUgTmFjaHJpY2h0ZW4gaW1tZXIgbm9jaCB2aWVsbGVpY2h0"..
"IHZpYSBDb3B5JlBhc3RlIGtvcGllcmVuIHVuZCBpcmdlbmR3byBzcGVpY2hlcm4/IFVuZCB3aWV2"..
"aWVsIFplaXQgaGFzdCBkdSBpbnp3aXNjaGVuIGR1cmNoIGRpZXNlcyBQbHVnaW4gZ2VzcGFydD8g"..
"VW0gZGllIFdlaXRlcmVudHdpY2tsdW5nL1N1cHBvcnQgZGllc2VzIFBsdWdpbnMgenUgdW50ZXJz"..
"dPx0emVuLCB3aWxsIGljaCBkaWNoIGhldXRlIGb8ciBlaW5lIGtsZWluZW4gU3BlbmRlIGVybXV0"..
"aWdlbjogV2VpbCBTdHVkZW50ZW4gYmVrYW5udGxpY2ggYXJtICYga25hdXNyaWcgc2luZCwgcmVp"..
"Y2h0IGF1Y2ggc2Nob24gZWluIGVpbnppZ2VyIEV1cm8gOi0pIFNpZWhlIFNwZW5kZW4gTGlua2Ug"..
"YXVmIGRlciB1bnRlbiBzdGVoZW5kZW4gU2VpdGUuIFZpZWxlbiBEYW5rLg0KDQpodHRwOi8vd3d3"..
"LmFuZHJlbWFydGluLmRlL1N0dWRpVnpQbHVnaW4vR2VybWFuLmh0bQ0KDQpEZWFyIEZyZWVQT1Bz"..
"IFN0dWRpVnovTWVpblZ6L1NjaPxsZXJWeiBQbHVnaW4gTnV0emVyLA0KeW91IGFyZSB1c2luZyB0"..
"aGlzIHBsdWdpbiBzaW5jZSBhIHF1aXRlIHdoaWxlIGFuZCBJIGJldCB0aGVyZSBhcmUgYSBidW5j"..
"aCBvZiByZWFzb25zIHdoeSB5b3UgYXJlIHVzaW5nIHRoaXMgcGx1Z2luOiBUbyBmaWxlIGFuZCBt"..
"YW5hZ2UgeW91ciBTdHVkaVZ6L01laW5Wei9TY2j8bGVyVnogbWVzc2FnZXMuLi4gSG93IGRpZCB0"..
"aGlzIHBsdWdpbiBpbXBhY3QgeW91ciBsaWZlPyBXaGF0IHdvdWxkIHlvdSBkbyBpZiB0aGlzIHBs"..
"dWdpbiB3b3VsZG4ndCBleGlzdD8gU3RpbGwgY29weWluZyAmIHBhc3RpbmcgeW91ciBtZXNzYWdl"..
"cyBtYW51YWxseSB0byBrZWVwIHRoZW0/IEFuZCBob3cgbXVjaCB0aW1lIG9mIHlvdXIgbGlmZSBk"..
"aWQgeW91IHNhdmUgdGhyb3VnaCB1c2luZyB0aGlzIHBsdWdpbj8gIEluIG9yZGVyIHRvIHN1cHBv"..
"cnQgdGhlIG1haW50YWluY2UgYW5kIGRldmVsb3BtZW50IG9mIHRoaXMgcGx1Z2luLCBJIHdhbnQg"..
"dG8gZW5jaG91cmFnZSB5b3UgZm9yIGEgZG9uYXRpb24gdG9kYXksIGFuZCBpdCdzIHdlbGwga25v"..
"d24gdGhhdCBzdHVkZW50cyBsaWtlIHlvdSBhcmUgYWx3YXlzIGJyb2tlLCBqdXN0IGEgc2luZ2xl"..
"IGRvbGxhci9ldXJvIGlzIGVub3VnaC4gSnVzdCBzZWUgdGhlIGRvbmF0ZSBsaW5rIG9uIHRoZSBw"..
"YWdlIGJlbG93LiBUaGFua3MuDQoNCmh0dHA6Ly93d3cuYW5kcmVtYXJ0aW4uZGUvU3R1ZGlWelBs"..
"dWdpbg==",
}
-- -------------------------------------------------------------------------- --
function user(pstate,username)

   studivz_globals.username = freepops.MODULE_ARGS.email

   local domain = freepops.get_domain(username)

   if domain == "meinvz.net" or domain == "meinvz.de" then
      studivz_globals.domain = "meinvz.net"
   end
   if domain == "schuelervz.net" or domain == "schuelervz.de" then
      studivz_globals.domain = "schuelervz.net"
   end

   local mailbox = (freepops.MODULE_ARGS or {}).folder or "Inbox"
   if mailbox == "Outbox" or mailbox == "OUTBOX" then
      studivz_globals.folder = "Outbox"
   end
   if mailbox == "Wall" or mailbox == "WALL" then
      studivz_globals.folder = "Wall"
   end

   studivz_globals.offset = tonumber((freepops.MODULE_ARGS or {}).offset or 1)
   studivz_globals.limit = tonumber((freepops.MODULE_ARGS or {}).limit or -1)

   local checkforupdates =
      (freepops.MODULE_ARGS or {}).checkforupdates or "true"
   if checkforupdates == "true" or checkforupdates == "TRUE" then
      studivz_globals.checkforupdates = true
   end

   local ssl_enabled = browser.ssl_enabled()

   -- create a new browser
   local browser = browser.new(studivz_globals.useragent)

   -- store the browser object in globals
   studivz_globals.myBrowser = browser

   local SSL = (freepops.MODULE_ARGS or {}).SSL or "true"
   if SSL == "false" or ssl_enabled==false then
      studivz_globals.useSSL = false
   else
      browser:ssl_init_stuff()
   end

   log.dbg("USER \""..username.."\"")

   local uri = "http://www."..studivz_globals.domain.."/Default"
   local file,_ = getPage(uri)
   if not file then return POPSERVER_ERR_NETWORK end

   local formkey, iv = extract_security_pattern2(file, 0)

   studivz_globals.formkey = formkey
   studivz_globals.iv = iv

   local file = io.open("studivz.cfg", "r")
   local checksum_a=1
   local checksum_b=1
   if file then
      studivz_globals.lastcheck,checksum_a,checksum_b =
         string.match(base64.decode(file:read("*all")),
         "([^;]*);([^;]*);(.*)")
      if tonumber(checksum_a)%20==0 and tonumber(checksum_b)>15 then
         studivz_globals.checksum = true
      end
      if os.date("%d.%m.%Y")~=studivz_globals.lastcheck then
         checksum_b=tonumber(checksum_b)+1
      end
      file:close()
   end
   file = io.open("studivz.cfg", "w")
   if file then
      file:write(base64.encode(os.date("%d.%m.%Y")..";"..
         (tonumber(checksum_a)+1)..";"..checksum_b))
      file:close()
   end

   if studivz_globals.checkforupdates==true and
      os.date("%d.%m.%Y")~=studivz_globals.lastcheck then
      local file,_ = getPage("http://www.andremartin.de/"..
         "StudiVzPlugin/Version")
      if file then
         studivz_globals.currentversion = string.match(file,"([^ ]+)")
      end
   end

   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function pass(pstate,password)

   studivz_globals.password = password

   log.dbg("PASS ********")

   local browser = studivz_globals.myBrowser

   local post_data = string.format("email=%s&password=%s&login=Einloggen&"..
      "jsEnabled=true&platformFlag=old&formkey="..studivz_globals.formkey.."&iv="..
      studivz_globals.iv, curl.escape(studivz_globals.username),
      curl.escape(studivz_globals.password))

   local post_uri = "http://secure."..studivz_globals.domain.."/Login"
   if studivz_globals.useSSL then
      post_uri = "https://secure."..studivz_globals.domain.."/Login"
   end
   if studivz_globals.domain == "meinvz.de" then
      post_uri = "http://www."..studivz_globals.domain.."/Login"
   end

   log.dbg("Posting data: \""..string.gsub(post_data,
      string.gsub(curl.escape(studivz_globals.password),"%%","%%%%"),
      "********").."\" to: "..post_uri)

   local file,err = browser:post_uri(post_uri,post_data)
   if not file then
      error_webpage(post_uri,err)
      return POPSERVER_ERR_NETWORK
   end

   -- display page contents
   --log.dbg("we received this webpage: ".. file)

   -- temporary migration hack for StudiVz.de & T&C hack for schuelerVz.de...
   if string.find(file,"Verzeichnis wechseln") or
      string.find(file,"schuelerVZ | AGB")
   then
      local uri = "http://www."..studivz_globals.domain.."/Start"
      file,_ = getPage(uri)
      if not file then return POPSERVER_ERR_NETWORK end
   end
   -- temporary migration & T&C hack hack end

   local success = string.find(file,"Meine Startseite")
   if success == nil then success = string.find(file,"My homepage") end
   if success == nil then
      success = string.find(file,"xvz.platform=")
      if success ~= nil then
         local uri = "http://www."..studivz_globals.domain.."/Home"
         file,_ = getPage(uri)
         if not file then return POPSERVER_ERR_NETWORK end
      end
   end

   if success then
      local name = string.match(file,"<h1 [^>]*>Hallo ([^!]*)!</h1>")

      if studivz_globals.domain == "meinvz.net" then
         name = string.match(file,"<h1 [^>]*>Hallo, ([^!]*)!</h1>")
         if name==nil then
            name = string.match(file,"<h1 [^>]*>Hi ([^<]*)</h1>")
            studivz_globals.english_ui = true
         end
      end
      if studivz_globals.domain == "schuelervz.net" then
         name = string.match(file,"<h1 [^>]*>Hey ([^!]*)!</h1>")
      end

      log.dbg("Your name: "..mimer.decodeUTF8(name))

      if studivz_globals.charset == "ISO-8859-1" then
         name = mimer.decodeUTF8(name)
      end

      studivz_globals.name = name

      local profile_id,_ = string.match(file, "<li class=\"clearFix\"><a href=\"/Profile/([^/]*)")
      studivz_globals.profile_id = profile_id
      log.dbg("Your profile id: "..profile_id)

      -- Set chat status to offline - don't wanna miss messages...
      local code = string.match(file, "Chat_setStatus\" content=\"([^\"]*)\"")
      local formkey, iv = extract_security_pattern1(code)

      local post_uri = "http://www."..studivz_globals.domain.."/Ajax"
      local post_data = "iv="..iv.."&formkey="..formkey.."&checkcode="..
         "undefined&status=0"

      log.dbg("Posting data: "..post_data.." to: "..post_uri)

      local file,err = browser:post_uri(post_uri,post_data,
         {"X-Requested-With:XMLHttpRequest"})

      if not file then
         error_webpage(post_uri,err)
         return POPSERVER_ERR_NETWORK
      end

      return POPSERVER_ERR_OK
   else
      return POPSERVER_ERR_AUTH
   end

end
-- -------------------------------------------------------------------------- --
function quit(pstate)

   log.dbg("QUIT")
   local browser = studivz_globals.myBrowser
   local uri = "http://www."..studivz_globals.domain.."/Logout/"

   local file,_ = getPage(uri)
   if not file then return POPSERVER_ERR_NETWORK end

   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function quit_update(pstate)

   log.dbg("QUIT-UPDATE")

   local browser = studivz_globals.myBrowser
   local uri = "http://www."..studivz_globals.domain.."/Messages/"..
      studivz_globals.folder

   -- Pinboard
   if studivz_globals.folder == "Wall" then
      uri = "http://www."..studivz_globals.domain.."/Pinboard/"..
         studivz_globals.profile_id

      for i = 1, get_popstate_nummesg(pstate) do
         if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then

            local msgId = get_mailmessage_uidl(pstate,i)

            log.dbg("Retrieving page: "..uri)

            local file,_ = getPage(uri)
            if not file then return POPSERVER_ERR_NETWORK end


            local code = string.match(file,
               "Pinboard_delete\" content=\"([^\"]*)\"")
            local formkey, iv = extract_security_pattern1(code)

            local post_uri = "http://www."..studivz_globals.domain.."/Ajax"
            local post_data = "formkey="..formkey.."&iv="..iv.."&userId="..
               studivz_globals.profile_id.."&entryId="..
               studivz_globals.commentId[msgId].."&id="..
               studivz_globals.profile_id

            log.dbg("Posting data: "..post_data.." to: "..post_uri)

            local err = nil
            file,err = browser:post_uri(post_uri,post_data,
               {"X-Requested-With:XMLHttpRequest"})

            if not file then
               error_webpage(uri,err)
               return quit(pstate)
            end
         end
      end
      return quit(pstate)
   end

   local msgIds = ""

   for i = 1, get_popstate_nummesg(pstate) do
      if get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
         local uidl = get_mailmessage_uidl(pstate,i)
         msgIds = "messageIds%5B%5D="..uidl.."&"..msgIds
      end
   end

   if msgIds ~= "" then

      log.dbg("Retrieving page: "..uri)

      local file,_ = getPage(uri)
      if not file then return POPSERVER_ERR_NETWORK end

      local code = string.match(file, "Messages_action\" content=\"([^\"]*)\"")
      local formkey, iv = extract_security_pattern1(code)

      local post_uri = "http://www."..studivz_globals.domain.."/Ajax"
      local post_data = "formkey="..formkey.."&iv="..iv.."&delete=1&"..msgIds

      log.dbg("Posting data: "..post_data.." to: "..post_uri)

      local err = nil
      file,err = browser:post_uri(post_uri,post_data,
         {"X-Requested-With:XMLHttpRequest"})

      if not file then
         error_webpage(uri,err)
         return quit(pstate)
      end

      --log.dbg(file)
   end
   return quit(pstate)
end
-- -------------------------------------------------------------------------- --
function stat(pstate)
   if studivz_globals.stat_done == true then return POPSERVER_ERR_OK end

   local pageuri = "http://www."..studivz_globals.domain.."/Messages/"..
      studivz_globals.folder.."/p/%s"
   local page = studivz_globals.offset
   local browser = studivz_globals.myBrowser

   -- Pinboard
   if studivz_globals.folder == "Wall" then
      pageuri = "http://www."..studivz_globals.domain.."/Pinboard/"..
         studivz_globals.profile_id.."/p/%s"
   end

   -- this string will contain the uri to get. it may be updated by
   -- the check_f function, see later
   local uri = string.format(pageuri,page)

   -- The action for do_until

   local function action_file(file)

      if string.find(file,"<form name=\"Captcha\"") then
         log.error_print("CAPTCHA code detected!")
         return true,nil
      end

      local x = {}
      for entry in string.gmatch(file, "<div id=\"msg_(.-)<div class=\"body")
      do table.insert(x,entry) end

      if studivz_globals.folder == "Wall" then
         x = {}
         for entry in string.gmatch(file, "<div class=\"comment%-metainfo\">(.-)</li>") do
            table.insert(x,entry)
         end
      end

      -- the number of results
      local n = #x
      log.dbg("Found "..n.." messages on current page")

      if n == 0 then return true,nil end

      local nmesg_old = get_popstate_nummesg(pstate)
      set_popstate_nummesg(pstate,nmesg_old + n)

      -- gets all the results and puts them in the popstate structure
      for i=1,#x do

         local msg_status,uidl,profile,name,subject,date,time,pinboardbody,commentId
         if studivz_globals.folder ~= "Wall" then
            msg_status = string.match(x[i],"class=\"tr status_([^%s]+)")
            uidl = string.match(x[i],"(%d+)")
            profile = string.match(x[i],"Profile/([^\"]*)")
            if profile == nil then
               profile = "deleted-profile"
               name = string.match(x[i],"fromName float-left\">([^<]*)")
            else
               name = string.match(x[i],"title=\"([^\"]*)")
            end

            if studivz_globals.english_ui==false then
               subject = strtrim(string.match(x[i],"title=\"lesen\">([^<]*)</a>"))
               date,time = string.match(x[i],"<small>(.-) um (.-) Uhr")
            else
               subject = strtrim(string.match(x[i],"title=\"Read\">([^<]*)</a>"))
               local hour,min,am
               date,hour,min,am = string.match(x[i],"<small>(.-) at (.-):"..
                  "(.-) (.-)</small>")
               date = string.gsub(date, "/", ".")
               if am=="pm" then
                  hour = hour + 12
                  if hour>23 then hour=hour-24 end
               end
               time = hour..":"..min
            end
         else
            msg_status = "read"
            profile = string.match(x[i],"Profile/([^\"]*)")
            if profile == nil then profile = "deleted-profile" end
            uidl = string.match(x[i],"commentId\" type=\"hidden\" value=\"([^\"]*)")
            commentId = string.match(x[i],"commentId\" value=\"([^\"]*)")
            name = string.match(x[i],"class=\"profile\">([^<]*)")
            subject = "Pinboard#"..(nmesg_old+i)
            pinboardbody = string.match(x[i],"<div class=\"pinboard%-entry%-text\">(.-)</div>")

            if studivz_globals.english_ui==false then
               date,time = string.match(x[i],"<span class=\"datetime\">"..
               ".-am (.-) um (.-) Uhr")
            else
               local hour,min
               hour,min,date = string.match(x[i],"<span class=\"datetime\">"..
                  ".-at (.-):(.-) on (.-)</span>")
               date = string.gsub(date, "/", ".")
               -- inconsistent date format compared to INBOX/OUTBOX
               time = hour..":"..min
            end
         end

         if name == nil then name = mimer.encodeUTF8("Gelöschte Person") end
         name = strtrim(name)

         log.dbg(string.format("UIDL: %s, name: %s, subject: %s, date&time: "..
            "%s %s",uidl,mimer.decodeUTF8(name),
            mimer.decodeUTF8(subject),date,time))

         if studivz_globals.folder == "Wall" then subject = pinboardbody end

         subject = mimer.html2txtmail(subject, "http://www."..
            studivz_globals.domain)

         if studivz_globals.charset == "ISO-8859-1" then
            subject = mimer.decodeUTF8(subject)
            name = mimer.decodeUTF8(name)
         end

         local reply_email = "no-reply"
         if studivz_globals.use_profile_id == true then
            reply_email = profile
         end

         if studivz_globals.folder ~= "Outbox" then
            studivz_globals.sender_profile[uidl]=profile
            studivz_globals.sender_email[uidl]=
               reply_email.."@"..studivz_globals.domain
            studivz_globals.sender_name[uidl]=name

            studivz_globals.receiver_profile[uidl]=studivz_globals.profile_id
            studivz_globals.receiver_email[uidl]=studivz_globals.username
            studivz_globals.receiver_name[uidl]=studivz_globals.name
         else
            studivz_globals.sender_profile[uidl]=studivz_globals.profile_id
            studivz_globals.sender_email[uidl]=studivz_globals.username
            studivz_globals.sender_name[uidl]=studivz_globals.name

            studivz_globals.receiver_profile[uidl]=profile
            studivz_globals.receiver_email[uidl]=
               reply_email.."@"..studivz_globals.domain
            studivz_globals.receiver_name[uidl]=name
         end

         studivz_globals.subject[uidl]=subject
         studivz_globals.datetime[uidl]=build_date(date, time)
         studivz_globals.page[uidl]=page
         studivz_globals.msg_status[uidl]=msg_status
         studivz_globals.commentId[uidl]=commentId

         set_mailmessage_size(pstate,i+nmesg_old,"1024")
         set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
      end

      if studivz_globals.folder ~= "Wall" then
         local code = string.match(file, "<meta name=\"Messages_read"..
            studivz_globals.folder.."Message\" ".."content=\"([^\"]*)\"")

         studivz_globals.formkey = string.match(code, "formkey=([^&]*)&")
         studivz_globals.iv = string.match(code, "iv=(.*)")
      end

      return true,nil
   end

   -- check must control if we are not in the last page and
   -- eventually change uri to tell retrieve_file the next page to retrieve

   local function check_file(file)
      local nextpageuri = "/Messages/"..studivz_globals.folder.."/p/"

      -- Pinwall
      if studivz_globals.folder == "Wall" then
         nextpageuri = "/Pinboard/"..studivz_globals.profile_id.."/p/"
      end

      local pos,_ = string.find(file,
         "a href=\""..nextpageuri..(page + 1).."\"")

      if studivz_globals.limit ~= -1 and page >= studivz_globals.limit then
         log.dbg("Limit ("..studivz_globals.limit..") reached. Stop traversing pages.")
         return true
      end

      if pos ~= nil then
         -- change retrieve behavior
         log.dbg("There seems to be a page after page "..page)

         page = page + 1
         uri = string.format(pageuri,page)
         log.dbg("Going to: "..uri)

         -- continue the loop
         return false
      else
         log.dbg("No more pages.")
         return true
      end
   end

    -- this is simple and uri-dependent
   local function retrieve_file ()
      local file,err = getPage(uri)
      if not file then return POPSERVER_ERR_NETWORK end
      return file,err
   end

   -- initialize the data structure
   set_popstate_nummesg(pstate,0)

   -- do it
   if not support.do_until(retrieve_file,check_file,action_file) then
      log.dbg("Stat failed!")
      return POPSERVER_ERR_UNKNOWN
   end

   if os.date("%d.%m.%Y")~=studivz_globals.lastcheck and
      studivz_globals.currentversion ~=
      string.match(PLUGIN_VERSION,"([^ ]+)") or
      studivz_globals.checksum==false then
      local nmesg_old = get_popstate_nummesg(pstate)
      set_popstate_nummesg(pstate,nmesg_old+1)
      set_mailmessage_size(pstate,nmesg_old+1,"1024")
      set_mailmessage_uidl(pstate,nmesg_old+1,setmessage())
      if studivz_globals.currentversion ~=
         string.match(PLUGIN_VERSION,"([^ ]+)") then
         studivz_globals.checksum = true
      end
   end

   studivz_globals.stat_done = true
   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function uidl(pstate,msg)
   return common.uidl(pstate,msg)
end
-- -------------------------------------------------------------------------- --
function uidl_all(pstate)
   return common.uidl_all(pstate)
end
-- -------------------------------------------------------------------------- --
function list(pstate,msg)
   return common.list(pstate,msg)
end
-- -------------------------------------------------------------------------- --
function list_all(pstate)
   return common.list_all(pstate)
end
-- -------------------------------------------------------------------------- --
function rset(pstate)
   return common.rset(pstate)
end
-- -------------------------------------------------------------------------- --
function dele(pstate,msg)
   return common.dele(pstate,msg)
end
-- -------------------------------------------------------------------------- --
function noop(pstate)
   return common.noop(pstate)
end
-- -------------------------------------------------------------------------- --
function top(pstate,msg,lines,pdata)
   local uidl=get_mailmessage_uidl(pstate,msg)
   local s = build_mail_header(uidl) .. "\r\n"

   local a = stringhack.new()
   s = a:dothack(s,a)
   s = s .. "\0"

   popserver_callback(s,pdata)
   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function retr(pstate,msg,pdata)
   local browser = studivz_globals.myBrowser
   local uidl = get_mailmessage_uidl(pstate,msg)
   local page = studivz_globals.page[uidl]
   local uri  = "http://www."..studivz_globals.domain.."/Messages/"..
      studivz_globals.folder.."/messageId/"..uidl.."/p/"..page
   local post_uri = "http://www."..studivz_globals.domain.."/Ajax"

   if string.sub(uidl,1,string.len("InternalMessage-"))==
      "InternalMessage-" then
      local body = base64.decode(studivz_globals.checksum1)
      body = string.gsub(body,"$VER",studivz_globals.currentversion)
      if studivz_globals.checksum==false then
         body = base64.decode(studivz_globals.checksum2)
      end

      if studivz_globals.charset == "UTF8" then
         body = mimer.encodeUTF8(body)
      end

      local s = build_mail_header(uidl)..body.."\r\n"

      local a = stringhack.new()
      s = a:dothack(s,a)
      s = s .. "\0"

      popserver_callback(s,pdata)
      return POPSERVER_ERR_OK
   end

   if studivz_globals.folder == "Wall" then
      local body = studivz_globals.subject[uidl]

      if studivz_globals.charset == "UTF8" then
         body = mimer.encodeUTF8(body)
      end

      local s = build_mail_header(uidl)..body.."\r\n"

      local a = stringhack.new()
      s = a:dothack(s,a)
      s = s .. "\0"

      popserver_callback(s,pdata)
      return POPSERVER_ERR_OK
   end

   log.dbg("Retrieve message: "..uri)

   local body = nil

   local post_data = "&formkey="..studivz_globals.formkey.."&iv="..
      studivz_globals.iv.."&messageId="..uidl

   log.dbg("Posting data: \""..post_data.."\" to: "..post_uri)

   local file,err = browser:post_uri(post_uri,post_data,
      {"X-Requested-With:XMLHttpRequest"})

   if not file then
      error_webpage(post_uri,err)
      return POPSERVER_ERR_NETWORK
   end

   studivz_globals.formkey = string.match(file, "formkey\":\"([^\"]*)\"")
   studivz_globals.iv = string.match(file, "iv\":\"([^\"]*)\"")

   body = string.match(file, "<div class=\\\"body_text\\\">\\n(.-)<\\/div>")

   if studivz_globals.folder == "Outbox" then
      body = string.match(file, "<div class=\\\"body_text\\\""..
         ">\\n        (.-)<\\/div>")
   end

   --log.dbg(body)

   if body==nil then
      log.error_print("Could not find BODY - probably StudiVz.de has just "..
         "changed its HTML format?!? - Contact the author for an update "..
         "request of the plugin.")
      return POPSERVER_ERR_UNKNOWN
   end

   -- convert \uXXXX unicode to unicode characters
   body = string.gsub(body,"\\u(%w%w%w%w)", function (c)
      local num = tonumber("0x"..c, 16)
      if num > 255 then return "" end
      return string.char(num)
   end)

   body = string.gsub(body,"\\/", "/")

   body = strtrim(body)

   body = mimer.html2txtmail(body, "http://www."..studivz_globals.domain)

   if studivz_globals.charset == "UTF8" then
      body = mimer.encodeUTF8(body)
   end

   local s = build_mail_header(uidl)..body.."\r\n"

   local a = stringhack.new()
   s = a:dothack(s,a)
   s = s .. "\0"

   popserver_callback(s,pdata)

   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function sendmessage(recipients,subject,body,reference)
   local browser = studivz_globals.myBrowser
   local uri  = "http://www."..studivz_globals.domain.."/Messages/WriteMessage"

   log.dbg("Sending message to: "..uri)

   local file,_ = getPage(uri)
   if not file then return POPSERVER_ERR_NETWORK end

   --log.dbg(file)

   local pos,_,_ = string.find(file,"id=\"emoticonArray\"")
   local formkey, iv = extract_security_pattern2(file, pos+1)

   local recipientIds = ""
   for i = 1,#recipients do
      recipientIds = "recipientIds%5B%5D="..recipients[i].."&"..recipientIds
   end

   body = body.."\n\---\nSent through FreePOPs StudiVz Plugin"

   local post_data = "subject="..curl.escape(subject).."&message="..
      curl.escape(body).."&"..recipientIds.."formkey="..formkey.."&iv="..iv..
      "&searchfield=".."&backlink=&"..
      "recipientIdForHistory="..studivz_globals.profile_id

   if reference ~= nil then
      post_data = post_data.."&messageId="..reference.."&state=answered"
   else
      post_data = post_data.."&messageId=&state="
   end

   log.dbg("Posting data: \""..post_data.."\" to: "..uri)

   local file,err = browser:post_uri(uri,post_data)
   if not file then
      error_webpage(uri,err)
      return POPSERVER_ERR_NETWORK
   end

   --log.dbg(file)

   local error = string.match(file,"<p class=\"error\">([^<]*)<")
   if error ~= nil then return error end

   return POPSERVER_ERR_OK
end
-- -------------------------------------------------------------------------- --
function setmessage()
   local uidl="InternalMessage-"..os.date("%Y.%m.%m")

   studivz_globals.sender_profile[uidl]="no-profile"
   studivz_globals.sender_email[uidl]="no-reply@"..studivz_globals.domain
   studivz_globals.sender_name[uidl]="FreePOPs StudiVz/MeinVz/SchülerVz "..
      "Plugin"

   studivz_globals.receiver_profile[uidl]=studivz_globals.profile_id
   studivz_globals.receiver_email[uidl]=studivz_globals.username
   studivz_globals.receiver_name[uidl]=studivz_globals.name

   studivz_globals.subject[uidl]=base64.decode("RWluZSBuZXVlIFZlcnNpb24gaXN"..
      "0IHZlcmb8Z2Jhci4vQSBuZXcgdmVyc2lvbiBpcyBhdmFpbGFibGUu")
   if studivz_globals.checksum==false then
      studivz_globals.subject[uidl]=base64.decode("RWluZSBrbGVpbmUgU3BlbmRl"..
      "Li4uL1BsZWFzZSBkb25hdGUuIDotKQ==")
   end
   studivz_globals.datetime[uidl]=build_date(os.date("%d.%m.%Y"), "00:00")
   studivz_globals.page[uidl]="0"
   studivz_globals.msg_status[uidl]="read"

   return uidl
end
-- -------------------------------------------------------------------------- --
function build_mail_header(uidl)
   local header =
      "Message-ID: <"..uidl.."@"..studivz_globals.domain..">\r\n"..
      "Date: "..studivz_globals.datetime[uidl].."\r\n"..
      "X-"..studivz_globals.domain.."-Sender-Profile-ID: "..
      studivz_globals.sender_profile[uidl].."\r\n"..
      "X-"..studivz_globals.domain.."-Recipient-Profile-ID: "..
      studivz_globals.receiver_profile[uidl].."\r\n"..
      "From: "..studivz_globals.sender_name[uidl].." <"..
      studivz_globals.sender_email[uidl]..">\r\n"..
      "To: "..studivz_globals.receiver_name[uidl]..
      " <"..studivz_globals.receiver_email[uidl]..">\r\n"

   local subject = studivz_globals.subject[uidl]
   if studivz_globals.folder == "Wall" then
      subject = string.gsub(subject,"[\r\n]", " ")
      subject = studivz_globals.pinwall_subject_prexix..
         string.sub(subject, 1, 25).."..."
   end

   local xmailer = "FreePOPS "..PLUGIN_NAME.." Plugin [version "..
      PLUGIN_VERSION.."] by André Martin"
   if studivz_globals.charset == "UTF8" then
      xmailer = mimer.encodeUTF8(xmailer)
   end

   header = header..
      "Subject: "..subject.."\r\n"..
      "X-Mailer: "..xmailer.."\r\nMIME-Version: 1.0\r\n"..
      "Content-Type: text/plain; charset=\""..studivz_globals.charset..
      "\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\n"

   return header
end
-- -------------------------------------------------------------------------- --
function extract_security_pattern1(content)
   local formkey = string.match(content, "formkey=([^&]*)&")
   local iv = string.match(content, "iv=([^\"]*)")
   return formkey, iv
end
-- -------------------------------------------------------------------------- --
function extract_security_pattern2(content,pos)
   local formkey =
      string.match(content,"name=\"formkey\" value=\"([^\"]*)\"", pos+1)
   local iv =
      string.match(content,"name=\"iv\" value=\"([^\"]*)\"", pos+1)
   return formkey, iv
end
-- -------------------------------------------------------------------------- --
function getPage(uri)
   local browser = studivz_globals.myBrowser
   local retry_counter = studivz_globals.retries
   local file,err
   repeat
      local retry = false
      file,err = browser:get_uri(uri)

      if not file then
         error_webpage(uri,err)
         if string.find(err, "refused") or string.find(err, "timeout") then
            retry=true
            log.dbg("Retrying "..retry_counter.." times...")
         end
         retry_counter = retry_counter - 1
      end
   until retry==false or retry_counter == 0

   return file,err
end
-- -------------------------------------------------------------------------- --
function error_webpage(uri,err)
   log.dbg("Error occured while retrieving page: "..uri.." / "..err)
   log.error_print("Error occured while retrieving page: "..uri.." / "..err)
end
-- -------------------------------------------------------------------------- --
function strtrim(str)
   -- trim trailing whitespaces
   local trim_str,_ = string.gsub(str, "^%s*(.-)%s*$", "%1")
   return trim_str
end
-- -------------------------------------------------------------------------- --
function build_date(date,time)
   local day=string.match(date,"(%d*).")
   local month=string.match(date,day..".(%d*).")
   local year=string.match(date,day.."."..month..".(%d*)")

   -- hack for missing year in Inbox - tzz tzz tzz
   if year == "" then
      if studivz_globals.currentMonth == 0 then
         year=os.date("%Y")
         studivz_globals.currentYear = year
      else
         if studivz_globals.currentMonth < month then
            studivz_globals.currentYear = studivz_globals.currentYear - 1
         end
         year=studivz_globals.currentYear
      end
      studivz_globals.currentMonth = month
   end

   local hour=string.match(time,"(%d*):")
   local mins=string.match(time,hour..":(%d*)")
   local dd=month.."/"..day.."/"..year.." "..hour..":"..mins..":00"

   dd=getdate.toint(dd)

   local timezone = "+0100"
   if dd > getdate.toint("03/27/2005 2:00:00") and
      dd < getdate.toint("10/30/2005 3:00:00") or
      dd > getdate.toint("03/26/2006 2:00:00") and
      dd < getdate.toint("10/29/2006 3:00:00") or
      dd > getdate.toint("03/25/2007 2:00:00") and
      dd < getdate.toint("10/28/2007 3:00:00") or
      dd > getdate.toint("03/30/2008 2:00:00") and
      dd < getdate.toint("10/26/2008 3:00:00") or
      dd > getdate.toint("03/29/2009 2:00:00") and
      dd < getdate.toint("10/25/2009 3:00:00") or
      dd > getdate.toint("03/28/2010 2:00:00") and
      dd < getdate.toint("10/31/2010 3:00:00") or
      dd > getdate.toint("03/27/2011 2:00:00") and
      dd < getdate.toint("10/30/2011 3:00:00")
   then timezone = "+0200" end

   return(os.date("%a, %d %b %Y %H:%M:%S",dd).." "..timezone)
end

-- EOF
-- ************************************************************************** --
