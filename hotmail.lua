-- ************************************************************************** --
--  FreePOPs @hotmail.com webmail interface
--  
--  Released under the GNU/GPL license
--  Written by Russell Schwager <russell822@yahoo.com>
--  contributions from D. Milne <drmilne (at) safe-mail (.) net>
-- ************************************************************************** --

-- Globals
--
PLUGIN_VERSION = "0.2.20100121"
PLUGIN_NAME = "hotmail.com"
PLUGIN_REQUIRE_VERSION = "0.2.8"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=hotmail.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Russell Schwager", "D. Milne", "Peter Collingbourne" }
PLUGIN_AUTHORS_CONTACTS = {"russell822 (at) yahoo (.) com", "drmilne (at) safe-mail (.) net", "pcc03 (at) doc (.) ic (.) ac (.) uk>"}
PLUGIN_DOMAINS = { "@hotmail.com","@msn.com","@webtv.com",
      "@charter.com", "@compaq.net","@passport.com", 
      "@hotmail.de", "@hotmail.it", "@hotmail.co.uk", 
      "@hotmail.co.jp", "@hotmail.fr", "@messengeruser.com",
      "@hotmail.com.ar", "@hotmail.co.th", "@hotmail.com.tr",
      "@windowslive.com", "@milanosemplice.it"
      }
PLUGIN_PARAMETERS = {
	{name="folder", description={
		it=[[La cartella che vuoi ispezionare. Quella di default &egrave; Inbox.]],
		en=[[The folder you want to interact with. Default is Inbox.]]}
	},
	{name="folderid", description={
		en=[[The folder id you want to interact with. Default is Inbox.  Using this option
		will override the folder parameter.]]}
	},
	{name = "emptyjunk", description = {
		en = [[
Parameter is used to force the plugin to empty the junk folder when it is done
pulling messages.  Set the value to 1.]]
		}	
	},
	{name = "emptytrash", description = {
		it = [[ Viene usato per forzare il plugin a svuotare il cestino quando ha finito di scaricare i messaggi. Se il valore &egrave; 1 questo comportamento viene attivato.]],
		en = [[
Parameter is used to force the plugin to empty the trash when it is done
pulling messages.  Set the value to 1.]]
		}	
	},
	{name = "markunread", description = {
		it = [[ Viene usato per far s&igrave; che il plugin segni come non letti i messaggi che scarica. Se il valore &egrave; 1 questo comportamento viene attivato.]],
		en = [[ Parameter is used to have the plugin mark all messages that it
pulls as unread.  If the value is 1, the behavior is turned on.]]
		}
	},
	{name = "maxmsgs", description = {
		en = [[
Parameter is used to force the plugin to only download a maximum number of messages. ]]
		}	
	},
	{name = "domain", description = {
		en = [[
Parameter is used to override the domain in the email address.  This is used so that users don't
need to add a mapping to config.lua for a hosted hotmail account. ]]
		}	
	},
	{name = "keepmsgstatus", description = {
		en = [[
Parameter is used to maintain the status of the message in the state it was before being pulling.  If the value is 1, the behavior is turned on
and will override the markunread flag.. ]]
		}	
	},
}
PLUGIN_DESCRIPTIONS = {
	it=[[
Questo plugin vi permette di scaricare la posta da mailbox con dominio della famiglia di @hotmail.com. 
Per usare questo plugin dovrete usare il vostro indirizzo email completo come 
nome utente e la vostra vera password come password.]],
	en=[[
This plugin lets you download mail from @hotmail.com and similar mailboxes. 
To use this plugin you have to use your full email address as the username
and your real password as the password.  For support, please post a question to
the forum instead of emailing the author(s).]]
}

-- Domains supported:  hotmail.com, msn.com, webtv.com, charter.com, compaq.net,
--                     passport.com

-- ************************************************************************** --
--  Global Strings
-- ************************************************************************** --

