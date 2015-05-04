-- ************************************************************************** --
--  FreePOPs Horde/IMP webmail interface
--  
--  $Id: imp.lua,v 0.0.3 2008/12/01 16:15:14 vitoco Exp $
--  
--  Released under the GNU/GPL license
--  Written by Victor Parada vitoco at users sourceforge net
--  Portions of this code are based on templates and other FreePOPs plugins
-- ************************************************************************** --

-- these are used in the init function
PLUGIN_VERSION = "0.0.3c"
PLUGIN_NAME = "imp"
PLUGIN_REQUIRE_VERSION = "0.0.99"
PLUGIN_LICENSE = "GNU/GPL"
PLUGIN_URL = "http://www.freepops.org/download.php?contrib=imp.lua"
PLUGIN_HOMEPAGE = "http://www.freepops.org/"
PLUGIN_AUTHORS_NAMES = {"Victor Parada"}
PLUGIN_AUTHORS_CONTACTS = {"vitoco - users sourceforge net"}
PLUGIN_DOMAINS = {"@imp","@inf.utfsm.cl","@alumnos.inf.utfsm.cl","@f2s.com","@free.fr","@..."}
PLUGIN_PARAMETERS = {
  {name = "domain | d", description = {
    it = [[
Richiesto solo quando si usa <SAMP>utente@<B>imp</B></SAMP> come username.
]],
    en = [[
Required only when the plugin is activated using <SAMP>user@<B>imp</B></SAMP>
as the username.
]],
    es = [[
Requerido s&oacute;lo cuando se especifica <SAMP>usuario@<B>imp</B></SAMP>
para activar el plugin.
]],
    }
  },
  {name = "email | e", description = {
    it = [[
Usare <SAMP>yes</SAMP> quando la username deve essere l&acute;indirizzo
email completo.
]],
    en = [[
Use <SAMP>yes</SAMP> when the login username has to be the full email
address.
]],
    es = [[
Use <SAMP>yes</SAMP> cuando el usuario de conexi&oacute;n debe ser la
direcci&oacute;n de correo completa.
]],
    }
  },
  {name = "webmail | w", description = {
    it = [[
Indica la URI dove IMP risiede, compreso di protocollo e/o del numero
della porta, per esempio:
<SAMP>https://webmail.mioserver.foo</SAMP>
]],
    en = [[
Indicates the webmail server where IMP resides, including protocol
and/or port number, for example:
<SAMP>https://webmail.myserver.foo</SAMP>
]],
    es = [[
Especifica el servidor web donde reside IMP, incluyendo el protocolo
y/o el puerto, por ejemplo:
<SAMP>https://webmail.miservidor.foo</SAMP>
]],
    }
  },
  {name = "server | s", description = {
    it = [[
Richiesto quando il server IMP gestisce pi&ugrave; domini indipendenti.
Questa &egrave; la chiave che identifica il vostro.
]],
    en = [[
Required when IMP server is able to manage many independant domains.
This is the key that identifies yours.
]],
    es = [[
Requerido cuando el servidor IMP es capaz de administrar varios dominios
independientes. Especifica la llave que identifica al propio.
]],
    }
  },
  {name = "path | z", description = {
    it = [[
Percorso di IMP sul webserver, di default &egrave; <SAMP>/horde/imp</SAMP>
]],
    en = [[
Path of IMP at the web server, defaults to <SAMP>/horde/imp</SAMP>
]],
    es = [[
Ruta de IMP en el servidor web, requerido cuando no es <SAMP>/horde/imp</SAMP>
]],
    }
  },
  {name = "purge | p", description = {
    it = [[
Di default, i messaggi eliminati vengono spostati nel Cestino o marcati
per una futura eliminazione.
Usare <SAMP>yes</SAMP> per eliminarli dal server.
Attenzione: con questo parametro verranno anche eliminati quei messaggi
marcati per l&acute;eliminazione precedentemente all&acute;installazione
del plugin.
]],
    en = [[
By default, deleted messages are only moved to a trash folder or marked
for future removal.
Use <SAMP>yes</SAMP> to remove them from the server.
Warning: this will also purge all messages previously marked without the
use of this plugin.
]],
    es = [[
Al borrar mensajes, &eacute;stos por defecto son s&oacute;lo marcados o
movidos a la papelera en el servidor.
Usar <SAMP>yes</SAMP> para removerlos definitivamente.
Advertencia: esto eliminar&aacute; todos los mensajes marcados previamente
sin usar este plugin.
]],
    }
  },
  {name = "ignorecert | i", description = {
    it = [[
A volte i certificati SSL vengono invalidati utilizzando una connessione
sicura attraverso un proxy.
Usare <SAMP>yes</SAMP> per ignorare i certificati.
]],
    en = [[
Sometimes SSL certificates became invalid when using a secure conection
through a proxy.
Use <SAMP>yes</SAMP> to ignore certificates.
]],
    es = [[
Cuando se usa una conexi&oacute;n segura a trav&eacute;s de un proxy,
es posible que los certificados se invaliden.
Usar <SAMP>yes</SAMP> para ignorar certificados.
]],
    }
  },
}
PLUGIN_DESCRIPTIONS = {
  -- Italian translation by AlienPro <http://www.alienpro.it>
  it=[[
Questo plugin supporta le webmail realizzate con Horde/IMP utilizzando
il protocollo SSL.
Il plugin allo stato attuale &egrave; alle prime versioni beta.
E&acute; possibile modificare manualmente i parametri per adattarlo
alle proprie esigenze.
<BR>Usare <SAMP>utente@miodominio.foo</SAMP> se il vostro dominio &egrave;
elencato sopra, oppure
<SAMP>utente@<B>imp</B>?<B>domain</B>=miodominio.foo&amp;<B>webmail</B>=https://webmail.miodominio.foo</SAMP>
come username e la vostra vera password come password.
<BR>Potete anche usare la forma abbreviata dei parametri, per esempio:
<SAMP>utente@<B>imp</B>?<B>d</B>=miodominio.foo&amp;<B>w</B>=https://webmail.miodominio.foo&amp;<B>p</B>=<B>y</B>&amp;<B>i</B>=<B>y</B></SAMP>
<BR>Nota: utilizzando questo plugin e&acute; possibile che venga ripristinato
l&acute;ordinamento dei messaggi al valore di default (data di ricezione).
<BR>Per il supporto al plugin, si prega di inviare le richieste al
<A HREF="http://freepops.diludovico.it/showthread.php?t=4638">forum
in lingua inglese</A>
invece di scrivere all&acute;autore.
]],
  en=[[
This plugin supports webmails made with Horde/IMP using SSL.
You have to hack by hand the plugin to make it work with your website
if provided parameters are not enougth or want to set some defaults.
<BR>Use <SAMP>user@mydomain.foo</SAMP> if your domain is listed above, or
<SAMP>user@<B>imp</B>?<B>domain</B>=mydomain.foo&amp;<B>webmail</B>=https://webmail.mydomain.foo</SAMP>
as your username and your real password as the password.
<BR>You can use the brief form of the parameters, for example:
<SAMP>user@<B>imp</B>?<B>d</B>=mydomain.foo&amp;<B>w</B>=https://webmail.mydomain.foo&amp;<B>p</B>=<B>y</B>&amp;<B>i</B>=<B>y</B></SAMP>
<BR>Note: the use of this plugin could change your current mailbox&acute;s
sorting order to the default (received order).
<BR>For support, please post a question to the
<A HREF="http://freepops.diludovico.it/showthread.php?t=4638">forum</A>
instead of emailing the author.
]],
  es=[[
Este plugin soporta webmails basados en Horde/IMP usando SSL.
Tiene que ser adaptado a mano para ser usado en otros sitios
cuando los par&aacute;metros disponibles no son suficientes
o para definir valores por defecto.
<BR>Especifique <SAMP>usuario@midominio.foo</SAMP> si su dominio
aparece listado arriba, o
<SAMP>usuario@<B>imp</B>?<B>domain</B>=midominio.foo&amp;<B>webmail</B>=https://webmail.midominio.foo</SAMP>
como nombre de usuario de correo y su password real como clave.
<BR>Puede usar la forma abreviada para especificar par&aacute;metros,
por ejemplo:
<SAMP>usuario@<B>imp</B>?<B>d</B>=midominio.foo&amp;<B>w</B>=https://webmail.midominio.foo&amp;<B>p</B>=<B>y</B>&amp;<B>i</B>=<B>y</B></SAMP>
<BR>Nota: el uso de este plugin puede cambiar el orden actual para el listado
de los mensajes en la casilla por el valor por defecto (orden de llegada).
<BR>Si necesita ayuda, use los
<A HREF="http://freepops.diludovico.it/showthread.php?t=4638">foros de FreePOPs</A>
en lugar de enviar un mail al autor.
]]

}

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

