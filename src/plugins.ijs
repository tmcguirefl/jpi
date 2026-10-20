NB. Plugin discovery — Agent Plugins v1.0.0 standard
NB. plugins.ijs
NB.
NB. Discovers and validates Agent Plugin packages (directories with plugin.json).
NB. Each plugin may contain:
NB.   - skills/    : Agent Skills (delegated to skills.ijs via discover_skills_in)
NB.   - mcp.json   : MCP server config (Phase 1 — not yet implemented)
NB.   - com.jpi/   : jpi-specific .ijs extensions (future)
NB.
NB. Spec: https://agent-plugins.org/specification
NB.
NB. Plugin discovery locations:
NB.   ./plugins/            — project-local (existing directory)
NB.   ~/.jpi/plugins/      — user-global
NB.   $JPI_SRC/plugins/    — built-in (shipped with jpi)

require 'files'
require 'utils.ijs'

NB. skills.ijs is loaded by agent.ijs before plugins.ijs
NB. We depend on: discover_skills_in, SKILLS

NB. Canonical schema identifier for Agent Plugins 1.0.0
AP_SCHEMA =: 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'

NB. Global registry of loaded plugins
NB. Each entry: name ; version ; path (plugin root directory)
PLUGINS =: 0 3 $ <''

NB. ================================================================
NB. Validate plugin.json manifest
NB. y = parsed JSON object (from dec_json)
NB. Returns: name (string) if valid, '' if invalid
validate_manifest =: monad define
  NB. Check $schema is present and matches
  schema =. '$schema' gethash_json y
  if. schema -: _1 do. '' return. end.
  if. _1 = 3!:0 schema do. '' return. end.  NB. not a string
  if. -. (> schema) -: AP_SCHEMA do. '' return. end.
  NB. Check name is present
  name =. 'name' gethash_json y
  if. name -: _1 do. '' return. end.
  if. _1 = 3!:0 name do. '' return. end.  NB. not a string
  if. 0 = # > name do. '' return. end.
  > name
)

NB. ================================================================
NB. Load a single plugin from a directory path
NB. y = absolute path to plugin root
NB. Returns: 1 if loaded, 0 if rejected
load_plugin =: monad define
  manifest_path =. y , '/plugin.json'
  if. -. fexist manifest_path do. 0 return. end.
  raw =. fread manifest_path
  if. 0 = #raw do. 0 return. end.
  NB. Parse JSON
  try.
    parsed =. dec_json raw
  catch.
    echo 'PLUGINS: invalid JSON in ' , manifest_path
    0 return.
  end.
  NB. Validate manifest
  name =. validate_manifest parsed
  if. 0 = #name do.
    echo 'PLUGINS: invalid manifest in ' , manifest_path
    0 return.
  end.
  NB. Extract version (optional)
  version =. ''
  vv =. 'version' gethash_json parsed
  if. (vv -.@-: _1) *. (0 = 3!:0 > vv) do. version =. > vv end.
  NB. Register plugin
  PLUGINS =: PLUGINS , name ; version ; y
  echo 'PLUGINS: loaded plugin "' , name , '" from ' , y
  NB. Skills are scanned once by discover_all_skills, after every
  NB. plugin is registered. Scanning here as well duplicated rows.
  NB. Load MCP servers from mcp.json if present
  load_mcp_json y ; name
  1
)