local globals = {
  -- Max password length in the login page
  --
  nMaxPasswordLen = 16,

  -- Server URL
  --
  strLoginUrl = "http://mail.live.com/",

  strDefaultLoginPostUrl = "https://login.live.com/ppsecure/post.srf",

  -- Login strings
  -- TODO: Define the HTTPS version
  --
  strLoginPostData = "login=%s&domain=%s&passwd=%s&sec=&mspp_shared=&PwdPad=%s&PPSX=Pas&LoginOptions=3",
  strLoginPaddingFull = "xxxxxxxxxxxxxxxx",
  strLoginFailed = "Login Failed - Invalid User name and/or password",

  -- Expressions to pull out of returned HTML from Hotmail corresponding to a problem
  --
  strRetLoginBadLogin = "(memberservices)",
  strRetLoginSessionExpired = "(Sign in)",
  strRetLoginSessionExpiredLiveLight = '(href="ManageFoldersLight%.aspx)',
  strRetLoginSessionErrorLive = '(HM%.FppError)',
  strRetLoginSessionExpiredLive = '(new HM%.FppReturnPackage%(0,new HM)',
  strRetStatBusy = "(form name=.hotmail.)",
  
  -- Regular expression to extract the mail server
  --
  
  -- Extract the server to post the login data to
  --
  strLoginPostUrlPattern1='action="([^"]+)"',
  strLoginPostUrlPattern2='type=["]?hidden["]? name="([^"]*)".* value="([^"]*)"',
  strLoginPostUrlPattern3='g_DO."%s".="([^"]+)"',
  strLoginPostUrlPattern4='var g_QS="([^"]+)";',
  strLoginPostUrlPattern5='name="PPFT" id="[^"]+" value="([^"]+)"',
  strLoginDoneReloadToHMHome1='URL=([^"]+)"',
  strLoginDoneReloadToHMHome2='%.location%.replace%("([^"]+)"',
  strLoginDoneReloadToHMHome3="location='([^']+)'",
--  strLoginDoneReloadToHMHome3='location=.([^"%']+)',
  strLoginDoneReloadToHMHome4="img src='([^']+)'",

  -- Paco
  strLoginDoneReloadToHMHome5='img src="([^"]+)"',

  strLoginDoneReloadToReloadPage='window%.location=\'([^\']+)\'',
 
  -- Pattern to detect if we are using the live or classic version
  --
  strLiveCheckPattern = '(TodayLight%.aspx)',
  strLiveCheckPattern2 = '(todayPageOptOut: true)',
  strClassicCheckPattern = '(Windows Live Mail was not able to sign into your account at this time)',
  strLiveMainPagePattern = '<frame.-name="main" src="([^"]+)"',
  -- cdmackie: some version do not have this anymore, so use something common
  -- strLiveLightPagePattern = 'href="(StylesheetTodayLight)',
  strLiveLightPagePattern = '"MailClassic"',  

  -- Get the crumb value that is needed for every command
  --
  strRegExpCrumb = '&a=([^"&]*)[&"]',
  strRegExpCrumbLive = '"sessionidhash" : "([^"]+)"',                    
  strRegExpUser = '"authuser" : "([^"]+)"',
  strRegExpCrumbLiveLight = 'SessionId:"([^"]+)"',
  strRegExpUserLiveLight = 'AuthUser:"([^"]+)"',

  -- MSN Inbox Folder Id
  --
  strPatMSNInboxId = "HMFO%('(%d+)'%)[^>]+><img src=.http://[^/]+/i%.p%.folder%.inbox%.gif",

  -- Image server pattern
  --
  strImgServerPattern = 'img src="(http://[^/]*)/spacer.gif"',
  strImgServerLivePattern = 'img src="(http://[^/]*)/mail/',

  -- Junk and Trash Folder pattern
  -- 
  strPatLiveTrashId = '"sysfldrtrash".-"([^"]+)"',
  strPatLiveJunkId = '"sysfldrjunk".-"([^"]+)"',

  -- Folder id pattern
  --
  strFolderPattern = '<a href="[^"]+curmbox=([^&]+)&[^"]+" >', 
  strFolderLivePattern = '%("([^"]+)","',
  strFolderLiveInboxPattern = 'sysfldrinbox".-"([^"]+)"',
  strFolderLiveLightInboxPattern = 'fst="NONE".-href="InboxLight%.aspx%?(FolderID=[^&]+[^"]+)"[^>]+>',
  strFolderLiveLightFolderIdPattern = 'FolderID=([^&]+)&[.]*',
  strFolderLiveLightNPattern = '&n=([^&]+)[.]*',
  strFolderWithIdLiveLightNPattern = '&.-n=([^"]+)"',  
  strFolderLiveLightTrashPattern = 'i_trash%.gif" border="0" alt=""/></td>.-<td class="dManageFoldersFolderNameCol"><a href="InboxLight%.aspx%?FolderID=([^&]+)&',
  strFolderLiveLightTrash2Pattern = 'href="InboxLight%.aspx%?FolderID=([^&]+)&[^"]+"[^>]+><img src="[^"]+" class="i_trash"',
  strFolderLiveLightJunkPattern = 'i_junkfolder%.gif" border="0" alt=""/></td>.-<td class="dManageFoldersFolderNameCol"><a href="InboxLight%.aspx%?FolderID=([^&]+)&',
  strFolderLiveLightJunk2Pattern = 'href="InboxLight%.aspx%?FolderID=([^&]+)&[^"]+"[^>]+><img src="[^"]+" class="i_junkfolder"',
  strFolderLiveLightPattern = 'href="InboxLight%.aspx%?(FolderID=[^&]+[^"]+)" title="', 
  strFolderLiveLightManageFoldersPattern = 'href="ManageFoldersLight%.aspx%?n=([^"]+)"',

  -- Pattern to determine if we have no messages
  --
  strMsgListNoMsgPat = "(<td colspan=10>)", --"(There are no messages in this folder)",

  -- Pattern to determine the total number of messages
  --
  strMsgListCntPattern = "<td width=100. align=center>([^<]+)</td><td align=right nowrap>",
  strMsgListCntPattern2 = "([%d]+) [MmNnBbVv][eai]",
  --strMsgListLiveLightCntPattern = '<div class=".-ItemListHeaderMsgInfo".->.-(%d+).-</div>',
  strMsgListLiveLightCntPattern = '>(%d+) %a+</div><div class="PageNavigation FloatRight"', 
  
  -- Used by Stat to pull out the message ID and the size
  --
  strMsgLineLitPattern = ".*<tr>.*<td>[.*]{img}.*</td>.*<td>.*<img>.*</td>.*<td>[.*]{img}.*</td>.*<td>.*<input>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*</td>.*</tr>",
  strMsgLineAbsPattern = "O<O>O<O>[O]{O}O<O>O<O>O<O>O<O>O<O>[O]{O}O<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>",

  -- Pattern used by Stat to get the next page in the list of messages
  --
  strMsgListNextPagePattern = '(nextpg%.gif\\?" border=0></a>)',
  strMsgListNextPagePatLiveLight = '<a href=\\?"([^"]+)\\?"[^>]*><img src=\\?"[^_]*_nextpage.gif\\?"',
  strMsgListNextPagePatLiveLight2 = '<a href=\\?"([^"]+)\\?"[^>]*><img src=\\?"[^"]+\\?" class=\\?"i_nextpage\\?"',
  strMsgListNextPagePatLiveLight3 = 'pnCur=\\?"([^\\"]+)\\?" pnAm=\\?"([^\\"]+)\\?" pnAd=\\?"([^\\"]+)\\?" pnDir=\\?"NextPage\\?" pnMid=\\?"([^\\"]+)\\?" [^>]*>.-<[^>]+>.-<img [^_]*_nextpage\\?"',
  strMsgListNextPagePatLiveLight4 = '<li id=\\?"nextPageLink\\?" pnCur=\\?"([^\\"]+)\\?" pnAm=\\?"([^\\"]+)\\?" pnAd=\\?"([^\\"]+)\\?" pnDir=\\?"NextPage\\?" pnMid=\\?"([^\\"]+)\\?" pnSkip=\\?"0\\?">',

  -- Pattern used to detect a bad STAT page.
  --
  strMsgListGoodBody = 'i%.p%.attach%.gif',

  -- Pattern used in the Live interface to get the message info
  --
  strMsgLivePatternOld = ',"([^"]+)","[^"]+","[^"]+",[^,]+,[^,]+,[^,]+,[^,]+,"([^"]+)"',
  strMsgLivePattern1 = 'class=.-SizeCell.->([^<]+)</div>',
  strMsgLivePattern2 = 'new HM%.__[^%(]+%("([^"]+)",[tf][^,"]+,"[^"]+",[^,]+,[^,]+',
  strMsgLiveLightPatternOld = 'ReadMessageId=([^&]+)&[^>]+>.-</a></td>.-<td [^>]+>.-</td>.-<td [^>]+>([^<]+)</td>',
  -- cdmackie 2008-07-02: new message patterns for live light
  strMsgLiveLightPattern = '(<tr[^<>]-id=\\?"[^\\"]+\\?" msg=\\?"msg\\?"[^>]->)(.-)</tr>',
  strMsgLiveLightPatternUidl = 'id=\\?"([^\\"]+)\\?"',
  strMsgLiveLightPatternMad = 'mad=\\?"([^\\"]+)\\?"',
  strMsgLiveLightPatternSize = 'class=\\?"TextAlignRight\\?"[^>]->(.-)</td>',
  strMsgLiveLightPatternUnread = "(Unread)",

  -- The amount of time that the session should time out at.
  -- This is expressed in seconds
  --
  nSessionTimeout = 28800,  -- 8 hours!

  -- Defined Mailbox names - These define the names to use in the URL for the mailboxes
  --
  strNewFolderPattern = "(curmbox=0)",
  strFolderPrefix = "00000000-0000-0000-0000-000",
  strInbox = "F000000001",

  -- Command URLS
  --
  strCmdBaseLive = "http://%s/mail/",
  strCmdBrowserIgnoreLive = "http://%s/mail/mail.aspx?skipbrowsercheck=true",
  strCmdMsgList = "http://%s/cgi-bin/HoTMaiL?a=%s&curmbox=%s",
  strCmdMsgListNextPage = "&page=%d&wo=",
  strCmdMsgListLiveLight = "http://%s/mail/InboxLight.aspx?FolderID=%s&InboxSortBy=Date&",
  strCmdMsgListLive = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.GetFolderData&ptid=0&a=%s&au=%s", 
  strCmdMsgListPostLiveOld = "cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=GetFolderData&d=%s,Date,%s,false,0,%s,0,,&MailToken=",
  strCmdMsgListPostLive = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=GetFolderData&d=%s,Date,%s,false,0,%s,0,"","",true,false&v=1&mt=%s',

  -- cdmackie 2008-07-02: new calls for STAT for live light
  strCmdMsgListLive3 = "mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.GetInboxData&ptid=0&a=%s&au=%s", 
  strCmdMsgListPostLive3 = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=GetInboxData&d=true,true,{%%22%s%%22,25,NextPage,0,Date,false,%%22%s%%22,%%22%s%%22,%s,%s,false,%%22%%22,false,%s},false,null&v=1&mt=%s',
	-- doglan @ 2009-10-10: Updated URL
  strCmdMsgListPostLive4 = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=GetInboxData&d=true,false,true,{%%22%s%%22,NextPage,0,Date,false,%%22%s%%22,%%22%s%%22,%s,%s,false,%%22%%22,%s,-1,Off},false,null&v=1&mt=%s',
	
  strCmdDelete = "http://%s/cgi-bin/HoTMaiL",
  strCmdDeletePost = "curmbox=%s&_HMaction=delete&wo=&SMMF=0", -- &<MSGID>=on
  strCmdDeleteLive = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.MoveMessages&ptid=0&a=%s&au=%s", 
  strCmdDeletePostLiveOld = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MoveMessages&d="%s","%s",[%s],[{"%%5C%%7C%%5C%%7C%%5C%%7C0%%5C%%7C%%5C%%7C%%5C%%7C00000000-0000-0000-0000-000000000001%%5C%%7C632901424233870000",{2,"00000000-0000-0000-0000-000000000000",0}}],null,null,0,false,Date&v=1',
  strCmdDeletePostLive = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MoveMessages&d="%s","%s",[%s],[{"0%%5C%%7C0%%5C%%7C8C9BDFF65883200%%5C%%7C00000000-0000-0000-0000-000000000001",null}],null,null,0,false,Date,false,true&v=1&mt=%s',

  strCmdDeleteLiveLight = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.MoveMessagesToFolder&ptid=0&a=%s&au=%s",  
  strCmdDeletePostLiveLight = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MoveMessagesToFolder&d="%s","%s",[%s],[%s],{"%s",25,FirstPage,0,Date,false,"00000000-0000-0000-0000-000000000000","",1,2,false,"",false,0},null&v=1&mt=%s',
	-- doglan @ 2009-10-10: Updated URL
  strCmdDeletePostLiveLight2 = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MoveMessagesToFolder&d="%s","%s",[%s],[%s],{"%s",FirstPage,0,Date,false,"00000000-0000-0000-0000-000000000000","",1,2,false,"",0,-1,Off}&v=1&mt=%s',
  strCmdMsgView = "http://%s/cgi-bin/getmsg?msg=%s&imgsafe=y&curmbox=%s&a=%s",
  strCmdMsgViewRaw = "&raw=0",
  strCmdMsgViewLive = "http://%s/mail/GetMessageSource.aspx?msgid=%s&gs=true",
  strCmdEmptyTrash = "http://%s/cgi-bin/dofolders?_HMaction=DoEmpty&curmbox=F000000004&a=%s&i=F000000004",
  strCmdLogout = "http://%s/cgi-bin/logout",
  strCmdLogoutLive = "http://%s/mail/logout.aspx",
  strCmdFolders = "http://%s/cgi-bin/folders?&curmbox=F000000001&a=%s",
  strCmdFoldersLiveLight = "http://%s/mail/ManageFoldersLight.aspx?n=%s",
  strCmdMsgUnreadLive = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.MarkMessages&ptid=0&a=%s&au=%s", 
  strCmdMsgUnreadLivePost = "cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MarkMessages&d=false,[%s]",
  strCmdEmptyTrashLive = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.EmptyFolder&ptid=0&a=&au=%s", 
  strCmdEmptyTrashLivePost = "cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=EmptyFolder&d=%s,1&v=1&mt=%s",
  strCmdEmptyTrashLiveLight = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.ClearFolder&ptid=0&a=%s&au=%s", 
  strCmdEmptyTrashLiveLightPost = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=ClearFolder&d="%s",{"%s",25,FirstPage,0,Date,false,"00000000-0000-0000-0000-000000000000","",1,2,false,"",false,0}&v=1&mt=%s',
  strCmdMsgReadLive = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.MarkMessages&ptid=0&a=&au=%s", 
  strCmdMsgReadLivePost = "cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MarkMessages&d=true,[%s]&v=1&mt=%s",
  strCmdMsgReadLiveLight = "http://%s/mail/mail.fpp?cnmn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox.MarkMessagesReadState&ptid=0&a=%s&au=%s", 

  -- Submitted by Barlad
	-- doglan @ 2009-10-10: Updated URL (["%s"],)
  --strCmdMsgReadLiveLightPost = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MarkMessagesReadState&d=true,["%s"],{"%s",FirstPage,0,Date,false,"00000000-0000-0000-0000-000000000000","",1,2,false,"",18,-1,Off}&v=1&mt=%s',
  strCmdMsgReadLiveLightPost = 'cn=Microsoft.Msn.Hotmail.Ui.Fpp.MailBox&mn=MarkMessagesReadState&d=true,["%s"],[{%%220%%5C%%7C0%%5C%%7C8CC610430EE14B0%%5C%%7C%%5C%%7C%%22}],{"%s",FirstPage,0,Date,false,"00000000-0000-0000-0000-000000000000","",1,2,false,"",71,-1,Off}&v=1&mt=%s',
}

-- ************************************************************************** --
--  State - Declare the internal state of the plugin.  It will be serialized and remembered.
-- ************************************************************************** --