local debug = false

local imp_domain = {
  ["inf.utfsm.cl"] = { webmail="https://wmalm.inf.utfsm.cl" }, -- server="PFIS"
  ["alumnos.inf.utfsm.cl"] = { webmail="https://wmalm.inf.utfsm.cl" }, -- server="ALM"
  ["f2s.com"] = { webmail="https://webmail.freedom2surf.net", email="yes" },
  ["free.fr"] = { webmail="http://imp.free.fr" },
}

local imp_string = {

  -- The default path of IMP installs
  partial_path = "/horde/imp",

  -- Start page uri, used to get the Session Id on cookies
  home = "%s%s/",

  -- Captures to get the login form and fields
  login_formC = "<form [^>]*action=\".-/redirect.php[^>]*>(.-)</form>",
  form_inputC= "(<[iI][nN][pP][uU][tT]%s+.->)(.*)$",

  -- The uri the browser uses when you click the "login" button
  login = "%s%s/redirect.php",
  login_post= "imapuser=%s&%s=%s&new_lang=en_US%s",
  -- The capture to check for a sucessful login
  loginC = "<form action=\"%S*mailbox.php\" method=\"get\" name=\"(.*)\">",
  loginframeC = "<frame name=\"horde_main\" src=",

  -- The uri to skip monthly maintenance
  maint = {
    [1] = "%s%s/redirect.php?maintenance_done=1&domaintenance=1",
    [2] = "%s%s/redirect.php",
  },
  maint_post = {
    [1] = "load_frameset=1",
    [2] = "confirm_maintenance=1",
  },
  -- The capture to check for maintenace after a login
  maintC = {
    [1] = "<form method=\"post\" action=\".-/(redirect.php%?maintenance_done=1&domaintenance=1)\"",
    [2] = "<form method=\"post\" action=\".-/(redirect.php)\" name=\"maint_confirm\">",
  },

  -- message list mlex
  statE = {
    [1] = "<tr>.*<td>.*<input>.*<label>.*</label>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*</tr>",
    [2] = "<tr>.*<td>.*<input>.*</td>.*<td>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*<td>.*<a>.*</a>.*</td>.*<td>.*</td>.*</tr>",
  },
  statG = {
    [1] = "<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>",
    [2] = "<O>O<O>O<X>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>O<O>X<O>O<O>",
  },

  -- The uri for the first page with the list of messages
  first = "%s%s/mailbox.php?mailbox=INBOX&sortby=1&sortdir=0&page=1",
  -- The uri to get the next page of messages
  next = "%s%s/mailbox.php?page=%d",
  -- The capture for the next page uri
  nextC ="<link href=\".-mailbox.php%?page=(%d+)\" rel=\"Next\"",

  -- The capture to understand if the session ended
  session_errorC = "(https?://.-/redirect.php)",

  -- The uri to view message source (for RETR and TOP)
  save = {
    [1] = "%s%s/view.php?popup_view=1&index=%d&mailbox=INBOX&actionID=view_source&id=0",--&mimecache=33945dad759d17863f4c017009be3c17',
    [2] = "%s%s/view.php?thismailbox=INBOX&index=%s&id=0&actionID=115&mime=",
  },

  -- The uri to delete some messages
  delete = "%s%s/mailbox.php",
  delete_post = {
    [1] = "actionID=delete_messages&targetMbox=&newMbox=0&flag=",
    [2] = "actionID=101&targetMbox=&newMbox=0&flag=",
  },
  -- The piece of post data you must append to delete to choose the messages to delete
  delete_next = "&indices%%5B%%5D=%d",

  -- The uri to remove permanently messages marked for delete
  purge_trash = {
    [1] = "%s%s/mailbox.php?thismailbox=mail%%2Ftrash&actionID=empty_mailbox&return_url=%%2Fhorde%%2Fimp%%2Fmailbox.php%%3Fmailbox%%3DINBOX",
    [2] = "%s%s/mailbox.php?thismailbox=INBOX.trash&actionID=159&return_url=%%2Fhorde%%2Fimp%%2Fmailbox.php%%3Fmailbox%%3DINBOX",
  },
  purge_deleted = {
    [1] = "%s%s/mailbox.php?actionID=expunge_mailbox",
    [2] = "%s%s/mailbox.php?actionID=160",
  },
  purge_typeC = {
    [1] = "<a href=\".-/mailbox.php%?page=%d+&amp;actionID=(expunge_mailbox)",
    [2] = "<a.-href=\"mailbox.php%?actionID=(160)",
  },
}