NB. ================================================================
NB. Load MCP servers from a plugin's mcp.json
NB. y = plugin_root ; plugin_name
NB. Supports stdio servers with command, args, env, cwd.
NB. Expands ${PLUGIN_ROOT} and ${PLUGIN_DATA} placeholders.
load_mcp_json =: monad define
  'plugin_root plugin_name' =. y
  mcp_path =. plugin_root , '/mcp.json'
  if. -. fexist mcp_path do. return. end.
  raw =. fread mcp_path
  if. 0 = #raw do. return. end.
  try.
    parsed =. dec_json raw
  catch.
    echo 'PLUGINS: invalid JSON in ' , mcp_path
    return.
  end.
  if. 1 = $$ parsed do. parsed =. ,parsed end.
  servers =. 'mcpServers' gethash_json parsed
  if. servers -: _1 do. return. end.
  servers =. > servers
  NB. servers is a 2-row array: row 0 = name, row 1 = config (for single server)
  NB. Or a 2-col table: col 0 = name, col 1 = config (for multiple servers)
  NB. Handle both cases
  if. 1 = {: $ servers do.
    NB. Single server: row 0 = name, row 1 = config
    srv_name =. , > 0 { servers
    srv_cfg =. > 1 { servers
    NB. dec_json returns objects as rank-3 (1 2 N): reshape to 2-by-N
    NB. so gethash_json can find keys in row 0, values in row 1.
    if. 3 = # $ srv_cfg do. srv_cfg =. (2 , {: $ srv_cfg) $ , srv_cfg end.
    if. 1 = $$ srv_cfg do. srv_cfg =. 1 ,: srv_cfg end.
    try.
      srv_type =. > 'type' gethash_json srv_cfg
    catch.
      echo 'PLUGINS: error reading MCP server config for "' , srv_name , '"'
      return.
    end.
    if. srv_type -: 'stdio' do.
      load_mcp_stdio srv_cfg ; plugin_root ; plugin_name ; srv_name
    elseif. srv_type -: 'http' do.
      load_mcp_http srv_cfg ; plugin_root ; plugin_name ; srv_name
    else.
      echo 'PLUGINS: skipping MCP server "' , srv_name , '" (unsupported type: ' , (":srv_type) , ')'
    end.
  else.
    NB. Multiple servers: 2-column table (name ; config)
    for_s. servers do.
      'srv_name srv_cfg' =. s
      srv_name =. > srv_name
      srv_cfg =. > srv_cfg
      if. 1 = $$ srv_cfg do. srv_cfg =. ,srv_cfg end.
      srv_type =. > 'type' gethash_json srv_cfg
      if. srv_type -: 'stdio' do.
        load_mcp_stdio srv_cfg ; plugin_root ; plugin_name ; srv_name
      elseif. srv_type -: 'http' do.
        load_mcp_http srv_cfg ; plugin_root ; plugin_name ; srv_name
      else.
        echo 'PLUGINS: skipping MCP server "' , srv_name , '" (unsupported type: ' , (":srv_type) , ')'
      end.
    end.
  end.
)

NB. ================================================================
NB. Load a stdio MCP server
NB. y = config ; plugin_root ; plugin_name ; server_name
NB. Expands ${PLUGIN_ROOT} and ${PLUGIN_DATA}, spawns server, initializes
load_mcp_stdio =: monad define
  'cfg plugin_root plugin_name srv_name' =. y
  NB. Get command
  command =. > 'command' gethash_json cfg
  NB. Get args (optional)
  args_raw =. 'args' gethash_json cfg
  args =. ''
  if. args_raw -.@-: _1 do.
    args_arr =. > args_raw
    if. 1 = $$ args_arr do. args_arr =. ,args_arr end.
    args =. ; (,&' ') each args_arr
  end.
  NB. Expand ${PLUGIN_ROOT} and ${PLUGIN_DATA}
  plugin_data =. (2!:5 'HOME') , '/.jpi/data/' , plugin_name
  NB. Create PLUGIN_DATA dir if it doesn't exist
  try. 2!:0 'mkdir -p ' , squote plugin_data catch. end.
  command =. expand_placeholder command ; plugin_root ; plugin_data
  args =. expand_placeholder args ; plugin_root ; plugin_data
  NB. Build the full command
  if. 0 < #args do.
    full_cmd =. command , ' ' , args
  else.
    full_cmd =. command
  end.
  NB. If command starts with ./, resolve against plugin root
  if. './' -: 2 {. command do.
    full_cmd =. plugin_root , '/' , (2 }. command) , ((' ' = {: full_cmd) # ' ') , args
  end.
  echo 'PLUGINS: spawning MCP server "' , srv_name , '": ' , full_cmd
  try.
    sid =. mcp_spawn full_cmd
    rc =. mcp_init sid
    if. rc do.
      mcp_list_tools sid
      echo 'PLUGINS: MCP server "' , srv_name , '" ready (' , (": # MCP_TOOLS) , ' tools)'
    else.
      echo 'PLUGINS: MCP server "' , srv_name , '" failed to initialize'
      mcp_shutdown sid
    end.
  catch.
    echo 'PLUGINS: failed to spawn MCP server "' , srv_name , '"'
    NB. Clean up partial state: if mcp_spawn inserted a row but mcp_init
    NB. threw, the row with live fds is still in MCP_SERVERS.
    try. if. 0 < 4!:0 <'sid' do. mcp_shutdown sid end. catch. end.
  end.
)

NB. ================================================================
NB. Load an HTTP MCP server (Streamable HTTP transport)
NB. y = config ; plugin_root ; plugin_name ; server_name
NB. Connects via mcp_http_connect, initializes, lists tools
load_mcp_http =: monad define
  'cfg plugin_root plugin_name srv_name' =. y
  url =. > 'url' gethash_json cfg
  NB. Get auth header (optional) — look for Authorization in headers object
  auth =. ''
  auth_raw =. 'headers' gethash_json cfg
  if. auth_raw -.@-: _1 do.
    NB. headers is a 2-by-N table (keys in row 0, values in row 1)
    hcfg =. > auth_raw
    if. 3 = # $ hcfg do. hcfg =. (2 , {: $ hcfg) $ , hcfg end.
    if. 1 = $$ hcfg do. hcfg =. 1 ,: hcfg end.
    hkeys =. 0 { hcfg
    hvals =. 1 { hcfg
    for_i. i. # hkeys do.
      if. (tolower > i { hkeys) -: 'authorization' do.
        auth =. > i { hvals
      end.
    end.
  end.
  echo 'PLUGINS: connecting MCP server "' , srv_name , '": ' , url
  try.
    sid =. mcp_http_connect url ; auth
    rc =. mcp_init sid
    if. rc do.
      mcp_list_tools sid
      echo 'PLUGINS: MCP server "' , srv_name , '" ready (' , (": # MCP_TOOLS) , ' tools)'
    else.
      echo 'PLUGINS: MCP server "' , srv_name , '" failed to initialize'
      mcp_shutdown sid
    end.
  catch.
    echo 'PLUGINS: failed to connect MCP server "' , srv_name , '"'
    try. if. 0 < 4!:0 <'sid' do. mcp_shutdown sid end. catch. end.
  end.
)

NB. Expand ${PLUGIN_ROOT} and ${PLUGIN_DATA} in a string
NB. y = string ; plugin_root ; plugin_data
expand_placeholder =: monad define
  's root data' =. y
  s =. s rplc '${PLUGIN_ROOT}';root
  s =. s rplc '${PLUGIN_DATA}';data
  s
)

NB. ================================================================
NB. Discover plugins from a directory containing plugin subdirectories
NB. y = directory path (e.g. './plugins', '~/.jpi/plugins')
NB. Each immediate subdirectory is checked for plugin.json
discover_plugins_in =: monad define
  if. -. fexist y do. return. end.
  try.
    entries =. 2!:0 'ls -d ' , y , '/*/ 2>/dev/null'
    if. 0 = #entries do. return. end.
    dirs =. <;._2 entries , (LF -. {: entries) # LF
    for_d. dirs do.
      dir =. > d
      NB. Remove trailing slash if present
      if. '/' = {: dir do. dir =. }: dir end.
      NB. Skip if no plugin.json
      if. -. fexist dir , '/plugin.json' do. continue. end.
      load_plugin dir
    end.
  catch.
    echo 'PLUGINS: error discovering in ' , y
  end.
)

NB. ================================================================
NB. Discover all plugins from all locations
NB. Called at load time
discover_all_plugins =: monad define
  PLUGINS =: 0 3 $ <''
  NB. Built-in plugins (shipped with jpi)
  jpi_src =. 2!:5 'JPI_SRC'
  if. (2 = 3!:0 jpi_src) *. 0 < #jpi_src do.
    discover_plugins_in jpi_src , '/plugins'
  end.
  NB. User-global plugins
  home =. 2!:5 'HOME'
  if. (2 = 3!:0 home) *. 0 < #home do.
    discover_plugins_in home , '/.jpi/plugins'
  end.
  NB. Project-local plugins — TRUST GATED (see utils.ijs). A
  NB. project's plugins/ can carry MCP servers (spawned processes)
  NB. and skills; jpi's own shipped dirs are exempt, absent dirs
  NB. never prompt.
  if. is_builtin_plugins './plugins' do.
    discover_plugins_in './plugins'
  else.
    NB. nested if.: *. does not short-circuit, and trust_gate
    NB. must not prompt for directories with nothing to load
    if. fexist './plugins' do.
      if. project_trusted '' do. discover_plugins_in './plugins' end.
    end.
  end.
  if. is_builtin_plugins '../plugins' do.
    discover_plugins_in '../plugins'
  else.
    pare =. ((1!:43 '') i: '/') {. 1!:43 ''
    if. (fexist '../plugins') *. 0 < # pare do.
      if. project_trusted '' do. discover_plugins_in '../plugins' end.
    end.
  end.
  echo 'Plugins loaded: ' , (": # PLUGINS) , ' plugin(s)'
)

NB. ================================================================
NB. List loaded plugins (for /plugins command)
list_plugins =: monad define
  if. 0 = # PLUGINS do. 'No plugins found.' return. end.
  lines =. 0 $ <''
  for_i. i. # PLUGINS do.
    name =. > (< i, 0) { PLUGINS
    version =. > (< i, 1) { PLUGINS
    path =. > (< i, 2) { PLUGINS
    if. 0 < #version do.
      lines =. lines , < (name , ' v' , version , '  [' , path , ']')
    else.
      lines =. lines , < (name , '  [' , path , ']')
    end.
  end.
  ; lines ,each <LF
)

echo 'plugins loaded.'
