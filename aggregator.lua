-- --------------------------- READ THIS PLEASE ----------------------------- --
-- This file is not only the RSS/RDF aggregator plugin. Is is also a well 
-- documented example of webnews plugin. 
--
-- Before reading this you should learn something about lua. The lua 
-- language is an excellen (at least in my opinion), small and easy 
-- language. You can learn something at http://www.lua.org (the main website)
-- or at http://lua-users.org/wiki/TutorialDirectory (a good and short tutorial)
--
-- Feel free to contact the author if you have problems in understanding 
-- this file
--
-- To start writing a new plugin please use skeleton.lua as the base.
-- -------------------------------------------------------------------------- --

-- ************************************************************************** --
--  FreePOPs RSS/RDF aggregator xml news interface
--  
--  $Id$
--  
--  Released under the GNU/GPL license
--  Written by Simone Vellei <simone_vellei@users.sourceforge.net>
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.2.10"
PLUGIN_NAME = "RSS/RDF aggregator"
PLUGIN_REQUIRE_VERSION = "0.2.0"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?module=aggregator.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Simone Vellei"}
PLUGIN_AUTHORS_CONTACTS = {"simone_vellei (at) users (.) sourceforge (.) net"}
PLUGIN_DOMAINS = {"@aggregator","@..."}
PLUGIN_PARAMETERS = {}
PLUGIN_DESCRIPTIONS = {
	it= [[
Solitamente potete trarre beneficio dal for mato RSS del W3C quando leggete
news da qualche sito web. Il file RSS indicizza le news, fornendo un 
link verso di esse. Questo plugin pu&ograve; far s&igrave; che il vostro 
client di posta veda il file RSS come una mailbox da cui potete 
scaricare ogni news come se fosse una mail. L'unica limitazione 
&egrave; che questo plugin pu&ograve; prelevare solo un sunto delle news
pi&ugrave; il link alle news. 
Per usare questo plugin dovete usare un nome utente casuale con il 
suffisso @aggregator (es.: foo@aggregator) e come password l'URL del file RSS
(es.: http://www.securityfocus.com/rss/vulnerabilities.xml). Per 
comodit&agrave; abbiamo aggiunto per voi alcuni alias. 
Questo significa che non dovrete cercare a mano l'URL del file RSS. 
Abbiamo aggiunto alcuni domini, per esempio 
@securityfocus.com, che possono essere usati per sfruttare direttamente
il plugin aggregator con questi siti web. Per usare questi alias dovrete usare
un nome utente nella for ma qualcosa@aggregatordomain e una password a
caso.]],
	en= [[
Usually you can benefit from the W3C's RSS for mat when you read some 
website news. The RSS file indexes the news, 
providing a link to them. This plugin
can make your mail client see the RSS file as a mailbox from which you can
download each news as if it was a mail message. The only limitation is that
this plugin can fetch only a news summary plus the news link.
To use this plugin you have to use a casual user name with the @aggregator
suffix (ex: foo@aggregator) and as the password the URL of the RSS file(ex:
http://www.securityfocus.com/rss/vulnerabilities.xml). For your 
commodity we added some alias for you. This means you have not to search by
hand the URL of the RSS file. We added some domain, 
for example @securityfocus.com,
that can be used to directly use the aggregator plugin with these website. To
use these alias you have to use a user name in the form 
something@aggregatordomain
and a casual password.]],
}

-- Configuration:
--
-- Username must be ".....@aggregator"
-- Password must be a pointer to RSS/RDF file 
-- Es. "http://flatnuke.sourceforge.net/misc/backend.rss"
-- 
--
-- We take the header and body news filed to mail message body and the title to
-- mail subject.
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

local rss,charset

local rss_string = {
	charsetC = "xml version=\"[^\"]*\" encoding=\"([^\?]*)\"",
	itemsbC = "<items>",
	itemseC = "</items>",
	item_bC = "<item",
	item_eC = "</item>",
	itemC = "(</item>)",
	linkC = "<link[^>]*>(.*)</link>",
	link2C = "<guid[^>]*>(.*)</guid>",
	titleC = "<title>(.*)</title>",
	descC = "<desc[^>]*>(.*)</desc[^>]*>",
	contentC = "<content:encoded>(.*)</content:encoded>",
	dcdateC = "<dc:date>(.*)</dc:date>",
	dateC = "<pubDate[^>]*>(.*)</pubDate[^>]*>"
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
-- Converts HTML news tag into text
--
function ripHTML(str)
	str=string.gsub(str,"\n","")
	str=string.gsub(str,"\r","") 
	str=string.gsub(str,"\t","") 
	str=string.gsub(str,"|","-")
	str=string.gsub(str,":","-")
	str=string.gsub(str,"<[Tt][Rr]>","\n") 
	str=string.gsub(str,"</[Tt][Hh]>","\t") 
	str=string.gsub(str,"</[Tt][Dd]>","\t") 
	str=string.gsub(str,"<[Bb][Rr]>","\n") 
	str=string.gsub(str,"<[Uu][Ll]>","\n") 
	str=string.gsub(str,"</[Uu][Ll]>","\n\n") 
	str=string.gsub(str,"<[Ll][Ii]>","\n\t* ") 
	str=string.gsub(str,"&amp;","&") 

	str=string.gsub(str,"&quot;","\"") 	
	str=string.gsub(str,"&gt;",">") 
	str=string.gsub(str,"&lt;","<")
	str=string.gsub(str,"<a href=\"([^\"]*)\"[^>]*>([^<]*)</a>","%2 (%1)")
	str=string.gsub(str,"</p>","\n")
	
	str=string.gsub(str,"<.->","") 
	
	return str	
end

----------------------------------------------------------
-- This function is not intended to be reversible
-- 
function fromHTML(str,encoding)
  if (encoding == nil) then
	  encoding = "utf-8"
  end

  if ((string.upper(encoding)=="ISO-8859-1") or (string.upper(encoding)=="ISO-8859-15")) then
    str=string.gsub(str,"&agrave;","\224")
    str=string.gsub(str,"&aacute;","\225")
    str=string.gsub(str,"&egrave;","\232")
    str=string.gsub(str,"&eacute;","\233")
    str=string.gsub(str,"&igrave;","\236")
    str=string.gsub(str,"&iacute;","\237")
    str=string.gsub(str,"&ograve;","\242")
    str=string.gsub(str,"&oacute;","\243")
    str=string.gsub(str,"&ugrave;","\249")
    str=string.gsub(str,"&uacute;","\250")
    str=string.gsub(str,"&Agrave;","\192")
    str=string.gsub(str,"&Aacute;","\193")
    str=string.gsub(str,"&Egrave;","\200")
    str=string.gsub(str,"&Eacute;","\201")
    str=string.gsub(str,"&Igrave;","\204")
    str=string.gsub(str,"&Iacute;","\205")
    str=string.gsub(str,"&Ograve;","\210")
    str=string.gsub(str,"&Oacute;","\211")
    str=string.gsub(str,"&Ugrave;","\217")
    str=string.gsub(str,"&Uacute;","\218")
    str=string.gsub(str,"&ccedil;","\231") 
    str=string.gsub(str,"&Ccedil;","\199") 
    str=string.gsub(str,"&ntilde;","\241")
    str=string.gsub(str,"&Ntilde;","\209")
	
    str=string.gsub(str,"&apos;",  "\039")
    -- for this character the conversion is not simetric
    -- because it can generate a missbehaviour of the HTML
    -- in this conversion for sure it will also cause 
    -- some missbehaviour, but is the functionaliy needed
    -- for a good conversion of the title
  elseif (string.upper(encoding)=="UTF-8") then
    str=string.gsub(str,"&agrave;","\195\160")
    str=string.gsub(str,"&aacute;","\195\161")
    str=string.gsub(str,"&egrave;","\195\168")
    str=string.gsub(str,"&eacute;","\195\168")
    str=string.gsub(str,"&igrave;","\195\172")
    str=string.gsub(str,"&iacute;","\195\173")
    str=string.gsub(str,"&ograve;","\195\178")
    str=string.gsub(str,"&oacute;","\195\179")
    str=string.gsub(str,"&ugrave;","\195\185")
    str=string.gsub(str,"&uacute;","\195\186")
    str=string.gsub(str,"&Agrave;","\195\128")
    str=string.gsub(str,"&Aacute;","\195\129")
    str=string.gsub(str,"&Egrave;","\195\136")
    str=string.gsub(str,"&Eacute;","\195\137")
    str=string.gsub(str,"&Igrave;","\195\140")
    str=string.gsub(str,"&Iacute;","\195\141")
    str=string.gsub(str,"&Ograve;","\195\146")
    str=string.gsub(str,"&Oacute;","\195\147")
    str=string.gsub(str,"&Ugrave;","\195\153")
    str=string.gsub(str,"&Uacute;","\195\154")
    str=string.gsub(str,"&ccedil;","\195\167") 
    str=string.gsub(str,"&Ccedil;","\195\135") 
    str=string.gsub(str,"&ntilde;","\195\177")
    str=string.gsub(str,"&Ntilde;","\195\145")
	
    str=string.gsub(str,"&apos;",  "\039")	
  end	
	
  return str
end


--------------------------------------------------------------------------------
-- Recode tilde, acute, grave...
--      http://www.macchiato.com/unicode/convert.html

function toHTML(str,encoding)
  if (encoding == nil) then
	  encoding = "utf-8"
  end

  if ((string.upper(encoding)=="ISO-8859-1") or (string.upper(encoding)=="ISO-8859-15")) then
    str=string.gsub(str,"\224",    "&agrave;")
    str=string.gsub(str,"\225",    "&aacute;")
    str=string.gsub(str,"\232",    "&egrave;")
    str=string.gsub(str,"\233",    "&eacute;")
    str=string.gsub(str,"\236",    "&igrave;")
    str=string.gsub(str,"\237",    "&iacute;")
    str=string.gsub(str,"\242",    "&ograve;")
    str=string.gsub(str,"\243",    "&oacute;")
    str=string.gsub(str,"\249",    "&ugrave;")
    str=string.gsub(str,"\250",    "&uacute;")
    str=string.gsub(str,"\192",    "&Agrave;")
    str=string.gsub(str,"\193",    "&Aacute;")
    str=string.gsub(str,"\200",    "&Egrave;")
    str=string.gsub(str,"\201",    "&Eacute;")
    str=string.gsub(str,"\204",    "&Igrave;")
    str=string.gsub(str,"\205",    "&Iacute;")
    str=string.gsub(str,"\210",    "&Ograve;")
    str=string.gsub(str,"\211",    "&Oacute;")
    str=string.gsub(str,"\217",    "&Ugrave;")
    str=string.gsub(str,"\218",    "&Uacute;")
    str=string.gsub(str,"\231",    "&ccedil;")
    str=string.gsub(str,"\199",    "&Ccedil;")
    str=string.gsub(str,"\241",    "&ntilde;")
    str=string.gsub(str,"\209",    "&Ntilde;")
  elseif (string.upper(encoding)=="UTF-8") then
    str=string.gsub(str,"\195\160","&agrave;")
    str=string.gsub(str,"\195\161","&aacute;")
    str=string.gsub(str,"\195\168","&egrave;")
    str=string.gsub(str,"\195\169","&eacute;")
    str=string.gsub(str,"\195\172","&igrave;")
    str=string.gsub(str,"\195\173","&iacute;")
    str=string.gsub(str,"\195\178","&ograve;")
    str=string.gsub(str,"\195\179","&oacute;")
    str=string.gsub(str,"\195\185","&ugrave;")
    str=string.gsub(str,"\195\186","&uacute;")
    str=string.gsub(str,"\195\128","&Agrave;")
    str=string.gsub(str,"\195\129","&Aacute;")
    str=string.gsub(str,"\195\136","&Egrave;")
    str=string.gsub(str,"\195\137","&Eacute;")
    str=string.gsub(str,"\195\140","&Igrave;")
    str=string.gsub(str,"\195\141","&Iacute;")
    str=string.gsub(str,"\195\146","&Ograve;")
    str=string.gsub(str,"\195\147","&Oacute;")
    str=string.gsub(str,"\195\153","&Ugrave;")
    str=string.gsub(str,"\195\154","&Uacute;")
    str=string.gsub(str,"\195\167","&ccedil;")
    str=string.gsub(str,"\195\135","&Ccedil;")
    str=string.gsub(str,"\195\177","&ntilde;")
    str=string.gsub(str,"\195\145","&Ntilde;")
  end
    
  str=string.gsub(str,"&amp;","&") 
  -- str=string.gsub(str,"&quot;","\"") 	
  str=string.gsub(str,"&gt;",">") 
  str=string.gsub(str,"&lt;","<")
	
	return str
end

--------------------------------------------------------------------------------
-- Build a mail header date string
--
function build_date(str)
	if(str==nil) then
		-- return(os.date("%a, %d %b %Y %H:%M:%S"))
		return("Sun, 01 Jan 2008 00:00:00")
	else
		return(str)
	end	
end

--------------------------------------------------------------------------------
-- Build a mail header
--
function make_valid_domain(s)
	s = string.gsub(s,"[^%a%d]",".")
	s = string.gsub(s,"%.+",".")
	if (string.sub(s,-1)==".") then
    s = string.sub(s,1,-2)
	end
	return s
end

function build_mail_header(title,uidl,mydate)
	return 
	"Message-Id: <"..uidl..">\r\n"..
	"To: "..internal_state.name.."@"..
		make_valid_domain(internal_state.password).."\r\n"..
	"Date: "..build_date(mydate).."\r\n"..
	"Subject: "..title.."\r\n"..
	"From: freepops@"..make_valid_domain(internal_state.password).."\r\n"..
	"User-Agent: freepops "..PLUGIN_NAME..
		" plugin "..PLUGIN_VERSION.."\r\n"--..
	--"MIME-Version: 1.0\r\n"..
	--"Content-Disposition: inline\r\n"..
	--"Content-Type: text/html; charset=\""..charset.."\"\r\n"
	-- This header cause some problems with link like [...]id=123[...]
	-- "Content-Transfer-Encoding: quoted-printable\r\n"
end

function hackw3cdate(mydate)
  if (string.find(mydate,",") == nil) then
    if (string.find(mydate,":") == nil) then
	    return(nil)
	  else
	    --1997-07-16T19:20:30.45+01:00
	    local year=string.match(mydate,"(%d*)%-")
	    local month=string.match(mydate,year.."%-(%d*)%-")
	    local day=string.match(mydate,year.."%-"..month.."%-(%d*)")
	    local hour=string.match(mydate,"T(%d*):")
	    local mins=string.match(mydate,hour..":(%d*)")
	    mydate=getdate.toint(month.."/"..day.."/"..year.." "..hour..":"..mins..":00")
	    mydate=os.date("%a, %d %b %Y %H:%M:%S",mydate)
	  end
  end
    
  log.dbg("Date:"..mydate)
    
  --Wed, 01 Sep 2004 15:50:29 +2000
  mydate = string.gsub(mydate,"+(%.*)","")
    
  mydate = string.gsub(mydate,"\r","")
  mydate = string.gsub(mydate,"\n","")    

  return(mydate)
end
--------------------------------------------------------------------------------
-- retr and top aree too similar. discrimitaes only if lines ~= nil
--
function retr_or_top(pstate,msg,data,lines)
	-- we need the stat
	local st = stat(pstate)
  if st ~= POPSERVER_ERR_OK then
    return st
  end
	
  local uidl = get_mailmessage_uidl(pstate,msg)
	
  --get it
	
  local s2=rss
  local starts2
  local ends2
  local chunk

  starts2,_,_=string.find(s2,rss_string.itemsbC)
  ends2,_,_=string.find(s2,rss_string.itemseC)
  if ((starts2 ~= nil) and (ends2 ~= nil)) then
    chunk=string.sub(s2,starts2,ends2)
    s2=string.sub(s2,ends2+3)
  end
	
	for i=1,msg do
    starts2,_,_=string.find(s2,rss_string.item_bC)
    ends2,_,_=string.find(s2,rss_string.item_eC)
    chunk=string.sub(s2,starts2,ends2)
    s2=string.sub(s2,ends2+3)
	end
									
	local title=string.match(chunk,rss_string.titleC)
	title=string.gsub(title,"<!%[CDATA%[","")
 	title=string.gsub(title,"%]%]>","")

	local header=string.match(chunk,rss_string.linkC)
	if ((header == nil) or (header == "")) then
		header=string.match(chunk,rss_string.link2C)
	end
	if ((header == nil) or (header == "")) then
		header=string.match(chunk,rss_string.titleC)
		header = string.gsub(uidl,"[^%a%d]",".")
		header = string.gsub(uidl,"%.+",".")
	end
	
	
	local body=string.match(chunk,rss_string.descC)
	if (body ~= nil) then
		body=string.gsub(body,"<!%[CDATA%[","")
		body=string.gsub(body,"%]%]>","")
	end
	
	--this is enabled in 
	-- xmlns:content="http://purl.org/rss/1.0/modules/content/"
	local content=string.match(chunk,rss_string.contentC)
	-- content contains description
	if ((content ~= nil) and (body ~= nil)) then
		body=content
 		body=string.gsub(body,"<!%[CDATA%[","")
 		body=string.gsub(body,"%]%]>","")
	end
	
	local mydate=string.match(chunk,rss_string.dateC)
	if (mydate == nil) then
		 mydate=string.match(chunk,rss_string.dcdateC)
	end
        
	-- is it W3C date?	
	if (mydate ~= nil) then
    --Wed, 01 Sep 2004 15:50:29
    --1997-07-16T19:20:30.45+01:00
    mydate=hackw3cdate(mydate)
	end

	if ((body == nil) or (body == "")) then
		body="Not available"
	end

	if ((header == nil) or (body == nil) or (title == nil)) then
		log.error_print("Error parsing: title="..
			(title or "nil").." header="..
			(header or "nil").." body="..(body or "nil"))
	end

--log.error_print(title)
--log.error_print(charset)

	--clean it
	header=ripHTML(fromHTML(toHTML(header,charset)))
	title=ripHTML(fromHTML(toHTML(title,charset)))
	body=toHTML(body,charset)
	--body=html2txt(body)	

--log.error_print(title)

	--build it
	local h = build_mail_header(title,uidl,mydate) 
	local s = "\<html><body>\r\n"
		
	if (string.find(header,"http://") or 
		string.find(header,"https://")) then
		s = s..
			"<p>\r\n"..		
			"<b>News link:</b>\r\n"..
			"<br/>\r\n" ..		
			"<a href="..header..">\r\n"..
			header.."\r\n"..
			"</a>\r\n"..
			"</p>\r\n<br/>\r\n"
	end
	
	s = s..	
		"<p>\r\n"..
		"<b>News description:</b>\r\n"..
		"<br/>\r\n".."\r\n"..
		body.."\r\n"..
		"</body></html>\r\n"

	local cb
	if lines == nil then 
		cb = common.retr_cb(data)
	else
		local global = common.new_global_for_top(lines,nil)
		cb = common.top_cb(global, data,true)
	end
	mimer.pipe_msg(h,nil,s,"",{},nil,mimer.callback_mangler(cb),{},charset)
	
	return POPSERVER_ERR_OK
end

-- ************************************************************************** --
--  aggregator functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
	
	-- extract username
	local name = get_name(username)

	-- save name
	internal_state.name = name
	
	return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
  if internal_state.login_done then
    return POPSERVER_ERR_OK
  end

  -- save the password
  -- password is the RSS/RDF file URI 
  if (freepops.MODULE_ARGS ~= nil) then
    if freepops.MODULE_ARGS.host ~= nil then
      internal_state.password = freepops.MODULE_ARGS.host
    else
      internal_state.password = password
    end
  end

  if ((string.find(internal_state.password,"http://") == nil) and (string.find(internal_state.password,"https://") == nil)) then
    log.error_print("Not a valid URI: "..internal_state.password.."\n")
    return POPSERVER_ERR_NETWORK
  end
						 
  -- build the uri
  local user = internal_state.name
	
  -- the browser must be preserved
  internal_state.b = browser.new()
	
  local b = internal_state.b
  b:ssl_init_stuff()
  -- b:verbose_mode()
	
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
--log.error_print("start action_f")
		rss=s
		charset=string.match(rss,rss_string.charsetC)
		if (charset == nil) then
			charset = "utf-8"
		end
		local a=0
		local start=0
		local nmess=0
		while(a~=nil) do
			start,_,a=string.find(s,rss_string.itemC,start+1);
			if(a~=nil) then
				nmess=nmess+1
			end
			
		end
		local n=nmess
		
--log.error_print("nummesg:"..nmess)
		if (nmess==0) then
			return true,nil
		end

		-- this is not really needed since the structure 
		-- grows automatically... maybe... don't remember now
		set_popstate_nummesg(pstate,nmess)

		-- gets all the results and puts them in the popstate structure
		local s2=s
		local starts2
		local ends2
		for i = 1,n do
			starts2,_,_=string.find(s2,rss_string.item_bC);
			ends2,_,_=string.find(s2,rss_string.item_eC);
			local chunk=string.sub(s2,starts2,ends2)
			s2=string.sub(s2,ends2+3)
			
			uidl = string.match(chunk,rss_string.titleC)

			local link
			link = string.match(chunk,rss_string.linkC)
			if (link ~= nil) then
			    uidl = uidl.."."..link
			end
			link = string.match(chunk,rss_string.link2C)
			if (link ~= nil) then
			    uidl = uidl..link
			end

			uidl = string.gsub(uidl,"[^%a%d]",".")
			uidl = string.gsub(uidl,"%.+",".")
			uidl = string.gsub(uidl,"^%.","")
			uidl = string.gsub(uidl,"%.$","")
			uidl = string.sub(uidl,1,250)

			--fucking default size
			local size=4096

			if ((not uidl) or (not size)) then
				return nil,"Unable to parse uidl"
			end

--log.error_print("uidl: "..uidl)

			-- set it
			set_mailmessage_size(pstate,i,size)
			uidl=base64.encode(uidl)
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

	freepops.need_ssl()
	
	-- the common implementation module
	require("common")

	require("mimer")
	
	-- checks on globals
	freepops.set_sanity_checks()
	
	return POPSERVER_ERR_OK
end

-- EOF
-- ************************************************************************** --