-- ************************************************************************** --
--  State
-- ************************************************************************** --

-- this is the internal state of the plugin. This structure will be serialized 
-- and saved to remember the state.
internal_state = {}

-- ************************************************************************** --
--  Helpers functions
-- ************************************************************************** --

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
  return (internal_state.username or "").."#"..
--    (internal_state.name or "")..
--    (internal_state.domain or "")..
    (internal_state.password or "")
end

--------------------------------------------------------------------------------
-- Login to the website
--

function browser_config(b)
  b:verbose_mode()
  if string.sub(internal_state.webmail,1,5) == "https" then
    -- Enable SSL
    b:ssl_init_stuff()
    if internal_state.ignorecert then
      b.curl:setopt(curl.OPT_SSL_VERIFYHOST,0)
    end
  --  b.curl:setopt(curl.OPT_FOLLOWLOCATION,1)
    b.curl:setopt(curl.OPT_VERBOSE,3)
  end
end

function trueorfalse(s)
  return string.find(string.sub((s or "n"),1,1),"^[yYsS1]")
end

function getfields(s)
  local t={}
  local n, k, v, r, q, z
  _,_,n,r = string.find(s,"^.-<%s*(%w+)%s*(.-)%s*/?>.*$")
  if n == nil then
    return nil
  end
  t["TAG"] = string.upper(n)
  r = r.." "
  while (r or "") ~= "" do
    z = r
    _,_,k,v,r = string.find(z,"^%s*(%w+)%s*(=%s*[%S]+%s)(.*)$")
    if k == nil then
      _,_,k,_,r = string.find(z,"^(%w+)(%s+)(.*)$")
      v = nil
    end
    if k ~= nil then
      if v ~= nil then
        _,_,v = string.find(v,"^=%s*(.*)$")
        if string.find(v,"^[\"']") then
          q = string.sub(v,1,1)
          _,_,v,r = string.find(v..r,q.."(.-)"..q.."%s*(.*)$")
        else
          _,_,v = string.find(v,"^(.*)%s+$")
        end
      end
      t[string.upper(k)] = v or ""
    end
  end
  return t
