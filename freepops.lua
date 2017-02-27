---
-- FreePOPs bootstrap file. This is the entrypoint for the C core.
-- This also includes some basic functions that can be used by plugins/scripts.
-- 

---
-- The global freepops module.
freepops = {}

---
-- A map between domains and plugins, see 
-- <TT>config(dot)lua</TT> for a bunch of examples.
freepops.MODULES_MAP = {}

---
-- This is a global variable that the plugins may read, see the libero plugin
-- for an example.
freepops.MODULE_ARGS = nil

---
-- List of loaded so/dll/lua libs.
-- XXX DEPRECATED XXX 
--   we use lua5.1 'require' system
--   we temporarily add a metatable to print a warning
  freepops.LOADED = {}
  local real_freepops_dot_LOADED = {}
  setmetatable(freepops.LOADED,{
  	__index = function(t,k) 
		log.error_print("method deprecated. please use 'require'"..
			" to load "..k)
		return real_freepops_dot_LOADED[k]
	end,
  	__newindex = function(t,k,v) 
		log.error_print("method deprecated. please use 'require'"..
			" to load "..k)
		real_freepops_dot_LOADED[k] = v
	end
  })

--<==========================================================================>--
-- This metatable/metamethod avoid accessing wrong fields of the tabe
fp_m = { 
	__index = function(table,k)
		if k == "MODULE_ARGS" then
			return nil
		elseif k == "ACCEPTED_ADDRESSES" then
			return {}
		elseif k == "REJECTED_ADDRESSES" then
			return {}
		else
			local err = string.format(
				"Unable to access to 'freepops.%s'\n",k)
			error(err) 
		end 
	end
}

setmetatable(freepops,fp_m)

--<==========================================================================>--
-- Local functions

local __dofile = dofile
local __loadlib = loadlib
local __loadfile = loadfile

-- Config file loading.
local function load_config()
	local conffile = os.getenv("FREEPOPSLUA_CONFFILE")
	local paths = { "/etc/freepops/", "./", os.getenv("FREEPOPSLUA_PATH") or "./" }
	
	local try_load = 
		function(filename) return
			function (_,p)
				local h = __loadfile(p .. filename)
				if h ~= nil then 
					h() 
					return true
				else
					return nil
				end
		end
	end
	
	if conffile == nil then
		local rc = table.foreachi(paths,try_load("config.lua"))
	
		if rc == nil then
			error("Unable to load config.lua. Path is "..
				table.concat(paths,":"))
		end
	else
		if (not string.match(conffile,"^/")) and 
		   (not string.match(conffile,"^%./")) then
			conffile = './'..conffile
		end
		if not (try_load("")(nil,conffile)) then
			error("Unable to load the specified conffile: "..conffile)
		end
	end
end

-- Required methods for a plugin.
local pop3_methods = {
	"user","pass",
	"list","list_all",
	"uidl","uidl_all",
	"stat",
	"retr","top",
	"rset","noop","dele",
	"quit","quit_update",
	"init",
}

--<==========================================================================>--
-- these are global helpers for all freepops modules

---
-- function to extract domain part of a mailaddress.
-- @param mailaddress string for example pippo@libero.it?param=value.
-- @return string The text between @ and (?|$). In our example 'libero.it'.
function freepops.get_domain(mailaddress)
	return string.match(mailaddress,"[^@]+@([^?]+).*")
end

---
-- function to extract the username part of a mailaddress.
-- @param mailaddress string for example pippo@libero.it?param=value.
-- @return string The text between ^ and @. in our example pippo.
function freepops.get_name(mailaddress)
	return string.match(mailaddress,"([^@]+)@[^?]+.*")
end

