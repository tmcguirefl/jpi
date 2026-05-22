NB. Extension system
NB. extensions.ijs
NB.
NB. Extensions are .ijs files in the plugins/ directory.
NB. Each extension can:
NB.   - Register custom tools (for LLM to call)
NB.   - Register custom commands (for /command in TUI)
NB.   - Register hooks (session_start, before_tool, after_tool)
NB.
NB. Extension API:
NB.   ext_register_tool 'name';'description';'params_json';verb
NB.   ext_register_command 'name';verb
NB.   ext_register_hook 'event';verb

NB. ================================================================
NB. Extension registries

NB. Custom tools: boxed list of (name;description;params;verb)
EXT_TOOLS =: 0 $ <''

NB. Custom commands: 2-column table (name;verb)
EXT_COMMANDS =: 0 2 $ <''

NB. Hooks: 2-column table (event;verb)
EXT_HOOKS =: 0 2 $ <''

NB. ================================================================
NB. Registration verbs

NB. Register a custom tool the LLM can call
NB. y = name;description;params_json;verbname  (verbname is a string)
ext_register_tool =: monad define
  EXT_TOOLS =: EXT_TOOLS , < y
  echo 'Extension tool registered: ' , > 0 { y
)

NB. Register a custom /command
NB. y = name;verbname  (verbname is a string, looked up at call time)
ext_register_command =: monad define
  EXT_COMMANDS =: EXT_COMMANDS , _2 ]\ y
  echo 'Extension command registered: /' , > 0 { y
)

NB. Register a hook
NB. y = event;verb  (events: session_start, before_tool, after_tool)
ext_register_hook =: monad define
  EXT_HOOKS =: EXT_HOOKS , _2 ]\ y
  echo 'Extension hook registered: ' , > 0 { y
)

NB. ================================================================
NB. Run hooks for a given event
NB. y = event name string
run_hooks =: monad define
  if. 0 = {. $ EXT_HOOKS do. return. end.
  idx =. I. ({."1 EXT_HOOKS) = < y
  for_i. idx do.
    v =. > (<i,1) { EXT_HOOKS
    v ''
  end.
)

NB. ================================================================
NB. Execute a custom tool by name
NB. y = name ; args (parsed JSON)
ext_exec_tool =: monad define
  'name args' =. y
  found =. 0
  for_t. EXT_TOOLS do.
    't_name t_desc t_params t_vname' =. > t
    if. name -: t_name do.
      found =. 1
      NB. look up verb by name string and invoke it
      (t_vname~) args
      return.
    end.
  end.
  if. -. found do. 'ERROR: unknown extension tool: ' , name end.
)

NB. ================================================================
NB. Execute a custom command by name
NB. x = command name, y = arguments string
ext_exec_command =: dyad define
  if. 0 = {. $ EXT_COMMANDS do. 0 return. end.
  idx =. ({."1 EXT_COMMANDS) i. < x
  if. idx >: {. $ EXT_COMMANDS do. 0 return. end.
  vname =. > (<idx,1) { EXT_COMMANDS
  NB. look up verb by name string and invoke it
  (vname~) y
  1
)

NB. Check if a command name is a registered extension command
is_ext_command =: monad define
  if. 0 = {. $ EXT_COMMANDS do. 0 return. end.
  (<y) e. {."1 EXT_COMMANDS
)

NB. ================================================================
NB. Build tool JSON for extension tools (for LLM payload)
get_ext_tools_json =: monad define
  if. 0 = #EXT_TOOLS do. '' return. end.
  r =. ''
  for_t. EXT_TOOLS do.
    'name desc params verb' =. > t
    select. PROVIDER
    case. 'openrouter' do.
      tool_json =. '{"name":"' , name , '","description":"' , desc , '","parameters":' , params , '}'
      r =. r , ',{"type":"function","function":' , tool_json , '}'
    case. 'google' do.
      tool_json =. '{"name":"' , name , '","description":"' , desc , '","parameters":' , params , '}'
      r =. r , ',{"type":"function","function":' , tool_json , '}'
    case. 'local' do.
      tool_json =. '{"name":"' , name , '","description":"' , desc , '","parameters":' , params , '}'
      r =. r , ',{"type":"function","function":' , tool_json , '}'
    case. 'ollama' do.
      tool_json =. '{"name":"' , name , '","description":"' , desc , '","parameters":' , params , '}'
      r =. r , ',{"type":"function","function":' , tool_json , '}'
    case. 'anthropic' do.
      r =. r , ',{"name":"' , name , '","description":"' , desc , '","input_schema":' , params , '}'
    end.
  end.
  r
)

NB. ================================================================
NB. Load all extensions from plugins/ directory
load_extensions =: monad define
  plugins_dir =. '../plugins'
  if. -. fexist plugins_dir do. return. end.
  try.
    files =. 2!:0 'ls ' , plugins_dir , '/*.ijs 2>/dev/null'
    if. 0 = #files do. return. end.
    flist =. <;._2 files , LF -. {: files
    for_f. flist do.
      fn =. > f
      echo 'Loading extension: ' , fn
      try.
        0!:0 < fn
      catch.
        echo 'ERROR loading extension: ' , fn , ' - ' , 13!:12 ''
      end.
    end.
  catch. end.
)

echo 'extensions loaded.'