end

function traza_cookies(mensaje)
  if debug then
  	print("CookieSet ("..(mensaje or "")..") : <"..internal_state.b:serialize("internal_state.b")..">\n")
	  io.flush()
	end
end

function imp_login()
  if internal_state.login_done then
    return POPSERVER_ERR_OK
  end
  internal_state.imp_type = 1
if debug then
log.say("IGNORECERT:<"..((freepops.MODULE_ARGS or {}).ignorecert or "nada")..">\n")
end
  internal_state.ignorecert = trueorfalse((freepops.MODULE_ARGS or {}).ignorecert) or
                              trueorfalse((freepops.MODULE_ARGS or {}).i)
if debug then
log.say("PURGE:<"..((freepops.MODULE_ARGS or {}).purge or (freepops.MODULE_ARGS or {}).p or "nada")..">\n")
end
  internal_state.purge = trueorfalse((freepops.MODULE_ARGS or {}).purge) or
                         trueorfalse((freepops.MODULE_ARGS or {}).p)
  internal_state.webmail = ((freepops.MODULE_ARGS or {}).webmail or
                           (freepops.MODULE_ARGS or {}).w or
                           (imp_domain[internal_state.domain] or {}).webmail or "")
  internal_state.server = ((freepops.MODULE_ARGS or {}).server or
                           (freepops.MODULE_ARGS or {}).s or
                           (imp_domain[internal_state.domain] or {}).server or "")
  internal_state.email = (trueorfalse((freepops.MODULE_ARGS or {}).email or
                           (freepops.MODULE_ARGS or {}).e or
                           (imp_domain[internal_state.domain] or {}).email or "") and
                           ("@"..internal_state.domain) or "")
  internal_state.path = ((freepops.MODULE_ARGS or {}).path or
                           (freepops.MODULE_ARGS or {}).z or
                           (imp_domain[internal_state.domain] or {}).path or
                           imp_string.partial_path)

  if string.find(internal_state.webmail,"^https?://[^/]+$") ~= 1 then
    log.error_print("Webmail server address and protocol required to login.\n")
    return POPSERVER_ERR_AUTH
  end