---
-- function to extract the parameters part of a mailaddress.
-- @param mailaddress string for example pippo@libero.it?par1=val1&par2=val2.
-- @return table in our example {par1=val1 ; par2=val2}.
function freepops.get_args(mailaddress)
	local ad = string.match(mailaddress,"[^@]+@[^?%s]+([?%s].*)")
	local args = {}
	local function extract_arg(s)
		local from,to = string.find(s,"=")
		if from == nil then
			return nil,nil
		else
			return string.sub(s,1,from-1),
				string.sub(s,to+1,-1)
		end
	end
	
	local function unescape(s)
		s = string.gsub(s, "+", " ")
		return string.gsub(s,"%%(%x%x)",function(n)
				return string.char(tonumber(n, 16))
			end)
	end

	if ad ~= nil then 
		ad = string.sub(ad,2,-1)
		ad = unescape(ad)
	end

	while string.len(ad or "") > 0 do
		local from,to = string.find(ad,"&")
		local param = nil
		if from ~= nil then
			param = string.sub(ad,1,to-1)
		else
			param = ad
		end
		
		local name,val = extract_arg(param)
		if name ~= nil then
			args[name] = val
		end
		
		if to ~= nil then
			ad = string.sub(ad,to+1,-1)
		else
			ad = ""
		end
	end

	return args
end

---
-- Extracts a list of supported domain from a plugin file.
-- The plugin is executed in a protected environment, 
-- no pollution but computations are done.
-- @param f string The path of the lua plugin file.
-- @return table A couple of tables, the list of domains and
-- the list of regexes.
function freepops.safe_extract_domains(f)
	local env = {}
	local meta_env = { __index = _G }

	-- the hack
	setmetatable(env,meta_env)
	local g, err = __loadfile(f)
	if g  == nil then
		log.dbg(err)
		return nil
	end
	setfenv(g,env)
	g()
	
	-- checks 
	local check_types = function(t)
		return table.foreachi(t,function(k,v)
			if type(v) ~= "string" then
				print("'"..tostring(v).."' is not a string")
				return true
			end
			if string.byte(v) ~= string.byte("@") then
				print("'"..v.."' does not start with @")
				return true
			end
		end)
	end
	
	if env.PLUGIN_DOMAINS ~= nil then
		if type(env.PLUGIN_DOMAINS) ~= "table" then return nil end
		if check_types(env.PLUGIN_DOMAINS) then return nil end
	end
	
	if env.PLUGIN_REGEXES ~= nil then
		if type(env.PLUGIN_REGEXES) ~= "table" then return nil end
		if check_types(env.PLUGIN_REGEXES) then return nil end
	end

	-- extract
	local rc, rd = {}, {}
	if env.PLUGIN_DOMAINS ~= nil then
		table.foreachi(env.PLUGIN_DOMAINS,function(_,v)
			local x = string.sub(v,2,-1)
			table.insert(rc,x)
		end)
	end
	if env.PLUGIN_REGEXES ~= nil then
		table.foreachi(env.PLUGIN_REGEXES,function(_,v)
			local x = string.sub(v,2,-1)
			table.insert(rd,x)
		end)
	end
	
	return rc,rd
end

---
-- Searches if an unofficial plugin handles this domain.
-- @param domain string The domain you want to handle.
-- @return string A couple, name and path.
function freepops.search_domain_in_unofficial(domain)
	local function is_in_table(x,t)
		if t == nil then return false end
		return table.foreachi(t,function(_,v)
			if v == x then return true end
		end) or false
	end
	local function match_regex(x,t)
		if t == nil then return false end
		return table.foreach(t,function(_,v)
			local w,_ = string.find(x,"^" .. v .. "$")
			if w ~= nil then return true end
		end)
	end	
	local name, where = nil, nil
	table.foreach(freepops.MODULES_PREFIX_UNOFFICIAL,function(_,v)
		local it = nil
		local p_dir = function() it = lfs.dir(v) end
		local rc,err = pcall(p_dir)
		if not rc then 
			log.dbg(err)
			return
		end
		for f in it do
			if string.upper(string.sub(f,-3,-1)) == "LUA" then
				local h,rex = 
					freepops.safe_extract_domains(v.."/"..f)
				if is_in_table(domain,h) then
					name, where =  v.."/"..f, "unofficial"
					return true -- stop loop
				elseif match_regex(domain,rex) then
					name, where =  
						v.."/"..f, "unofficial(regex)"
					return true -- stop loop
				end
			end
		end	
	end)

	return name, where