internalState = {
  bStatDone = false,
  bLoginDone = false,
  strUser = nil,
  strPassword = nil,
  browser = nil,
  strMailServer = nil,
  strImgServer = nil,
  strDomain = nil,
  strCrumb = "",
  strMBox = nil,
  strMBoxName = nil,
  bEmptyTrash = false,
  bEmptyJunk = false,
  loginTime = nil,
  bMarkMsgAsUnread = false,
  bLiveGUI = false,
  bLiveLightGUI = false,
  strTrashId = nil,
  strJunkId = nil,
  statLimit = nil,
  strUserId = "",
  strMT = "",
  bKeepMsgStatus = false,
  msgIds = {},
  unreadStatus = {},
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

-- Computes the hash of our state.  Concate the user, domain, mailbox and password
--
function hash()
  return (internalState.strUser or "") .. "~" ..
         (internalState.strDomain or "") .. "~"  ..
         (internalState.strMBoxName or "") .. "~"  ..
         (internalState.strMBox or "") .. "~"  ..
         (internalState.statLimit or "") .. "~"  ..
	 internalState.strPassword -- this asserts strPassword ~= nil
end

function getPage(browser, url, post, name)
  local try = 0

  if post ~= nil then
    log.dbg("LOADING: " .. url .. "\nPOST: " .. post .. "\n")
  else
    log.dbg("LOADING: " .. url .. "\n")
  end

  while (try < 3) do
    try = try + 1
    local body, err = fetchPage(browser, url, post, name)

    if (body == nil) then
      log.error_print("Tried to load: " .. url .. " and got error: " .. err)
      return nil, err
    else			
      if (string.find(body, "We are experiencing higher than normal volume") == nil and 
          (string.find(body, "<[Hh][Tt][Mm][Ll]") ~= nil or string.find(body, "new HM.FppReturnPackage") ~= nil) and
          string.find(body, "MSN Hotmail %- ERROR") == nil ) then
        return body, err
      end
      -- This is a little bizarre -- It seems the condition should not be here.
      --
      local newurl = string.match(body, 'Object moved to <a href="([^"]+)"')
      if (newurl ~= nil) then
        return getPage(browser, newurl, nil, name)
      end
      log.dbg("Attempt to load: " .. url .. " failed in attempt: " .. try)
    end
  end

  return nil, nil
end

function fetchPage(browser, url, post, name)
  log.dbg("Fetching Page: " .. name .. " - " .. url)
  local body, err
  if (post == nil) then
    body, err = browser:get_uri(url)
  else
    body, err = browser:post_uri(url, post)
  end
  
  local lastpage = browser:whathaveweread()
  if (lastpage ~= nil and string.match(lastpage, "browsersupport")) then
    if (post == nil) then
      body, err = browser:get_uri(url)
    else
      body, err = browser:post_uri(url, post)
    end
  end
  
  return body, err
end


function CheckForMessageAtLogin(browser, url, body)
  local err
  -- Let's look for a message at login
  --
  local hasMsgAtLogin = false
  url = string.match(body, '<form name="MessageAtLoginForm" method="post" action="([^"]+)"')
  if (url ~= nil) then
    log.dbg("Found Message at login")
    hasMsgAtLogin = true
    url = string.gsub(url, "&amp;", "&")
	local post = ""
    for name, value in string.gfind(body, '<input type="hidden" name="([^"]+)".-value="([^"]+)"') do
	  post = post .. name .. "=" .. value .. "&"
	end

	post = post .. "TakeMeToInbox=Continue"
	post = string.gsub(post, "/", "%%2F")
	post = string.gsub(post, "+", "%%2B")
	
	url = "http://" .. browser:wherearewe() .. "/mail/" .. url
    log.dbg("Leaving message at login: " .. url .. " - " .. post)
    body, err = getPage(browser, url, post, "Message At Login Form")
  end

  return url, body, err, hasMsgAtLogin
end


-- Issue the command to login to Hotmail
--
function loginHotmail()
  --log.dbg("Entering login")

  -- Check to see if we've already logged in
  --
  if internalState.loginDone then
    return POPSERVER_ERR_OK
  end

  -- Create a browser to do the dirty work
  --
  internalState.browser = browser.new("Mozilla/5.0 (Windows; U; Windows NT 5.1; en) AppleWebKit/522.11.3 (KHTML, like Gecko) Version/3.0 Safari/522.11.3")
  --internalState.browser = browser.new("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.12) Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12")

  -- Define some local variables
  --
  local username = internalState.strUser
  local password = internalState.strPassword --curl.escape(internalState.strPassword)
  local passwordlen = string.len(internalState.strPassword)
  local domain = internalState.strDomain
  local url = globals.strLoginUrl
  local browser = internalState.browser
  local postdata = nil
  local name, value  
    
  -- DEBUG - Set the browser in verbose mode
  --
--  browser:verbose_mode()

  -- Enable SSL
  --
  browser:ssl_init_stuff()

  -- Retrieve the login page.
  --
  local body, err = getPage(browser, url, nil, "Live Mail Login Page")

  -- No connection
  --
  if body == nil then
    log.error_print("Login failed: Can't get the page: " .. url .. ", Error: " .. (err or "none"));
    return POPSERVER_ERR_NETWORK
  end

  -- Hotmail will return with the login page.  This page supports a slew of domains.
  -- Pull out the place where we need to post the login information.  Post the form
  -- to login.
  --
  local pattern = string.format(globals.strLoginPostUrlPattern3, domain)
  url = string.match(body, pattern)
  local str = string.match(body, globals.strLoginPostUrlPattern4)
  local str2 = string.match(body, globals.strLoginPostUrlPattern5)
  if (str == nil or str2 == nil) then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_NETWORK
  end
  if (url == nil) then 
    url = globals.strDefaultLoginPostUrl 
  end
  url = url .. "?" .. str 

  local padding = string.sub(globals.strLoginPaddingFull, 0, globals.nMaxPasswordLen - passwordlen)
  postdata = string.format(globals.strLoginPostData, username, domain, curl.escape(password), padding)
  postdata = postdata .. "&PPFT=" .. str2

  log.dbg("Hotmail - Sending login information to: " .. url)
  body, err = browser:post_uri(url, postdata)
  if (body == nil) then
      log.error_print(globals.strLoginFailed .. " Sent login info to: " .. (url or "none") .. " and got something we weren't expecting(0):\n" .. err);
      return POPSERVER_ERR_NETWORK
  end

  -- The login page returns a page where a form needs to be submitted.  We'll do it
  -- manually.  Extract the form elements and post the data
  --
  url = string.match(body, globals.strLoginPostUrlPattern1)
  local postdata = nil
  local name, value  
  for name, value in string.gfind(body, globals.strLoginPostUrlPattern2) do
    value = curl.escape(value)
    if postdata ~= nil then
      postdata = postdata .. "&" .. name .. "=" .. value  
    else
      postdata = name .. "=" .. value 
    end
  end
  if (postdata ~= nil) then
    body, err = getPage(browser, url, postdata, "Login Form Page")
  end
  if (body == nil) then
    return POPSERVER_ERR_NETWORK
  end
 
  -- We should be logged in now!  Unfortunately, we aren't done.  Hotmail returns a page
  -- that should auto-reload in a browser but not in curl.  It's the URL for Hotmail Today.
  --
  url = string.match(body, globals.strLoginDoneReloadToHMHome1)
  if url == nil then
    url = string.match(body, globals.strLoginDoneReloadToHMHome2)
    if url == nil then
      log.error_print(globals.strLoginFailed .. " Sent login info to: " .. (url or "none") .. " and got something we weren't expecting(1):\n" .. body)
      return POPSERVER_ERR_NETWORK
    end
  end

  str = string.match(url, globals.strRetLoginBadLogin)
  if str ~= nil then
    log.error_print(globals.strLoginFailed .. " Sent login info to: " .. (url or "none") .. " and got something we weren't expecting(2):\n" .. body);
    return POPSERVER_ERR_NETWORK
  end
  body, err = getPage(browser, url, nil, "Hotmail Today")

  -- Shouldn't happen but you never know
  --
  if body == nil then
    log.error_print(globals.strLoginFailed)
    return POPSERVER_ERR_NETWORK
  end

   -- Check to see if we are using a classic account
   --
   local str = string.match(body, globals.strClassicCheckPattern)
   if str ~= nil then
     log.dbg("Hotmail: Detected Classic version.") 
     body, err = getPage(browser, "http://www.hotmail.com", nil, "hotmail homepage")
	 if (body == nil) then
	   return POPSERVER_ERR_NETWORK
	 end
   end 

  -- Let's have a look for a message at login
  --
  local hasMsgAtLogin = false
  url, body, err, hasMsgAtLogin = CheckForMessageAtLogin(browser, url, body)

  -- Check to see if we are using the new interface and are redirecting.
  --
  local folderBody = body
  if string.match(body, globals.strLiveCheckPattern) or string.match(body, globals.strLiveCheckPattern2) then
    log.dbg("Hotmail: Detected LIVE version.") 
    str = string.format(globals.strCmdBrowserIgnoreLive, browser:wherearewe())
    body, err = getPage(browser, str, nil, "browser check")
	if (body == nil) then
	  return POPSERVER_ERR_NETWORK
	end
    local strTemp = string.match(body, '<iframe.* src="([^"]+)"')
    if strTemp ~= nil then
      str = cleanupLoginBody(strTemp)
      body, err = getPage(browser, str, nil, "Main Page?")
  	  if (body == nil) then
	    return POPSERVER_ERR_NETWORK
	  end
    end	

    -- Let's have another look for a message at login
    --
    if (hasMsgAtLogin ~= true) then
      url, body, err, hasMsgAtLogin = CheckForMessageAtLogin(browser, url, body)
    end

    str = string.match(body, globals.strLiveMainPagePattern)
    if str ~= nil then
      str = string.format(globals.strCmdBaseLive, browser:wherearewe()) .. str
      body, err = getPage(browser, str, nil, "Main Page?")
      if (body == nil) then
	    return POPSERVER_ERR_NETWORK
	  end

    else
      str = string.match(body, globals.strLiveLightPagePattern)
      if (str ~= nil) then
        log.dbg("Hotmail: Detected LIVE version is in LIGHT mode.")
        internalState.bLiveLightGUI = true
      else
        log.error_print(globals.strLoginFailed .. " Trying to get session id and got something we weren't expecting:\n" .. body);
        return POPSERVER_ERR_NETWORK
      end
    end

    internalState.bLiveGUI = true
  else
    -- One or two more redirects
    --  
    local oldurl = url
    local oldbody = body
    url = string.match(body, globals.strLoginDoneReloadToReloadPage)
    if url ~= nil then
      body, err = getPage(browser, url, nil, "Non-Live Login Success and Redirect")
      if body == nil then
       	-- cdmackie: switch back to old body because we need to first process img in strLoginDoneReloadToHMHome4
       	body = oldbody
      end
    end

    -- Paco
    body = cleanupLoginBody(body)
    
	url = string.match(body, globals.strLoginDoneReloadToHMHome1)
    if url == nil then
      url = string.match(body, globals.strLoginDoneReloadToHMHome2)
      if url == nil then
        -- Change suggested by 930     
        local authimgurl = string.match(body, globals.strLoginDoneReloadToHMHome4)
    
     	-- Paco
        --
        if authimgurl == nil then
          authimgurl = string.match(body, globals.strLoginDoneReloadToHMHome5)
        end
        log.dbg("Image url: " .. authimgurl)

        if authimgurl ~= nil then
          getPage(browser, authimgurl, nil, "Authentication Image Url - NonLive")
  	  	  if (body == nil) then
	        return POPSERVER_ERR_NETWORK
	      end
        end
        url = string.match(body, globals.strLoginDoneReloadToHMHome3)
        if url == nil then
          log.error_print(globals.strLoginFailed .. " Sent login info to: " .. (oldurl or "none") .. " and got something we weren't expecting(3):\n" .. body);
          return POPSERVER_ERR_NETWORK
        end  
        -- End change
      end
    end
    body, err = getPage(browser, url, nil, "NonLive - Login Redirect")

    -- Paco
    if body == nil then
      log.error_print(globals.strLoginFailed .. " Sent login info to: " .. (url or "none") .. " and got an error:\n" .. err);
      return POPSERVER_ERR_NETWORK
	end
  end

  -- Extract the crumb - This is needed for deletion of items
  --
  if (internalState.bLiveLightGUI ~= true) then
    local user = nil
    if (internalState.bLiveGUI == true) then
      str = string.match(body, globals.strRegExpCrumbLive)
      user = string.match(body, globals.strRegExpUser)
    else
      str = string.match(body, globals.strRegExpCrumb)
    end

    if str == nil then
      log.error_print("Can't get the 'a' value. This will lead to problems!")
      internalState.strCrumb = ""
    else
      internalState.strCrumb = str
  
      -- Debug Message
      -- 
      log.dbg("Hotmail Crumb value: " .. str .. "\n")
    end

    if user == nil then
      log.error_print("Can't get the 'authuser' value. This will lead to problems!")
      internalState.strUserId = ""
    else
      internalState.strUserId = user
  
      -- Debug Message
      -- 
      log.dbg("Hotmail Authuser value: " .. user .. "\n")
    end
  else
    -- Force this to be the empty string for live light -- older versions.  Eventually we could probably remove this.
	--
    internalState.strCrumb = ''
  end

  -- Get the MT cookie value
  --
  local cookie = browser:get_cookie('mt')
  if (cookie ~= nil) then
    internalState.strMT = cookie.value
    log.dbg("Hotmail mt value: " .. cookie.value)
  end

  -- Save the mail server
  --
  internalState.strMailServer = browser:wherearewe()

  -- DEBUG Message
  --
  log.dbg("Hotmail Server: " .. internalState.strMailServer .. "\n")

  -- Find the image server
  --
  str = string.match(body, globals.strImgServerLivePattern)
  if (str == nil) then
    str = string.match(body, globals.strImgServerPattern)
  end
  
  if str ~= nil then
    internalState.strImgServer = str
    log.dbg("Hotmail image server: " .. str)
  else
    internalState.strImgServer = internalState.strMailServer
    log.dbg("Couldn't figure out the image server.  Using the mail server as a default.")
  end

  -- Note the time when we logged in
  --
  internalState.loginTime = os.clock();

  -- If we haven't set the folder yet, then it is a custom one and we need to grab it
  --
  internalState.strMBoxName = string.gsub(internalState.strMBoxName, '%-', "%%-")
  if (internalState.strMBox == nil and internalState.bLiveGUI == false) then
    local url = string.format(globals.strCmdFolders, internalState.strMailServer, 
      internalState.strCrumb)
    body, err = getPage(browser, url, nil, "Manage Folders Page")
	if (body == nil) then
	  return POPSERVER_ERR_NETWORK
	end

    str = string.match(body, globals.strFolderPattern .. internalState.strMBoxName .. "</a>")
    if (str == nil and domain == "msn.com" and internalState.strMBoxName == "Inbox") then
      str = string.match(body, globals.strPatMSNInboxId)
    end
    if (str == nil) then
      log.error_print("Unable to figure out folder id with name: " .. internalState.strMBoxName)
      return POPSERVER_ERR_NETWORK
    else
      internalState.strMBox = str
      log.dbg("Hotmail - Using folder (" .. internalState.strMBox .. ")")
    end
  elseif (internalState.bLiveGUI == true and internalState.bLiveLightGUI == false) then 
    -- Get some folder id's
    --
    local inboxId = string.match(body, globals.strFolderLiveInboxPattern)

    -- Get the trash folder id and the junk folder id
    --
    str = string.match(body, globals.strPatLiveTrashId) 
    if str ~= nil then
      internalState.strTrashId = str
      log.dbg("Hotmail - trash folder id: " .. str)
    else
        log.error_print("Unable to detect the folder id for the trash folder.  Deletion may fail.")
      end

    str = string.match(body, globals.strPatLiveJunkId) 
    if str ~= nil then
      internalState.strJunkId = str
      log.dbg("Hotmail - junk folder id: " .. str)
    else
        log.error_print("Unable to detect the folder id for the junk folder.  Deletion may fail.")
      end

    if (internalState.strMBoxName == "Inbox") then
      str = inboxId
    elseif (internalState.strMBoxName == "Junk" or internalState.strMBoxName == "Junk E%-Mail") then
      str = internalState.strJunkId
    else
      str = getFolderId(inboxId)
    end

    if (str == nil) then
      log.error_print("Unable to figure out folder id with name: " .. internalState.strMBoxName)
      return POPSERVER_ERR_NETWORK
    else
      internalState.strMBox = str
      log.dbg("Hotmail - Using folder (" .. internalState.strMBox .. ")")
    end
  elseif (internalState.bLiveGUI == true and internalState.bLiveLightGUI == true) then 
    -- cdmackie: Live Light has an "n" value in the folders list that we need to get
    local n = string.match(body, globals.strFolderLiveLightManageFoldersPattern)
    local url = string.format(globals.strCmdFoldersLiveLight, internalState.strMailServer, n)    
    
    body, err = getPage(browser, url, nil, "LiveLight - Manage Folders")
	if (body == nil) then
	  return POPSERVER_ERR_NETWORK
	end
    
    -- cdmackie 2008-07-06: fix patter to get folder IDs
	if (internalState.strMBox == nil) then
      if (internalState.strMBoxName == "Inbox") then
        str = string.match(body, globals.strFolderLiveLightInboxPattern)
        local id = string.match(str, globals.strFolderLiveLightFolderIdPattern)
        local n = string.match(str, globals.strFolderLiveLightNPattern)
        str = id .. "&n=" .. n
      else
        str = string.match(body, globals.strFolderLiveLightPattern .. internalState.strMBoxName)
        local id = string.match(str, globals.strFolderLiveLightFolderIdPattern)
        local n = string.match(str, globals.strFolderLiveLightNPattern)
        str = id .. "&n=" .. n
      end

      if (str == nil) then
        log.error_print("Unable to figure out folder id with name: " .. internalState.strMBoxName)
        return POPSERVER_ERR_NETWORK
	  end
      internalState.strMBox = str
	else
	    local folder = string.gsub(internalState.strMBox, '%-', "%%-")
        local n = string.match(body, folder .. globals.strFolderWithIdLiveLightNPattern)
		if (n == nil) then
          log.error_print("Unable to figure out the n value for folder id: " .. internalState.strMBox)
          return POPSERVER_ERR_NETWORK
		end
		internalState.strMBox = internalState.strMBox .. "&n=" .. n
	end
    log.dbg("Hotmail - Using folder (" .. internalState.strMBox .. ")")

    -- Get the trash folder id and the junk folder id
    --
	local idx = 0
	for folderId in string.gfind(body, "javascript:confirmDeleteFolder%('([^']+)'") do
	  if idx == 0 then
        internalState.strJunkId = folderId
        log.dbg("Hotmail - junk folder id: " .. folderId)
	  elseif idx == 1 then
        internalState.strTrashId = folderId
        log.dbg("Hotmail - trash folder id: " .. folderId)
      end
	  idx = idx + 1
	end

    if (internalState.strTrashId == nil) then	
      str = string.match(body, globals.strFolderLiveLightTrashPattern) 
      if str ~= nil then
        internalState.strTrashId = str
        log.dbg("Hotmail - trash folder id: " .. str)
      else
        str = string.match(body, globals.strFolderLiveLightTrash2Pattern) 
        if str ~= nil then
          internalState.strTrashId = str
          log.dbg("Hotmail - trash folder id: " .. str)
        else
          log.error_print("Unable to detect the folder id for the trash folder.  Deletion may fail.")
        end
      end
	end

	if (internalState.strJunkId == nil) then
      str = string.match(body, globals.strFolderLiveLightJunkPattern) 
      if str ~= nil then
        internalState.strJunkId = str
        log.dbg("Hotmail - junk folder id: " .. str)
      else
        str = string.match(body, globals.strFolderLiveLightJunk2Pattern) 
        if str ~= nil then
          internalState.strJunkId = str
          log.dbg("Hotmail - junk folder id: " .. str)
        else
          log.error_print("Unable to detect the folder id for the junk folder.  Deletion may fail.")
        end
      end
	end
  end

  -- Note that we have logged in successfully
  --
  internalState.bLoginDone = true
    
  -- Debug info
  --
  log.dbg("Created session for " .. 
    internalState.strUser .. "@" .. internalState.strDomain .. "\n")

  -- Return Success
  --
  return POPSERVER_ERR_OK
end

function cleanupLoginBody(body)
  body = string.gsub(body, "&#58;", ":")
  body = string.gsub(body, "&#61;", "=")
  body = string.gsub(body, "&#39;", "'")
  body = string.gsub(body, "&#92;", "\\")
  body = string.gsub(body, "&#47;", "/")
  body = string.gsub(body, "&#63;", "?")
  body = string.gsub(body, "&#42;", "*")
  body = string.gsub(body, "&#33;", "!")
  body = string.gsub(body, "&#36;", "$")
  body = string.gsub(body, "\\x3a", ":")
  body = string.gsub(body, "\\x2f", "/")
  body = string.gsub(body, "\\x3f", "?")
  body = string.gsub(body, "\\x3d", "=")
  body = string.gsub(body, "\\x26", "&")
  body = string.gsub(body, "&#38;", "&")   -- maybe best to be last

  return body
end

function getFolderId(inboxId) 
  local cmdUrl = string.format(globals.strCmdMsgListLive, internalState.strMailServer,
    internalState.strCrumb, internalState.strUserId)
  local post = string.format(globals.strCmdMsgListPostLive, inboxId, 0, 0, internalState.strMT)
  local body, err = internalState.browser:post_uri(cmdUrl, post)
  local str = string.match(body, globals.strFolderLivePattern .. internalState.strMBoxName .. '","i_')
  return str
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
	
  -- Local Variables
  --
  local browser = internalState.browser
  local uidl = get_mailmessage_uidl(pstate, msg)
  local url = string.format(globals.strCmdMsgView, internalState.strMailServer,
    uidl, internalState.strMBox, internalState.strCrumb);
  local markReadUrl = url
  url = url .. globals.strCmdMsgViewRaw
  if (internalState.bLiveGUI == true) then
    url = string.format(globals.strCmdMsgViewLive, internalState.strMailServer, uidl)
  end

  -- Debug Message
  --
  log.dbg("Getting message: " .. uidl .. ", URL: " .. url)

  -- Define a structure to pass between the callback calls
  --
  local cbInfo = {
    -- Whether this is the first call of the callback
    --
    bFirstBlock = true,
    nAttempt = 0,
    bRetry = true,

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
    strBuffer = "",

    -- addition
    cb_uidl = uidl,     --  to provide the uidl for later... 
    bEndReached = false  	-- this is a hack, I know...
    -- end of addition
  }
	
  -- Define the callback
  --
  local cb = downloadMsg_cb(cbInfo, data)

  -- Start the download on the body
  -- 
  while (cbInfo.bRetry == true and cbInfo.nAttempt < 3) do
    local f, err = browser:pipe_uri(url, cb)
    if err and string.match(err, "transfer closed with outstanding read data remaining") == nil then
      -- Log the error
      --
      log.dbg("Message: " .. cbInfo.cb_uidl .. " received error: " .. err)
    end
  end
  if (cbInfo.bRetry == true) then
    log.error_print("Message: " .. cbInfo.cb_uidl .. " failed to download.")
    return POPSERVER_ERR_NETWORK
  end

  -- Handle whatever is left in the buffer
  --
  local body = cbInfo.strBuffer
  if (string.len(body) > 0 and cbInfo.nLinesRequested == -2) then
    --log.dbg("Message: " .. cbInfo.cb_uidl .. ", left over buffer being processed: " .. body)
    body = cleanupBody(body, cbInfo)
    
    -- cdmackie: rather than test for </pre> to determine end, just set it seen
    -- as we've reached end of buffer..and hotmail doesn't always send "</pre>"
    cbInfo.bEndReached = true
    cbInfo.nLinesReceived = -1;
    -- apply same fixup from cleanupbody to remove dead tags -- I have doubts that this ever does anything.
    if (string.len(body) > 6) then
      local idx = string.find(string.sub(body, -6), "([&<])")
      if (idx ~= nil) then
        idx = idx - 1
        cbInfo.strBuffer = string.sub(body, -6 + idx)
        local len = string.len(body) - 6 + idx
        body = string.sub(body, 1, len)
      end
    end
    -- make sure we end in a crlf
	body = string.gsub(body, "</\r\n", "\r\n") 
    if (string.sub(body, -2, -1) ~= "\r\n") then
      body = body .. "\r\n"
    end
    
    if (cbInfo.bEndReached == false) then
      log.dbg("Forcing a CRLF to end the message as it isn't clear the message is ended properly")
      popserver_callback("\r\n\0", data)
    end
    body = cbInfo.strHack:dothack(body) .. "\0"
    popserver_callback(body, data)
  elseif (cbInfo.bEndReached == false and cbInfo.nLinesRequested == -2) then
      popserver_callback("\r\n\0", data)
  elseif (cbInfo.nLinesRequested ~= -2) then
      popserver_callback("\r\n\0", data)
  end

  -- Mark the message as read
  --
  if (internalState.bKeepMsgStatus == true) then
    -- no op
  elseif internalState.bMarkMsgAsUnread == false and internalState.bLiveGUI == false then
    log.dbg("Message: " .. cbInfo.cb_uidl .. ", Marking message as being done.")
    browser:get_head(markReadUrl)
  elseif internalState.bMarkMsgAsUnread == false and internalState.bLiveGUI and internalState.bLiveLightGUI == false then
    log.dbg("Message: " .. cbInfo.cb_uidl .. ", Marking message as read.")
    url = string.format(globals.strCmdMsgReadLive, internalState.strMailServer, internalState.strUserId)
    local post = string.format(globals.strCmdMsgReadLivePost, uidl, internalState.strMT)
    browser:post_uri(url, post)
  elseif internalState.bMarkMsgAsUnread == false and internalState.bLiveGUI and internalState.bLiveLightGUI then
    log.dbg("Message: " .. cbInfo.cb_uidl .. ", Marking message as read.")
    -- cdmackie: 2008-07-05 use new MarkMessagesReadState command
    --url = string.format(globals.strCmdMsgReadLiveLight, internalState.strMailServer, internalState.strMBox, uidl)
    url = string.format(globals.strCmdMsgReadLiveLight, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
		local inboxid = string.gsub(internalState.strMBox, "&n=.*", "")
    local post = string.format(globals.strCmdMsgReadLiveLightPost, uidl, inboxid, internalState.strMT) -- needs madsLight before inboxid
		post = string.gsub(post, '"', "%%22") 
		log.dbg("****" .. post .. "****")
    browser:post_uri(url, post)
  elseif internalState.bMarkMsgAsUnread == true and internalState.bLiveGUI == true then
    log.dbg("Message: " .. cbInfo.cb_uidl .. ", Marking message as unread.")
    url = string.format(globals.strCmdMsgUnreadLive, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
    local post = string.format(globals.strCmdMsgUnreadLivePost, uidl)
    browser:post_uri(url, post)
  end

  --log.dbg("Message: " .. cbInfo.cb_uidl .. ", Completed!")
  return POPSERVER_ERR_OK
end

-- Callback for the retr function
--
function downloadMsg_cb(cbInfo, data)
	
  return function(body, len)

    -- Is this the first block?  If so, make sure we have a valid message
    --
    if (cbInfo.bFirstBlock == true) then
      if (string.find(body, "<pre>")) then
        cbInfo.bRetry = false
      else
        cbInfo.bRetry = true   
        cbInfo.nAttempt = cbInfo.nAttempt + 1
        return 0, nil
      end
    end 

    -- Are we done with Top and should just ignore the chunks
    --
    if (cbInfo.nLinesReceived == -1) then
      return 0, nil
    end

    -- Update the buffer
    --
    body = cbInfo.strBuffer .. body
    cbInfo.strBuffer = ""
    if (string.len(body) > 6) then
      local idx = string.find(string.sub(body, -6), "([&<])")
      if (idx ~= nil) then
        idx = idx - 1
        cbInfo.strBuffer = string.sub(body, -6 + idx)
        local len = string.len(body) - 6 + idx
        body = string.sub(body, 1, len)
      end
    end

    body = cleanupBody(body, cbInfo)

    -- Perform our "TOP" actions
    --
    if (cbInfo.nLinesRequested ~= -2) then
      body = cbInfo.strHack:tophack(body, cbInfo.nLinesRequested)

      -- Check to see if we are done and if so, update things
      --
      if cbInfo.strHack:check_stop(cbInfo.nLinesRequested) then
        cbInfo.nLinesReceived = -1;
        -- This is now handled in the parent function
        --
--        if (string.sub(body, -2, -1) ~= "\r\n") then
--          body = body .. "\r\n"
--        end
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

function cleanupHeaders(headers, cbInfo)
  -- Cleanup the headers.  They are HTML-escaped.  
  --
  local origHeaders = headers
  local bMissingTo = false    -- it seems hotmail server sometimes disregards To: when 'raw=0' ? 
                              --   probably only in internal HoTMaiL-service letters, where the actual 
                              --   internet message headers do not contain actual To:-field
  local bMissingID = false    -- when no Message-ID -field seems to have been automatically generated ?
  local bodyrest = ""

  headers, bodyrest = string.match(headers, "^(.-\r\n.-)\r\n(.*)$" )

  if (headers == nil) then
    log.dbg("Hotmail: unable to parse out message headers.  Extra headers will not be used.")
    return origHeaders
  end  

  --headers = string.gsub(headers, "%s+$", "\n")
  --headers = headers .. "\n";
  --headers = string.gsub(headers, "\n\n", "\n")
  --headers = string.gsub(headers, "\r\n", "\n")
  --headers = string.gsub(headers, "\n", "\r\n")

  --
  -- some checking...
  --
--  if string.find(headers, "(To:)") == nil then
--    bMissingTo = true
--  end
--  if string.find(headers, "(Message%-I[dD]:)") == nil then
--    bMissingID = true
--  end

  -- Add some headers
  --
  local newheaders = ""
  if bMissingTo ~= false then
    newheaders = newheaders .. "To: " .. internalState.strUser .. "@" .. internalState.strDomain .. "\r\n" ;
  end

  if bMissingID ~= false then
    local msgid = cbInfo.cb_uidl .. "@" .. internalState.strMailServer -- well, if we do not have any better choice...
    newheaders = newheaders .. "Message-ID: <" .. msgid .. ">\r\n"  
  end
  
  local readStatus = "read"
  if (internalState.unreadStatus[cbInfo.cb_uidl]) then
    readStatus = "unread"
  end

  newheaders = newheaders .. "X-FreePOPs-User: " .. internalState.strUser .. "@" .. internalState.strDomain .. "\r\n"
  newheaders = newheaders .. "X-FreePOPs-Domain: " .. internalState.strDomain .. "\r\n"
  newheaders = newheaders .. "X-FreePOPs-Folder: " .. internalState.strMBox .. "\r\n"
  newheaders = newheaders .. "X-FreePOPs-MailServer: " .. internalState.strMailServer .. "\r\n"
  newheaders = newheaders .. "X-FreePOPs-ImageServer: " .. internalState.strImgServer .. "\r\n"
  newheaders = newheaders .. "X-FreePOPs-MsgNumber: " .. "<" .. cbInfo.cb_uidl .. ">" .. "\r\n"
  newheaders = newheaders .. "X-FREEPOPS-READ-STATUS: " .. readStatus .. "\r\n"

  -- make the final touch...
  --
  headers = headers .. "\r\n" .. newheaders .. bodyrest

  return headers 
end

function cleanupBody(body, cbInfo)
  -- check to see whether the end of message has already been seen...
  --
  if (cbInfo.bEndReached == true) then
    return ("") ; 	-- in this case we pass nothing past the end of message
  end

  -- Did we reach the end of the message
  --
  -- cdmackie: test for the end after we've processed the buffers instead
  -- GetMessageSource sometimes returns only "</" instead of "</pre>"
  --if (string.find(body, "(</pre>)") ~= nil) then
  --  cbInfo.nLinesReceived = -1;
  --  cbInfo.bEndReached = true 
  --end

  -- The only parts we care about are within <pre>..</pre>
  --
  body = string.gsub(body, "<pre>[%s]*", "")
  body = string.gsub(body, "</pre>.-$", "\n")
  -- cdmackie: sometimes we get only "</"
  body = string.gsub(body, "</$", "\n")

  -- Clean up the end of line, and replace HTML tags
  --
  body = string.gsub(body, "&#13;&#10; &#13;&#10;", "\n") -- appears in some spam messages and destroys the headers
  body = string.gsub(body, "&#9;", "\t")
  body = string.gsub(body, "&#09;", "\t")
  body = string.gsub(body, "&#10;", "\n")
  body = string.gsub(body, "&#13;", "")
  body = string.gsub(body, "&#27;", "\27")
  body = string.gsub(body, "&#32;", " ")
  body = string.gsub(body, "&#33;", "!")
  body = string.gsub(body, "&#35;", "#")
  body = string.gsub(body, "&#36;", "$")
  -- cdmackie: this should be escaped
  body = string.gsub(body, "&#37;", "%%")
  body = string.gsub(body, "&#38;", "&")
  body = string.gsub(body, "&#39;", "'")
  body = string.gsub(body, "&#40;", "(")
  body = string.gsub(body, "&#41;", ")")
  body = string.gsub(body, "&#42;", "*")
  body = string.gsub(body, "&#43;", "+")
  body = string.gsub(body, "&#44;", ",")
  body = string.gsub(body, "&#45;", "-")
  body = string.gsub(body, "&#46;", ".")
  body = string.gsub(body, "&#47;", "/")
  body = string.gsub(body, "&#58;", ":")
  body = string.gsub(body, "&#59;", ";")
  body = string.gsub(body, "&#60;", "<")

  -- cdmackie: these mess up QP and b64 encoded attachments
  --body = string.gsub(body, "&#61;2E", ".")
  --body = string.gsub(body, "&#61;3D", "=")
  --body = string.gsub(body, "&#61;20", " ")
  --body = string.gsub(body, "&#61;09", "\t")
  --body = string.gsub(body, "&#61;96", "-")
  --body = string.gsub(body, "&#61;\r\n", "")
  --body = string.gsub(body, "&#61;92", "'")

  body = string.gsub(body, "&#61;", "=")
  body = string.gsub(body, "&#62;", ">")
  body = string.gsub(body, "&#63;", "?")
  body = string.gsub(body, "&#64;", "@")
  body = string.gsub(body, "&#91;", "[")
  body = string.gsub(body, "&#92;", "\\")
  body = string.gsub(body, "&#93;", "]")
  body = string.gsub(body, "&#94;", "^")
  body = string.gsub(body, "&#95;", "_")
  body = string.gsub(body, "&#96;", "`")
  body = string.gsub(body, "&#123;", "{")
  body = string.gsub(body, "&#124;", "|")
  body = string.gsub(body, "&#125;", "}")
  body = string.gsub(body, "&#126;", "~")
  body = string.gsub(body, "&#199;", "Ç")

  body = string.gsub(body, "\r", "")
  body = string.gsub(body, "\n", "\r\n")
  body = string.gsub(body, "&#34;", "\"")
  -- cdmackie: these mess up QP attachments in Live
  -- but still needed for classic
  if internalState.bLiveGUI == false then
  	body = string.gsub(body, "&amp;", "&")
  	body = string.gsub(body, "&lt;", "<")
  	body = string.gsub(body, "&gt;", ">")
  	body = string.gsub(body, "&quot;", "\"")
  	body = string.gsub(body, "&nbsp;", " ")
  end
  body = string.gsub(body, "<!%-%-%$%$imageserver%-%->", internalState.strImgServer)

  -- cdmackie: POP protocol: lines starting with a dot must be escaped dotdot
  body = string.gsub(body, "\r\n%.", "\r\n%.%.")
  
  -- Experimental -- For non-ascii users
  body = string.gsub(body, "&#(%d*);",
      function(c)
          c = tonumber(c)
          if (c > 255) then
              return "&#" .. c .. ";"
          else
              return string.char(c)
          end
      end
  )
  
  -- We've now at least seen one block, attempt to clean up the headers
  --
  if (cbInfo.bFirstBlock == true) then
    cbInfo.bFirstBlock = false 
    body = cleanupHeaders(body, cbInfo)
  end

  return body
end

-- ************************************************************************** --
--  Pop3 functions that must be defined
-- ************************************************************************** --

-- Extract the user, domain and mailbox from the username
--
function user(pstate, username)
  -- Get the user, domain, and mailbox
  -- TODO:  mailbox - for now, just inbox
  --
  local domain = freepops.get_domain(username)
  local user = freepops.get_name(username)

  internalState.strDomain = domain
  internalState.strUser = user

  -- Override the domain variable if it is set in the login parameter
  --
  local val = (freepops.MODULE_ARGS or {}).domain or nil
  if val ~= nil then
    log.dbg("Hotmail: Using overridden domain: " .. val)
    internalState.strDomain = val
  end

  -- If the flag emptyTrash is set to 1 ,
  -- the trash will be emptied on 'quit'
  --
  local val = (freepops.MODULE_ARGS or {}).emptytrash or 0
  if val == "1" then
    log.dbg("Hotmail: Trash folder will be emptied on exit.")
    internalState.bEmptyTrash = true
  end

  -- If the flag emptyjunk is set to 1 ,
  -- the trash will be emptied on 'quit'
  --
  local val = (freepops.MODULE_ARGS or {}).emptyjunk or 0
  if val == "1" then
    log.dbg("Hotmail: Junk folder will be emptied on exit.")
    internalState.bEmptyJunk = true
  end

  -- If the flag markunread=1 is set, then we will mark all messages
  -- that we pull as unread when done.
  --
  local val = (freepops.MODULE_ARGS or {}).markunread or 0
  if val == "1" then
    log.dbg("Hotmail: All messages pulled will be marked unread.")
    internalState.bMarkMsgAsUnread = true
  end

  -- If the flag maxmsgs is set,
  -- STAT will limit the number of messages to the flag
  --
  val = (freepops.MODULE_ARGS or {}).maxmsgs or 0
  if tonumber(val) > 0 then
    log.dbg("Hotmail: A max of " .. val .. " messages will be downloaded.")
    internalState.statLimit = tonumber(val)
  end

  -- If the flag keepmsgstatus=1 is set, then we won't touch the status of 
  -- messages that we pull.
  --
  local val = (freepops.MODULE_ARGS or {}).keepmsgstatus or 0
  if val == "1" then
    log.dbg("Hotmail: All messages pulled will have its status left alone.")
    internalState.bKeepMsgStatus = true
  end



  -- Get the folder
  --
  local mbox = (freepops.MODULE_ARGS or {}).folder
  if mbox == nil then
    internalState.strMBoxName = "Inbox"
  else
    mbox = curl.unescape(mbox)
    internalState.strMBoxName = mbox
    log.dbg("Using Custom mailbox set to: " .. internalState.strMBoxName .. ".\n")
  end

  local mboxid = (freepops.MODULE_ARGS or {}).folderid or nil
  if mboxid ~= nil then
    internalState.strMBox = mboxid
    log.dbg("Using Custom mailbox id set to: " .. internalState.strMBoxName .. ".\n")
  end

  return POPSERVER_ERR_OK
end

-- Perform login functionality
--
function pass(pstate, password)
  -- Store the password
  --
  -- truncate password if longer than nMaxPasswordLen characters to mimic broken web page behavior
  if string.len(password) > globals.nMaxPasswordLen then
    password = string.sub(password, 0, globals.nMaxPasswordLen)
  end
  
  internalState.strPassword = password

  -- Get a session
  --
  local sessID = session.load_lock(hash())

  -- See if we already have a session.  We want to prevent
  -- multiple sessions for a given account
  --
  if sessID ~= nil then
    -- Session exists
    -- This code is copied from example.  It doesn't make sense to me.
    --
  
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
      return loginHotmail()
    end
		
    log.dbg("Session loaded - Account: " .. internalState.strUser .. 
      "@" .. internalState.strDomain .. "\n")

    -- Execute the function saved in the session
    --
    func()

    -- Should we force a logout.  If this session runs for more than a day, things
    -- stop working
    --
    local currTime = os.clock()
    local diff = currTime - internalState.loginTime
    if diff > globals.nSessionTimeout then 
      logout() 
      log.dbg("Logout forced to keep hotmail session fresh and tasty!  Yum!\n")
      log.dbg("Session removed - Account: " .. internalState.strUser .. 
        "@" .. internalState.strDomain .. "\n")
      session.remove(hash())
      return loginHotmail()
    end
		
    return POPSERVER_ERR_OK
  else
    -- Create a new session by logging in
    --
    return loginHotmail()
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
  -- Make sure we aren't jumping the gun
  --
  local retCode = stat(pstate)
  if retCode ~= POPSERVER_ERR_OK then 
    return retCode 
  end

  -- Local Variables
  --
  local browser = internalState.browser
  local cmdUrl = string.format(globals.strCmdDelete, internalState.strMailServer)
  local cnt = get_popstate_nummesg(pstate)
  local dcnt = 0
  local postBase = string.format(globals.strCmdDeletePost, internalState.strMBox)
  local post = postBase
  local uidls = ""
  local uidlsLight = ""
  local madsLight = ""

  -- Cycle through the messages and see if we need to delete any of them
  -- 
  for i = 1, cnt do
    if internalState.bLiveGUI == false and get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      dcnt = dcnt + 1
      post = post .. "&" .. get_mailmessage_uidl(pstate, i) .. "=on"

      -- Send out in a batch of 5
      --
      if math.fmod(dcnt, 5) == 0 then
        log.dbg("Sending Delete URL: " .. cmdUrl .. "Post Data: " .. post .. "\n")
        local body, err = getPage(browser, cmdUrl, post, "Delete Messages - NonLive")
        if not body or err then
          log.error_print("Unable to delete messages.\n")
        end
       
        -- Reset the variables
        --
        dcnt = 0
        post = postBase
      end
    elseif internalState.bLiveGUI == true and internalState.bLiveLightGUI and get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      -- cdmackie: 2008-07-09 string contains UIDLS and "mad" attribute from inbox
      local uidl, mad = string.match(internalState.msgIds[i], "(.-)&(.*)")
      if i > 1 then
        uidlsLight = uidlsLight .. ',"' .. uidl .. '"'
        -- doglan @ 2009-10-10: ",null" no longer needed before "}"
        madsLight = madsLight .. ',{"' .. mad .. '"}'
      else
        uidlsLight = '"' .. uidl .. '"'
        -- doglan @ 2009-10-10: ",null" no longer needed before "}"
        madsLight = '{"' .. mad .. '"}' -- ,null
      end
      dcnt = dcnt + 1
    elseif internalState.bLiveGUI == true and get_mailmessage_flag(pstate, i, MAILMESSAGE_DELETE) then
      if i > 1 then
        uidls = uidls .. "," .. get_mailmessage_uidl(pstate, i)
      else
        uidls = get_mailmessage_uidl(pstate, i)
      end
      dcnt = dcnt + 1
    end
  end

  -- Send whatever is left over
  --
  if dcnt > 0 and internalState.bLiveGUI == false then
    log.dbg("Sending Delete URL: " .. cmdUrl .. "Post Data: " .. post .. "\n")
    local body, err = browser:post_uri(cmdUrl, post)
    if not body or err then
      log.error_print("Unable to delete messages.\n")
    end
  elseif dcnt > 0 and internalState.bLiveGUI and internalState.bLiveLightGUI == true then
    cmdUrl = string.format(globals.strCmdDeleteLiveLight, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
    local inboxid = string.gsub(internalState.strMBox, "&n=.*", "")

	-- This is less than ideal and will need to be fixed soon.  This is the newer way to delete.
	--
	madsLight = string.gsub(madsLight, "|", "%%5C%%7C") 
    post = string.format(globals.strCmdDeletePostLiveLight2,
   	inboxid, internalState.strTrashId,
   	uidlsLight, madsLight,
    inboxid, internalState.strMT)
    post = string.gsub(post, '"', "%%22")      
    local body, err = getPage(browser, cmdUrl, post, "Delete Messages - LiveLight - Newer version")
	
  elseif dcnt > 0 and internalState.bLiveGUI then
    cmdUrl = string.format(globals.strCmdDeleteLive, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
    uidls = string.gsub(uidls, ",", '","')
    uidls = '"' .. uidls .. '"'
    post = string.format(globals.strCmdDeletePostLive, internalState.strMBox, 
      internalState.strTrashId, uidls, internalState.strMT)
--    log.dbg("Sending Trash url: " .. cmdUrl .. " - " .. post)
    local body, err = getPage(browser, cmdUrl, post, "Delete Messages - Live")
    if (body == nil) then -- M7 Only - DELETE SOON!
      post = string.format(globals.strCmdDeletePostLiveOld, internalState.strMBox, 
        internalState.strTrashId, uidls)
      local body, err = getPage(browser, cmdUrl, post, "Delete Messages - Live")
    end
  end

  -- Empty the trash
  --
  if internalState.bEmptyTrash and internalState.bLiveGUI == false then
    if internalState.strCrumb ~= '' then
      cmdUrl = string.format(globals.strCmdEmptyTrash, internalState.strMailServer,internalState.strCrumb)
      log.dbg("Sending Empty Trash URL: " .. cmdUrl .."\n")
      local body, err = getPage(browser, cmdUrl, nil, "NonLive - Empty Trash")
      if not body or err then
        log.error_print("Error when trying to empty the trash with url: ".. cmdUrl .. "\n")
      end
    else
      log.error_print("Cannot empty trash - crumb not found\n")
    end
  elseif internalState.bEmptyTrash and internalState.bLiveGUI and internalState.bLiveLightGUI == true then
    cmdUrl = string.format(globals.strCmdEmptyTrashLiveLight, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
    local inboxid = string.gsub(internalState.strMBox, "&n=.*", "")
    local post = string.format(globals.strCmdEmptyTrashLiveLightPost,internalState.strTrashId, inboxid, internalState.strMT)
    post = string.gsub(post, '"', "%%22")      
    log.dbg("Sending Empty Trash URL: " .. cmdUrl ..", POST: " .. post .. "\n")
    local body, err = getPage(browser, cmdUrl, post, "LiveLight - Empty Trash")
    if not body or err then
      log.error_print("Error when trying to empty the trash with url: ".. cmdUrl .."\n")
    end
  elseif internalState.bEmptyTrash and internalState.bLiveGUI then
    cmdUrl = string.format(globals.strCmdEmptyTrashLive, internalState.strMailServer, internalState.strUserId)
    local post = string.format(globals.strCmdEmptyTrashLivePost, internalState.strTrashId, internalState.strMT)
    log.dbg("Sending Empty Trash URL: " .. cmdUrl .."\n")
    local body, err = getPage(browser, cmdUrl, post, "Live - Empty Trash")
    if not body or err then
      log.error_print("Error when trying to empty the trash with url: ".. cmdUrl .."\n")
    end
  end

  -- Empty the Junk Folder
  -- 
  if internalState.bEmptyJunk and internalState.bLiveGUI and internalState.bLiveLightGUI == true then
    cmdUrl = string.format(globals.strCmdEmptyTrashLiveLight, internalState.strMailServer, internalState.strCrumb, internalState.strUserId)
    local inboxid = string.gsub(internalState.strMBox, "&n=.*", "")
    local post = string.format(globals.strCmdEmptyTrashLiveLightPost,internalState.strJunkId, inboxid, internalState.strMT)
    post = string.gsub(post, '"', "%%22")      
    log.dbg("Sending Empty Junk URL: " .. cmdUrl ..", POST: " .. post .. "\n")
    local body, err = getPage(browser, cmdUrl, post, "LiveLight - Empty Junk")
    if not body or err then
      log.error_print("Error when trying to empty the junk folder with url: ".. cmdUrl .."\n")
    end
  elseif internalState.bEmptyJunk and internalState.bLiveGUI then
    cmdUrl = string.format(globals.strCmdEmptyTrashLive, internalState.strMailServer, internalState.strUserId)
    local post = string.format(globals.strCmdEmptyTrashLivePost, internalState.strJunkId)
    log.dbg("Sending Empty Junk URL: " .. cmdUrl .."\n")
    local body, err = getPage(browser, cmdUrl, post, "Live - Empty Junk")
    if not body or err then
      log.error_print("Error when trying to empty the junk folder with url: ".. cmdUrl .."\n")
    end
  end

  -- Should we force a logout.  If this session runs for more than a day, things
  -- stop working
  --
  local currTime = os.clock()
  local diff = currTime - internalState.loginTime
  if diff > globals.nSessionTimeout then 
    logout() 
    log.dbg("Logout forced to keep hotmail session fresh and tasty!  Yum!\n")
    log.dbg("Session removed - Account: " .. internalState.strUser .. 
      "@" .. internalState.strDomain .. "\n")
    session.remove(hash())
    return POPSERVER_ERR_OK
  end

  -- Save and then Free up the session
  --
  session.save(hash(), serialize_state(), session.OVERWRITE)
  session.unlock(hash())

  log.dbg("Session saved - Account: " .. internalState.strUser .. 
    "@" .. internalState.strDomain .. "\n")

  return POPSERVER_ERR_OK
end

function logout() 
  local browser = internalState.browser
  local cmdUrl
  if (internalState.bLiveGUI) then
    cmdUrl = string.format(globals.strCmdLogoutLive, internalState.strMailServer)
  else
    cmdUrl = string.format(globals.strCmdLogout, internalState.strMailServer)
  end
  log.dbg("Sending Logout URL: " .. cmdUrl .. "\n")
  local body, err = getPage(browser, cmdUrl, nil, "Logout Page")
  if (internalState.bLiveGUI) then
    cmdUrl = string.match(body, '<meta http-equiv="refresh" content="%d+;url=([^"]+)" />')
    if (cmdUrl ~= nil) then
      body, err = getPage(browser, cmdUrl, nil, "Redirected Logout Page")
    end
  end
end

-- Stat command for the live gui
--
function LiveStat(pstate) 
  -- Local variables
  -- 
  local browser = internalState.browser
  local nMsgs = 0
  local nTotMsgs = 0;
  local nMaxMsgs = 999 
  if internalState.statLimit ~= nil then
    nMaxMsgs = internalState.statLimit
  end  

  local cmdUrl = string.format(globals.strCmdMsgListLive, internalState.strMailServer,
    internalState.strCrumb, internalState.strUserId)
  local post = string.format(globals.strCmdMsgListPostLive, internalState.strMBox, nMaxMsgs, nMaxMsgs, internalState.strMT)

  -- Debug Message
  --
  log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Iterate over the messages
  --
  local body, err = browser:post_uri(cmdUrl, post)
  if (body == nil) then
    -- Use the M7 way -- REMOVE THIS AT SOME POINT!
    --
    post = string.format(globals.strCmdMsgListPostLiveOld, internalState.strMBox, nMaxMsgs, nMaxMsgs)
    body, err = browser:post_uri(cmdUrl, post)
  end

  -- Let's make sure the session is still valid
  --
  local sessionExpired = (body == nil) or string.match(body, globals.strRetLoginSessionExpiredLive) == nil
  if sessionExpired then
    -- Invalidate the session
    --
    internalState.bLoginDone = nil
    session.remove(hash())
    local strLog = "Session Expired - Last page loaded: " .. cmdUrl .. ", Body"
    if (body == nil) then
      strLog = strLog .. " was 'nil'"
    else
      strLog = strLog .. ": " .. body
    end

    -- Try Logging back in
    --
    logout() 
    local status = loginHotmail()
    if status ~= POPSERVER_ERR_OK then
      return POPSERVER_ERR_NETWORK
    end
	
    -- Reset the local variables		
    --
    browser = internalState.browser

    -- Retry to load the page
    --
    body, err = browser:post_uri(cmdUrl, post)
  end

  -- Go through the list of messages (M7 - DELETE SOON!)
  --
  for uidl, size in string.gfind(body, globals.strMsgLivePatternOld) do
    nMsgs = nMsgs + 1
    if (nMsgs <= nMaxMsgs) then  
	  processMessage(uidl, sizes[i], nMsgs, pstate)
    end
  end

  -- Go through the list of messages (M8)
  --
  local cnt = 0
  local i = 1
  local sizes = {}
  for size in string.gfind(body, globals.strMsgLivePattern1) do
    cnt = cnt + 1
    local kbUnit = string.match(size, "([Kk])")
    size = string.match(size, "([%d%.,]+) [KkMm]")
    if (size ~= nil) then
      size = string.gsub(size, ",", ".")
    end
    if size ~= nil and tonumber(size) ~= nil then
      if not kbUnit then 
        size = math.max(tonumber(size), 0) * 1024 * 1024
      else
        size = math.max(tonumber(size), 0) * 1024
      end
    else
      size = 1024
    end
    sizes[cnt] = size
  end

  for uidl in string.gfind(body, globals.strMsgLivePattern2) do
    nMsgs = nMsgs + 1
    if (nMsgs <= nMaxMsgs) then
	  processMessage(uidl, sizes[i], nMsgs, pstate)
      i = i + 1
    end
  end

  -- Update our state
  --
  internalState.bStatDone = true

  -- Function completed successfully
  --
  return POPSERVER_ERR_OK
end

-- Stat command - Get the number of messages and their size
--
function stat(pstate)

  -- Have we done this already?  If so, we've saved the results
  --
  if internalState.bStatDone then
    return POPSERVER_ERR_OK
  end

  if internalState.bLiveGUI and internalState.bLiveLightGUI == false then
    return LiveStat(pstate)
  end

  -- Local variables
  -- 
  local browser = internalState.browser
  local nPage = 1
  local nMsgs = 0
  local nTotMsgs = 0
  local lastNMsgs = 0
  local cmdUrl = ""
  local cmdUrlPost = nil
  if (internalState.bLiveLightGUI) then    
    cmdUrl = string.format(globals.strCmdMsgListLiveLight, internalState.strMailServer, 
      internalState.strMBox);
  else
    cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
      internalState.strCrumb, internalState.strMBox);
  end
  local baseUrl = cmdUrl
  local nextPageUrl = nil
  local nextPageUrlPost = nil
  local bIgnoreFinalTest = false

  -- Keep a list of IDs that we've seen.  With yahoo, their message list can 
  -- show messages that we've already seen.  This, although a bit hacky, will
  -- keep the unique ones.  We'll need to search the table on every message which
  -- really sucks!
  --
  local knownIDs = {}
  
  -- keep msgIds for Hotmail to include the n value
  internalState.msgIds = {}

  -- Debug Message
  --
  log.dbg("Stat URL: " .. cmdUrl .. "\n");
		
  -- Initialize our state
  --
  set_popstate_nummesg(pstate, nMsgs)

  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcess(body)
    lastNMsgs = nMsgs

    -- Find out if there are any messages
    -- 
    local nomesg = string.match(body, globals.strMsgListNoMsgPat)
    if (nomesg ~= nil) then
      return true, nil
    end

    -- Tokenize out the message ID and size for each item in the list
    --    
    local items = mlex.match(body, globals.strMsgLineLitPattern, globals.strMsgLineAbsPattern)
    log.dbg("Stat Count: " .. items:count())

    -- Remember the count
    --
    local cnt = items:count()
    if cnt == 0 then
      return true, nil
    end 
		
    -- Cycle through the items and store the msg id and size
    --
    for i = 1, cnt do
      local uidl = items:get(0, i - 1) 
      local size = items:get(1, i - 1)

      if not uidl or not size then
        log.say("Hotmail Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      -- Get the message id..
      --
      uidl = string.match(uidl, 'name="([^"]+)"')

      local bUnique = true
      for j = 0, nMsgs do
        if knownIDs[j + 1] == uidl then
          bUnique = false
          break
        end        
      end
	  size = parseSize(size)

      -- Save the information
      --
      if bUnique == true and ((nMsgs < nTotMsgs and nTotMsgs ~= 0) or nTotMsgs == 0) then
        nMsgs = nMsgs + 1
		processMessage(uidl, size, nMsgs, pstate)
        knownIDs[nMsgs] = uidl
      end
    end

    -- We are done with this page, increment the counter
    --
    nPage = nPage + 1		
    
    return true, nil
  end 


  -- Local function to process the list of messages, getting id's and sizes
  --
  local function funcProcessLiveLight(body)
    lastNMsgs = nMsgs
    
    -- Figure out if there are more pages with messages
    --
    nextPageUrl = string.match(body, globals.strMsgListNextPagePatLiveLight)
    -- cdmackie 2008-07-02: qw now have to build post for subsequent page calls
    nextPageUrlPost = nil
    if nextPageUrl == nil then
      local startpos, endpos, pcur, pnam, pnad, pnmid = string.find(body, globals.strMsgListNextPagePatLiveLight3)
      local pattern4Use = false	  
	  if (startpos == nil) then
	    startpos, endpos, pcur, pnam, pnad, pnmid = string.find(body, globals.strMsgListNextPagePatLiveLight4)
		pattern4Use = true
	  end
      if startpos ~= nil then
          nextPageUrl = string.format(globals.strCmdMsgListLive3, internalState.strCrumb, internalState.strUserId)
        local inboxid = string.gsub(internalState.strMBox, "&n=.*", "")
        pnad = cleanupLoginBody(pnad) -- replace &#58; with colons
        pnad = string.gsub(pnad, ":", "%%5C%%3A") -- replace colons with %5C%3A
		if pattern4Use then
          nextPageUrlPost = string.format(globals.strCmdMsgListPostLive4, inboxid, pnam, pnad, pcur, pnmid, nTotMsgs, internalState.strMT)				
		else
          nextPageUrlPost = string.format(globals.strCmdMsgListPostLive3, inboxid, pnam, pnad, pcur, pnmid, nTotMsgs, internalState.strMT)				
        end		  
      end
    end
    -- cdmackie: change in hotmail nextpage link (kept old one incase still used)
    if nextPageUrl == nil then
	    nextPageUrl = string.match(body, globals.strMsgListNextPagePatLiveLight2)
    end
    if (nextPageUrl ~= nil) then
      if (nextPageUrlPost ~= nil) then
        log.dbg("Found another page of messages: " .. nextPageUrl .. ", POST:" .. nextPageUrlPost)
      else
        log.dbg("Found another page of messages: " .. nextPageUrl)
      end
    end

    -- Tokenize out the message ID and size for each item in the list
    --    
    -- cdmackie 2008-07-02: new message patterns and different for first and ajax calls
    for msgrow, msgcells in string.gfind(body, globals.strMsgLiveLightPattern) do
      local mad = string.match(msgrow, globals.strMsgLiveLightPatternMad)
      local uidl = string.match(msgrow, globals.strMsgLiveLightPatternUidl)
      local fulluidl = uidl .. "&" .. mad
      local size = string.match(msgcells, globals.strMsgLiveLightPatternSize)
	  if (size == nil) then
	    size = "1 KB" -- Some versions of hotmail don't display the size.
	  end

      if not uidl or not size then
        log.say("Hotmail Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

  	  if (string.match(msgrow, globals.strMsgLiveLightPatternUnread)) then
	    internalState.unreadStatus[uidl] = true
	  end

      local bUnique = true
      for j = 0, nMsgs do
        if knownIDs[j + 1] == uidl then
          bUnique = false
          break
        end        
      end
	  size = parseSize(size)

      -- Save the information
      --
      if bUnique == true and ((nMsgs < nTotMsgs and nTotMsgs ~= 0) or nTotMsgs == 0) then
        nMsgs = nMsgs + 1
		processMessage(uidl, size, nMsgs, pstate)
        knownIDs[nMsgs] = uidl
        internalState.msgIds[nMsgs] = fulluidl
      end
    end

	-- Some accounts haven't been upgraded to the newer version of the live light interface and thus, we need to make a second chec.
	-- This is terrible and needs to be removed when it can be!
    for uidl, size in string.gfind(body, globals.strMsgLiveLightPatternOld) do
      if not uidl or not size then
        log.say("Hotmail Module needs to fix it's individual message list pattern matching.\n")
        return nil, "Unable to parse the size and uidl from the html"
      end

      local bUnique = true
      for j = 0, nMsgs do
        if knownIDs[j + 1] == uidl then
          bUnique = false
          break
        end        
      end
	  size = parseSize(size)

      -- Save the information
      --
      if bUnique == true and ((nMsgs < nTotMsgs and nTotMsgs ~= 0) or nTotMsgs == 0) then
        nMsgs = nMsgs + 1
		processMessage(uidl, size, nMsgs, pstate)
        knownIDs[nMsgs] = uidl
        internalState.msgIds[nMsgs] = uidl
      end
    end	
	
    -- We are done with this page, increment the counter
    --
    nPage = nPage + 1		
    
    return true, nil
  end 

  -- Local Function to check for more pages of messages.  If found, the 
  -- change the command url
  --
  local function funcCheckForMorePages(body) 
    -- Prevent an infinite loop
	--
    if (lastNMsgs == nMsgs) then
      return true
    end
  
    if (internalState.bLiveLightGUI) then
      if (nextPageUrl == nil) then
        return true
      else 
	    if (string.match(nextPageUrl, "^http") == nil) then
          cmdUrl = "http://" .. internalState.strMailServer .. "/mail/" .. nextPageUrl
		end
        cmdUrlPost = nextPageUrlPost
        return false
      end		
    end
    
    -- See if there are messages remaining
    --
    if nMsgs < nTotMsgs then
      cmdUrl = baseUrl .. string.format(globals.strCmdMsgListNextPage, nPage)
      return false
    else
      -- For western languages, our patterns don't work so use a backup pattern.
      --
      if (nTotMsgs == 0 and 
          string.find(body, globals.strMsgListNextPagePattern) ~= nil) then
        cmdUrl = baseUrl .. string.format(globals.strCmdMsgListNextPage, nPage)
        return false
      end
      return true
    end
  end

  -- Local Function to get the list of messages
  --
  local function funcGetPage()  
    -- Debug Message
    --
    log.dbg("Debug - Getting page: ".. cmdUrl)

    -- Get the page and check to see if we got results
    --
    local body, err = getPage(browser, cmdUrl, cmdUrlPost, "STAT Page - LiveLight and NonLive")
    if body == nil then
      return body, err
    end

    -- Check to see if we got a good page back.  The folder list is
    -- notorous for returning Server busy or page not available
    --
    if (internalState.bLiveLightGUI == false and string.find(body, globals.strRetStatBusy) == nil) then
      return nil, "Hotmail is returning an error page."
    end

    -- Is the session expired
    --
    -- dhh 2008-07-05: fix for non live light interface.
    local bSessionExpired = false
    if (internalState.bLiveLightGUI == false) then
      local strSessExpr = string.match(body, globals.strRetLoginSessionExpired)
      if strSessExpr ~= nil then
        bSessionExpired = true
      end
    else
      local strSessExprLight = string.match(body, globals.strRetLoginSessionExpiredLiveLight)
      local strSessExprLive = string.match(body, globals.strRetLoginSessionExpiredLive)
      if strSessExprLight == nil and strSessExprLive == nil then
        bSessionExpired = true
      end
    end
    if bSessionExpired == true then
      -- Invalidate the session
      --
      internalState.bLoginDone = nil
      session.remove(hash())
      log.dbg("Session Expired - Last page loaded: " .. cmdUrl)

      -- Try Logging back in
      --
      logout() 
      local status = loginHotmail()
      if status ~= POPSERVER_ERR_OK then
        return nil, "Session expired.  Unable to recover"
      end
	
      -- Reset the local variables		
      --
      browser = internalState.browser
      if (internalState.bLiveLightGUI) then    
        cmdUrl = string.format(globals.strCmdMsgListLiveLight, internalState.strMailServer, 
          internalState.strMBox);
      else
        cmdUrl = string.format(globals.strCmdMsgList, internalState.strMailServer,
          internalState.strCrumb, internalState.strMBox);
      end
      baseUrl = cmdUrl
      if nPage > 1 then
        cmdUrl = cmdUrl .. string.format(globals.strCmdMsgListNextPage, nPage)
      end

      -- Retry to load the page
      --
      return getPage(browser, cmdUrl, nil, "STAT Page - LiveLight and NonLive")
    end

    -- cdmackie 2008-07-02: live light needs crumb now
    if (internalState.bLiveLightGUI) then    
      if internalState.strCrumb == "" then
        internalState.strCrumb = string.match(body, globals.strRegExpCrumbLiveLight)
      end
      if internalState.strUserId == "" then
        internalState.strUserId = string.match(body, globals.strRegExpUserLiveLight)
      end
    end
		
    -- Get the total number of messages
    --
    if nTotMsgs == 0 then
      local strTotMsgs
      if (internalState.bLiveLightGUI == false) then    
        strTotMsgs = string.match(body, globals.strMsgListCntPattern)
      else
        strTotMsgs = string.match(body, globals.strMsgListLiveLightCntPattern)
      end
      if strTotMsgs == nil then
        nTotMsgs = 0
      else 
        -- The number of messages can be in one of two patterns
        --
        if (internalState.bLiveLightGUI == false) then    
          nTotMsgs = string.match(strTotMsgs, globals.strMsgListCntPattern2)
          if (nTotMsgs == nil) then
            nTotMsgs = 0
          end
        else 
          nTotMsgs = strTotMsgs
        end
        nTotMsgs = tonumber(nTotMsgs)
      end

      if internalState.statLimit ~= nil then
        local nMaxMsgs = internalState.statLimit
        if (nTotMsgs == 0 or nTotMsgs > nMaxMsgs) then
          if (nTotMsgs == 0) then
            bIgnoreFinalTest = true
          end			
          nTotMsgs = nMaxMsgs
        end
      end  

      log.dbg("Total messages in message list: " .. nTotMsgs)
    end

    -- Make sure the page is valid
    -- 
    if internalState.bLiveLightGUI == false and string.find(body, globals.strMsgListGoodBody) == nil then
      return nil, "Hotmail returned with an invalid page."
    end
	
    return body, err
  end


  -- Run through the pages and pull out all the message pieces from
  -- all the message lists
  --
  local fnProcess = funcProcess
  if (internalState.bLiveLightGUI) then
    fnProcess = funcProcessLiveLight
  end
  if not support.do_until(funcGetPage, funcCheckForMorePages, fnProcess) then
    session.remove(hash())
    log.error_print("Session removed (STAT Failure) - Account: " .. internalState.strUser .. 
      "@" .. internalState.strDomain) 
    return POPSERVER_ERR_NETWORK
  end
	
  -- Update our state
  --
  internalState.bStatDone = true
	
  -- Check to see that we completed successfully.  If not, return a network
  -- error.  This is the safest way to let the email client now that there is
  -- a problem but that it shouldn't drop the list of known uidls.
  if (nMsgs < nTotMsgs and nMsgs > 0) then
    log.error_print("The plugin needs updating.  Expecting to find: " .. nTotMsgs .. 
	  " and processed " .. nMsgs)
    return POPSERVER_ERR_OK
  elseif (nMsgs < nTotMsgs and nMsgs == 0 and bIgnoreFinalTest == false) then
    log.error_print("The plugin needs updating.  Expecting to find: " .. nTotMsgs ..
	  " but wasn't able to process any.")
	return POPSERVER_ERR_NETWORK
  end

  -- Return that we succeeded
  --
  return POPSERVER_ERR_OK
end

function processMessage(uidl, size, nMsgs, pstate)
  log.dbg("Processed STAT - Msg: " .. nMsgs .. ", UIDL: " .. uidl .. ", Size: " .. size)
  set_popstate_nummesg(pstate, nMsgs)
  set_mailmessage_size(pstate, nMsgs, size)
  set_mailmessage_uidl(pstate, nMsgs, uidl)
end

function parseSize(size)
  -- Convert the size from it's string (4KB or 2MB) to bytes
  -- First figure out the unit (KB or just B)
  --
  local kbUnit = string.match(size, "([Kk])")
  size = string.match(size, "([%d%.,]+)%s*[KkMm]") -- cdmackie 2008-07-02: fix for space
  if (size ~= nil) then
	size = string.gsub(size, ",", ".")
  end
  if (size ~= nil and tonumber(size) ~= nil) then
	if not kbUnit then 
	  size = math.max(tonumber(size), 0) * 1024 * 1024
	else
	  size = math.max(tonumber(size), 0) * 1024
	end
  else
	size = 1024
  end
  return size
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

  -- Logging
  --
  require("smartlog")
  smartlog.setLoggingPrefixCallBack(function(kind, info) 
    local prefix = ""
    if info then
      prefix = "(".. info.short_src .. ", " .. info.currentline 
    end
	if (internalState ~= nil and internalState.strUser ~= nil) then
	  prefix = prefix .. ", " .. internalState.strUser .. "@" .. internalState.strDomain
	end
	prefix = prefix .. ") "
    return prefix
  end)

  -- Browser
  --
  require("browser")
	
  -- MIME Parser/Generator
  --
  require("mimer")

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

-- EOF
-- ************************************************************************** --