if debug then
  log.error_print("Parametros recibidos:"..serial.serialize("MODULE_ARGS",freepops.MODULE_ARGS).."<- wow!\n")
    log.error_print("Browser listo para ser inicializado\n")
end
  -- the browser must be preserved
  internal_state.b = browser.new()
  local b = internal_state.b
  browser_config(internal_state.b)
if debug then
    log.error_print("Browser inicializado\n")
  log.error_print(serial.serialize("internal_state",internal_state).."\n")
end

  local page
  local err
  local check
  local home = string.format(imp_string.home,internal_state.webmail,internal_state.path)
traza_cookies("antes")
  -- Retrieve the login page and set cookies
  page,err = b:get_uri(home)
traza_cookies("home")
if debug then
    log.error_print("Estamos (home) en <"..(b:whathaveweread() or "LIMBO")..">\n")
end
  if page == nil then
    log.error_print("Can't connect to webmail.\n")
    return POPSERVER_ERR_AUTH
  end

  _,_,internal_state.webmail = string.find(b:whathaveweread(),"^(https?://[^/]+)")
if debug then
    log.error_print("Seguimos (home) en <"..(internal_state.webmail or "LIMBO").."> ???\n")
end

  local _,_,form = string.find(page,imp_string.login_formC)
  if form == nil then
    log.error_print("Can't get login form.\n")
    return POPSERVER_ERR_AUTH
  end
  
  -- Parse the login form to get localized hidden fields
  local f,tag,name,value
  local args = ""
  local passname = "password"
  repeat
    _,_,tag,form = string.find(form,imp_string.form_inputC)
    if tag ~= nil then
      f = getfields(tag)
      if string.upper(f.TYPE) == "HIDDEN" then
        name = f.NAME
        value = f.VALUE
        if (f.NAME == "load_frameset") then
          value = "0"
        end
        args = args .. "&" .. curl.escape(name) .. "=" .. curl.escape(value)
        if (f.NAME == "actionID") and (f.VALUE == "105") then
          -- Older version of IMP detected!!!
          internal_state.imp_type = 2
          log.say("Older version if IMP detected!\n")
        end
      elseif string.upper(f.TYPE) == "PASSWORD" then
        passname = f.NAME
      end
    end
  until tag == nil

  if internal_state.server ~= "" then
    local n
    args,n = string.gsub(args,"server=[^&]*","server="..curl.escape(internal_state.server))
    if n == 0 then
      args = args.."&server="..curl.escape(internal_state.server)
    end
  end

  -- Login
  local login = string.format(imp_string.login,internal_state.webmail,internal_state.path)
  local login_post = string.format(imp_string.login_post,
    curl.escape(internal_state.name..(internal_state.email or "")),
    curl.escape(passname),curl.escape(internal_state.password),args)
  login_post = string.gsub(login_post,"%%2E",".")
  page,err = b:post_uri(login,login_post)