end

---
-- Merge 2 tables.
-- t is destroyed, and t1 wins over t.
-- @param t table The slave table.
-- @param t1 table The master table.
-- @return table the union (t1 wins over t).
function freepops.table_overwrite(t,t1)  
	t = t or {}
	t1 = t1 or {}
	table.foreach(t1, function(k,v)
		t[k] = v
		end)
	return t
end

---
-- function that maps domains to modules.
-- These are the rules that will be honored to choose the module:</BR>
-- 0th: if domain d is nil then fail</BR>
-- 1st: check if a verbatim mapping exists (freepops.MODULES_MAP[d] ~= nil)</BR>
-- 2nd: check if a plugin tagged regex matches</BR>
-- 3rd: check if the mailaddress is a plugin name</BR>
-- 4th: check if an unofficial plugin matches verbatim</BR>
-- 5th: check if an unofficial plugin tagged regex matches.
-- @param d string The domain.
-- @return found, where, name, args.
function freepops.choose_module(d)
	local found, where, name, args = false, "nowhere", nil, nil
	
	-- 0th: if domain d is nil then fail
	if d == nil then 
		found, where, name, args = true, "nowhere", nil, nil 
	end

	-- 1st: check if a verbatim mapping exists 
	if not found and freepops.MODULES_MAP[d] ~= nil then
		found, where, name, args = true, "official", 
			freepops.MODULES_MAP[d].name,
			freepops.MODULES_MAP[d].args
	end
	 
	-- 2nd: check if a plugin tagged regex matches
	if not found then
		local plugins_with_regex = {}
		table.foreach(freepops.MODULES_MAP, function (k,v)
			if v.regex then
				plugins_with_regex[k] = v
			end
		end)
		table.foreach(plugins_with_regex,function(k,v)
			local x,_ = string.find(d,"^" .. k .. "$")
			if x ~= nil then
				found, where, name, args = 
					true, "official(regex)", v.name, v.args or {}
				return true -- stop iteration
			end
		end)
	end
	
	-- 3rd: check if the mailaddress is a plugin name
	if not found then 
		local x = string.match(d,"^(%w+%.lua)$")
		if x ~= nil then
			-- to allow "inline" modules to be in the UNOFFICIAL dir
			local u_pref = freepops.MODULES_PREFIX_UNOFFICIAL
			local path = freepops.find(x) or freepops.find(x,u_pref)
			found, where, name, args = 
				true, "inline", path, {}
		end
	end	
	-- 4th: check if an unofficial plugin matches verbatim
	-- 5th: check if an unofficial plugin tagged regex matches
	if not found then
		local unoff, wh = freepops.search_domain_in_unofficial(d)
		if unoff ~= nil then
			log.dbg("Using unofficial '"..unoff.."'")
			found, where, name, args = true, wh, unoff, {}
		end
	end

	return name, args, where 
end