traza_cookies("login")
if debug then
    print("---2---\n"..(page or "NADA").."\n"..(err or "OK").."\n---(2)---\n")
    log.error_print("Estamos (login) en <"..(b:whathaveweread() or "LIMBO")..">\n")
end
  if page == nil then
    log.error_print("Login POST failed.\n")
    return POPSERVER_ERR_AUTH
  end

  -- Check for mail maintenance to skip this month
  local maint = string.format(imp_string.maint[internal_state.imp_type],internal_state.webmail,internal_state.path)
  local maint_post = string.format(imp_string.maint_post[internal_state.imp_type])
  _,_,check = string.find(page,imp_string.maintC[internal_state.imp_type])
  if check ~= nil then
    page,err = b:post_uri(maint,maint_post)
traza_cookies("maint")
if debug then
    log.error_print("Estamos (maint) en <"..(b:whathaveweread() or "LIMBO")..">\n")
end
    if page == nil then
      log.error_print("Maintenance POST failed.\n")
      return POPSERVER_ERR_AUTH
    end
  end

  _,_,check = string.find(page,imp_string.loginC)
  if check == nil then
  _,_,check = string.find(page,imp_string.loginframeC) -- FRAMES!!!!!
  if check ~= nil then
    log.error_print("Cannot login. Bad username or password.\n")
    return POPSERVER_ERR_AUTH
  end
  end

  -- Check for the deleted mail purge method, if selected
  if internal_state.purge then
    local _,_,ptype = string.find(page,imp_string.purge_typeC[internal_state.imp_type])
    if ptype == nil then
      internal_state.purge_type = "trash"
if debug then
      log.say("PURGE:  tipo TRASH\n")
end
    else
      internal_state.purge_type = "deleted"
if debug then
      log.say("PURGE:  tipo DELETED\n")
end
    end
  else
    internal_state.purge_type = nil
  end

  -- save all the computed data
  internal_state.login_done = true
  
  -- log the creation of a session
  log.say("Session started for " .. internal_state.name .. "@" .. 
    internal_state.domain .. "\n")

  return POPSERVER_ERR_OK
end

-- ************************************************************************** --
--  imp functions
-- ************************************************************************** --

-- Must save the mailbox name
function user(pstate,username)
  
  internal_state.username = username

  -- extract and check domain
  local domain = freepops.get_domain(username)
  local name = freepops.get_name(username)

  -- save domain and name
--  internal_state.domain = (domain ~= "imp.lua") and domain or
  internal_state.domain = (domain ~= "imp") and domain or
    (freepops.MODULE_ARGS or {}).domain or
    (freepops.MODULE_ARGS or {}).d or ""
  internal_state.name = name

  return POPSERVER_ERR_OK
end

-- -------------------------------------------------------------------------- --
-- Must login
function pass(pstate,password)
  -- save the password
  internal_state.password = password

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
      return imp_login()
    end
if debug then
print("---loadstring---\n"..(s or "NADA").."\n---(loadstring)---\n")
end
    
    -- exec the code loaded from the session string
    c()
    browser_config(internal_state.b)

    log.say("Session loaded for " .. internal_state.name .. "@" .. 
      internal_state.domain .. "\n")
    
    return POPSERVER_ERR_OK
  else
    -- call the login procedure 
    return imp_login()
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
  local uri = string.format(imp_string.delete,internal_state.webmail,imp_string.partial_path)
  local post = string.format(imp_string.delete_post[internal_state.imp_type])

  -- here we need the stat, we build the uri and we check if we 
  -- need to delete something
  local delete_something = false;
  
  for i=1,get_popstate_nummesg(pstate) do
    if get_mailmessage_flag(pstate,i,MAILMESSAGE_DELETE) then
      post = post .. string.format(imp_string.delete_next,
        get_mailmessage_uidl(pstate,i))
      delete_something = true  
    end
  end

  if delete_something then
    -- Build the functions for do_until
    local extract_f = function(s) return true,nil end
    local check_f = support.check_fail
    local retrive_f = support.retry_n(3,support.do_post(b,uri,post))

    if not support.do_until(retrive_f,check_f,extract_f) then
      log.error_print("Unable to delete messages\n")
      return POPSERVER_ERR_UNKNOWN
    end
    
    if internal_state.purge then
      if internal_state.purge_type == "trash" then
        uri = string.format(imp_string.purge_trash[internal_state.imp_type],internal_state.webmail,imp_string.partial_path)
      else
        uri = string.format(imp_string.purge_deleted[internal_state.imp_type],internal_state.webmail,imp_string.partial_path)
      end
      retrive_f = support.retry_n(3,support.do_retrive(b,uri))
      if not support.do_until(retrive_f,check_f,extract_f) then
        log.error_print("Unable to purge messages\n")
        return POPSERVER_ERR_UNKNOWN
      end
traza_cookies("purge")
    end
  end

  -- save fails if it is already saved
  session.save(key(),serialize_state(),session.OVERWRITE)
  -- unlock is useless if it have just been saved, but if we save 
  -- without overwriting the session must be unlocked manually 
  -- since it would fail instead overwriting
  session.unlock(key())

  log.say("Session saved for " .. internal_state.name .. "@" .. 
    internal_state.domain .. "\n")

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
  local uri = string.format(imp_string.first,internal_state.webmail,imp_string.partial_path)
  
  -- The action for do_until
  --
  -- uses mlex to extract all the messages uidl and size
  local function action_f (s) 
    -- remove images from page s
    s = string.gsub(s,"<img [^>]+>","")
    -- remove bold and italic tags (strike tags preserved not to match deleted messages)
    s = string.gsub(s,"</?[bi]>","")
    -- calls match on the page s, with the mlexpressions
    -- statE and statG
    local x = mlex.match(s,imp_string.statE[internal_state.imp_type],imp_string.statG[internal_state.imp_type])
if debug then
    print("---PAGINA-S---\n"..s.."\n---(PAGINA-S)---\n")
    x:print()
    print("---(printX)---\n")
end

    -- the number of results
    local n = x:count()

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
      local fsize = x:get (1,i-1)
      fsize = string.gsub(fsize,"[,\.]","")
      local size
      local k

      -- arrange message size
      _,_,uidl = string.find(uidl,'value="([%d]+)"')
      _,_,size,k = string.find(fsize,"(%d+)%s*([Kk]?[Bb]?)")

      if not uidl or not size then
        return nil,"Unable to parse page"
      end

      -- arrange size
      size = math.max(tonumber(size),2)
      if k ~= nil then
        size = size * 1024
      end

      -- set it
      set_mailmessage_size(pstate,i+nmesg_old,size)
      set_mailmessage_uidl(pstate,i+nmesg_old,uidl)
    end
    return true,nil
  end 

  -- check must control if we are not in the last page and 
  -- eventually change uri to tell retrive_f the next page to retrive
  local function check_f (s) 
    local _,_,nex = string.find(s,imp_string.nextC)
    if nex ~= nil then
      uri = string.format(imp_string.next,internal_state.webmail,imp_string.partial_path,nex)
      -- continue the loop
      return false
    else
      return true
    end
  end

  -- this is simple and uri-dependent
  local function retrive_f ()  
    local f,err = b:get_uri(uri)