---
-- Searches a file in $CWD + prefixes and returns the full path or nil.
-- XXX $CWD should be removed, what happens if $CWD is writable by all? XXX
-- @param file string The ifle name.
-- @return string The full path or nil, then the package.path entry, then 
--         the namespace if any ("a.b.lua" -> ".../a.lua", ".../?.lua", "a" .
function freepops.find(file)
	local name = string.gsub(file,"%.lua$","")
	name = string.gsub(name,"%.","/")
	local namespace = string.match(name,"^([^/]*)/") or ""
	local try = function(path)
		local file = string.gsub(path,'?',name)
		local f,_ = io.open(file,"r")
		if f ~= nil then
			io.close(f)
			return file
		end
	end
	local function fix_namespace(path, namespace)
		local _,n = string.gsub(path,'?','?')
		for i = 2,n do
			namespace = name ..'/'..namespace
		end
		return namespace
	end

	local rc = try('?.lua')
	if rc ~= nil then return rc, '?.lua', fix_namespace('?.lua',namespace) end
	for p in string.gmatch(package.path, "([^;][^;]*);") do
		rc = try(p)
		if rc ~= nil then return rc, p, fix_namespace(p,namespace) end
	end
end

---
-- As the standard LUA dofile but with MODULES_PREFIX path.
-- @return number 0 if OK, nil if not.
function freepops.dofile(file)
	local got = freepops.find(file)
	if got == nil then
		log.error_print(string.format("Unable to find '%s'\n",file))
		log.error_print(string.format("Path is '%s'\n",package.path))
		return nil
	else
		__dofile(got)
		return 0
	end
end

---
-- As the standard LUA loadlib but with MODULES_PREFIX path.
-- Load a shared library (or even a .lua file).
-- Checks if the file has been already loaded.
-- Should be preferred to freepops.dofile().
-- @param file string The object name.
-- @param fname string The function to call (nil in case the object is a lua).
-- @return function The result of a LUA loadfile or nil.
function freepops.loadlib(file,fname)
	-- check if already loaded
	if freepops.LOADED[file] ~= nil then
		return function() end 
	end
	
	local got = freepops.find(file)
	
	-- check result
	if got == nil then
		log.error_print(string.format("Unable to load '%s'\n",file))
		log.error_print(string.format("Path is '%s'\n",
			table.concat(freepops.MODULES_PREFIX,":")))
		return nil
	else
		local x,_ = string.find(file, "%.lua$")
		local g, err = nil, nil
		
		if x ~= nil then
			-- we are loading a .lua file
			g, err = __loadfile(got)
		else
			g, err = __loadlib(got, fname)
		end
		if not g then
			log.error_print(got..": "..err.."\n")
			return nil
		else
			freepops.LOADED[file] = true
			return g
		end
	end
end

---
-- uses freepops' dofile instead of the standard one.
dofile = function(f) 
	return (pcall(function() require(f) end) or freepops.dofile(f)) 
end

---
-- Load needed module for handling domain.
function freepops.load_module_for(mailaddress,loadonly)
	-- helpers
	local function err_format(dom,mail) 
		return string.format(
			"Unable to find a module that handles '%s' domain,"..
			" requested by '%s' mail account\n",dom,mail)
	end
	local function err_rtfm()
		return [[
		
	*************************************************************
	*                      LEGGIMI                              *
	*                                                           * 
	* Sembra che tu abbia usato uno username privo della        *
	* parte @qualcosa. FreePOPs ha bisogno di username con      *
	* un dominio. Se eri un utente LiberoPOPs puoi leggere      *
	*                                                           *
	*   http://www.freepops.org/it/lp_to_fp.shtml       *
	*                                                           *
	* che spiega cosa devi esattamente fare. Per favore non     *
	* mettere richieste di aiuto sul forum se non hai           *
	* semplicemente messo il dominio nello username             *
	*                                                           *
	*************************************************************
]],[[
	
	*************************************************************
	*                      README                               *
	*                                                           *
	* FreePOPs needs a username with the domain part. You       *
	* must use a username in the form foo@something to use      *
	* FreePOPs. Please read the manual available at             *
	*                                                           *
        *   http://www.freepops.org/en/files/manual.pdf     *
	*                                                           *
	* or the tutorial                                           *
	*                                                           *
	*   http://www.freepops.org/en/tutorial/index.shtml *
	*                                                           *
	*************************************************************
]]
	end
	
	-- preventive check
	local accept,why = freepops.match_address(mailaddress,
		freepops.ACCEPTED_ADDRESSES)

	if not accept then
		local reject,why = freepops.match_address(mailaddress,
			freepops.REJECTED_ADDRESSES)
		if reject then
			log.say("Rejecting '" .. mailaddress .. 
				"' cause matched '" .. why .."'\n")
			return nil -- ERR
		end
	else
		log.dbg("Accepting '" .. mailaddress .. 
			"' cause matched '" .. why .."'\n")
	end

	-- the stuff
	local domain = freepops.get_domain(mailaddress)
	local module,args,where = freepops.choose_module(domain)
	if module == nil then
		if domain ~= nil then
			log.error_print(err_format(domain,mailaddress))
		else
			local it,en = err_rtfm()
			log.error_print(it)
			log.error_print(en)
		end
		return nil --ERR
	else
		--print("ARGS:")
		--table.foreach(args,print)
		--print("PARSED ARGS:")
		--table.foreach(freepops.get_args(mailaddress),print)
		--print("plugin found: ",where)

		local marg = freepops.table_overwrite(args,
			freepops.get_args(mailaddress))
		
		freepops.MODULE_ARGS = marg
		if freepops.dofile(module) ~= nil then 
			return 0 -- OK
		else
			return nil -- ERR
		end
	end
	
end

---
-- Compares 2 verions in FreePOPs format.
-- This is the LUA regex to extract the components: "(%d+)%.(%d+)%.(%d+)".
-- @param version1 string A version.
-- @param version2 string A version.
-- @return boolean true if version1 >= version2.
function freepops.is_version_ge(version1, version2)
	local match = "(%d+)%.(%d+)%.(%d+)"
	local fp_x,fp_y,fp_z = string.match(version1, match)
	local p_x,p_y,p_z = string.match(version2, match)
	if fp_x == nil or fp_y == nil or fp_z == nil then
		log.error_print("Wrong FreePOPs version string format")
		return false
	end
	if p_x == nil or p_y == nil or p_z == nil then
		log.error_print("Wrong plugin REQUIRE_VERSION string format.")
		log.error_print("It must be X.Y.Z (numbers only).")
		return false
	end

	if tonumber(fp_x) > tonumber(p_x) then return true end
	if tonumber(fp_x) == tonumber(p_x) and
	   tonumber(fp_y) > tonumber(p_y) then return true end
	if tonumber(fp_x) == tonumber(p_x) and
	   tonumber(fp_y) == tonumber(p_y) and	
	   tonumber(fp_z) >= tonumber(p_z) then return true end

	return false
end

---
-- Gives back the version string of freepops
function freepops.version()
	return os.getenv("FREEPOPS_VERSION")
end

---
-- Checks if this FreePOPs version is enough for the plugin.
function freepops.enough_new(plugin_version_string)
	local fp_version_string = freepops.version()
	return freepops.is_version_ge(fp_version_string, 
						plugin_version_string)
end

---
-- Makes tab members globals.
function freepops.export(tab)
	local _export = function(name,value) 
		_G[name]=value 
	end
	table.foreach(tab,_export)
end


---
-- Checks if the plugin has declared all required methods.
-- This should be called after the plugin is loaded.
function freepops.check_global_symbols()
	for _,v in ipairs(pop3_methods) do
		if _G[v] == nil then
			log.error_print("The plugin has not declared '"..v.."'")
			return nil
		end
	end
	return true
end

---
-- Sets a metatable for _G that checks for wrong globals usage.
-- No more globals can be declared after this function is called.
function freepops.set_sanity_checks()
	-- no more globals can be declared after this (except _)
	setmetatable(_G,{
		__index = function(t,k)
			local d = debug.getinfo(2,"lSn")or debug.getinfo(1,"lS")
			local s = "\tBUG found in '".. (d.source or "nil") ..
				"' at line "..(d.currentline or "nil")..".\n"..
				"\tFunction '".. (d.name or "anonymous") .. 
				"' uses an undefined global '" ..k.. "'\n"..[[

	This is a sanity check added by freepops.set_sanity_checks() that
	prevents the plugin to access undeclared globals.
	This avoids some hard-to-detect bugs.
	]]
			log.say(s.."\n")
			error(s)
		end,
		__newindex = function(t,k,v)
			if k == "_" then rawset(_G,k,v) return end
			local d = debug.getinfo(2,"lSn")or debug.getinfo(1,"lS")
			local s = "\tBUG found in '".. (d.source or "nil") ..
				"' at line "..(d.currentline or "nil")..".\n"..
				"\tFunction '".. (d.name or "anonymous") .. 
				"' sets an undefined global '" .. k .. "'\n"..[[
				
	This is a sanity check added by freepops.set_sanity_checks() that
	prevents the plugin to create new global variables. This means you
	must use the 'local' keyword or declare a global table 
	(ex. plugin_state) and use it as the global state of the plugin. 
	This avoids some hard-to-detect bugs.
	]]
			log.say(s.."\n")
			error(s)
		end
	})
end

---
-- Checks if this version of FP is SSL enabled.
-- Must be called after loading the browser module.
function freepops.need_ssl()
	local c = browser.ssl_enabled()
	if not c then
		local s = [[

	This plugin needs a SSL-enabled version of FreePOPs. If you are a 
	windows user, please download and install the -SSL version of FreePOPs.
	If you are a unix user, this means you have to install an SSL library,
	like OpenSSL, and make libcURL aware of this (maybe you need to 
	recompile them).
	]]
	
		log.say(s.."\n")
		error(s)
	end
end

---
-- Checks if the address a is matched by the strings defined in table t.
function freepops.match_address(a,t)
	local why = ""
	local rc = table.foreach(t,function(k,v)
		-- what is this? boh...
		local capt = "^(" .. v .. ")$"
		local x = string.match(a,capt)
		if x ~= nil then 
			why = v
			return true
		end
	end)
	
	if rc then 
		return rc,why
	else
		return false,nil
	end
end


--<==========================================================================>--
-- This is the function freepops calls

-- -------------------------------------------------------------------------- --
-- freepops.dofile may be called too by the C core to execute a script that is
-- not found (and so it is searched in the standard paths)
-- -------------------------------------------------------------------------- --

-- -------------------------------------------------------------------------- --
-- This is only the LUA box bootstrap code. This is called to initialize the
-- lua box when freepops is started with -e or -x
-- -------------------------------------------------------------------------- --

---
-- Load the configuration file and the support module.
-- Is intended to be used by the C core.
function freepops.bootstrap()
	load_config()
	
	-- compat-5.1
	LUA_PATH=""
	local function path_to_compat51_path(_,path)
	        LUA_PATH=LUA_PATH .. path .. "?.lua;"
	        LUA_PATH=LUA_PATH .. path .. "?/?.lua;"
	end
	table.foreach(freepops.MODULES_PREFIX,path_to_compat51_path)
	table.foreach(freepops.MODULES_PREFIX_UNOFFICIAL,path_to_compat51_path)
	package.path=LUA_PATH..";"..package.path
	LUA_CPATH=""
	table.foreach(freepops.MODULES_CPREFIX, function(_,p)
		 LUA_CPATH=LUA_CPATH .. p .. "?.so;"
		 LUA_CPATH=LUA_CPATH .. p .. "?.dll;"
	end)
	package.cpath=LUA_CPATH..";"..package.cpath
	
	-- standard lua modules that must be loaded
	require("support")

	return 0 -- OK
end

-- -------------------------------------------------------------------------- --
--  This is the only (except the former) function called from the C code. 
--  This loads the module that handles mailaddress's domain and load standard
--  LUA modules
-- -------------------------------------------------------------------------- --

---
-- Load the configuration file and the support module and the plugin that
-- handles mailaddress.
-- Is intended to be used by the C core.
function freepops.init(mailaddress)
	freepops.bootstrap()
	
	if freepops.load_module_for(mailaddress) == nil then return 1 end
	
	-- check if the required version is older
	if not freepops.enough_new(PLUGIN_REQUIRE_VERSION) then
		log.error_print(
			"This plugin requires a newer version "..
			"of FreePOPs. Please update!")
		return 1
	end
	-- some sanity checks
	if freepops.check_global_symbols() == nil then return 1 end
	
	return 0 -- OK
end

--<==========================================================================>--