traza_cookies("stat")
    if f == nil then
      return f,err
    end

    if f == "" or string.find(f,imp_string.session_errorC) then
      internal_state.login_done = nil
      session.remove(key())

      local rc = imp_login()
      if rc ~= POPSERVER_ERR_OK then
        return nil,"Session ended,unable to recover"
      end
      
      b = internal_state.b
      -- popserver has not changed
      
      uri = string.format(imp_string.first,internal_state.webmail,imp_string.partial_path)    
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
function retr(pstate,msg,data)
  -- we need the stat
  local st = stat(pstate)
  if st ~= POPSERVER_ERR_OK then return st end
  
  -- the callback
  local cb = common.retr_cb(data)
  
  -- some local stuff
  local b = internal_state.b
  
  -- build the uri
  local uidl = get_mailmessage_uidl(pstate,msg)
  local uri = string.format(imp_string.save[internal_state.imp_type],internal_state.webmail,imp_string.partial_path,uidl)
  
  -- tell the browser to pipe the uri using cb
  local f,rc = b:pipe_uri(uri,cb)

  if not f then
    log.error_print("Asking for "..uri.."\n")
    log.error_print(rc.."\n")
    -- don't remember if this should be done
    --session.remove(key())
    return POPSERVER_ERR_NETWORK
  end

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
  local webmail = internal_state.webmail
  local b = internal_state.b
  local size = get_mailmessage_size(pstate,msg)

  -- build the uri
  local uidl = get_mailmessage_uidl(pstate,msg)
  local uri = string.format(imp_string.save[internal_state.imp_type],webmail,imp_string.partial_path,uidl)

  return common_top(b,uri,key(),size,lines,data,false)
end

-- common_top is the same code than common.top, except that changed some contants.
function common_top(b,uri,key,tot_bytes,lines,data,truncate)
  -- build the callbacks --
  
  -- this data structure is shared between callbacks
  local global = {
    -- the current amount of lines to go!
    lines = lines, 
    -- the original amount of lines requested
    lines_requested = lines, 
    -- how many bytes we have received
    bytes = 0,
    total_bytes = tot_bytes,
    -- the stringhack (must survive the callback, since the 
    -- callback doesn't know when it must be destroyed)
    a = stringhack.new(),
    -- the first byte
    from = 0,
    -- the last byte
    to = 0,
    -- the minimum amount of bytes we receive 
    -- (compensates the mail header usually)
    base = 4096,
  }
  -- the callback for http stram
  local cb = common.top_cb(global,data,truncate)
  -- retrive must retrive from-to bytes, stores from and to in globals.
  local retrive_f = function()
    global.to = global.base + global.from + (global.lines + 10) * 80 - 1
    global.base = 0
    local extra_header = {
      "Range: bytes="..global.from.."-"..global.to
    }
    local f,err = b:pipe_uri(uri,cb,extra_header)
traza_cookies("common_top")
    global.from = global.to + 1
    --if f == nil --and rc.error == "EOF" 
    --  then
    --  return "",nil
    --end
    return f,err
  end
  -- global.lines = -1 means we are done!
  local check_f = function(_)
    return global.lines < 0 or global.bytes >= global.total_bytes
  end
  -- nothing to do
  local action_f = function(_)
    return true
  end

  -- go! 
  if not support.do_until(retrive_f,check_f,action_f) and 
     not truncate then
    log.error_print("Top failed\n")
    -- don't remember if this should be done
    --session.remove(key())
    return POPSERVER_ERR_UNKNOWN
  end

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
  freepops.need_ssl()
  
--  -- the MIME mail generator module
--  require("mimer")

  -- the common implementation module
  require("common")
  
  -- checks on globals
  freepops.set_sanity_checks()

  return POPSERVER_ERR_OK

end

-- EOF
-- ************************************************************************** --
