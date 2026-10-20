NB. Agent - integrated dispatcher
NB. agent.ijs
NB. Supports both direct commands and LLM-backed mode

load 'config.ijs'
load 'log.ijs'
load 'utils.ijs'
load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'
load 'llm.ijs'
load 'jev.ijs'
load 'tool_exec.ijs'
load 'session.ijs'
load 'skills.ijs'
load 'mcp.ijs'
load 'plugins.ijs'
load 'extensions.ijs'

NB. Discover Agent Plugins and Skills after all modules are loaded.
NB. Skills are scanned once here, including plugin skills.
discover_all_plugins ''
discover_all_skills ''

NB. ----------------------------------------------------------------
NB. Model listing — fetch_models helper + list_models

NB. Fetch models from an OpenAI-compatible /v1/models endpoint.
NB. Uses curl -K config file so API keys never appear in ps aux.
NB. y = prov ; url ; envkey ; datakey ; idfield ; namefield ; disp_prefix ; id_prefix ; disp_suffix ; use_auth
NB.   namefield: if non-empty, read this field from each model for display name
NB.   disp_suffix: fixed fallback string when namefield is empty or missing
NB.   use_auth: 1 = include Bearer auth header, 0 = no auth header
NB. Returns: boxed (models_list ; ids_list)
NB. Humanize a token count for the model picker: 1048576 -> 1M,
NB. 128000 -> 128k
fmt_ctx_window =: monad define
  if. y >: 1000000 do.
    (": 0.01 * <. 100 * y % 1000000) , 'M'
  elseif. y >: 1000 do.
    (": <. y % 1000) , 'k'
  else.
    ": y
  end.
)

fetch_models =: monad define
  'prov url envkey datakey idfield namefield disp_prefix id_prefix disp_suffix use_auth' =. 10 {. y
  NB. optional 11th arg: an array field (e.g. Cohere's 'endpoints')
  NB. whose membership in 'chat' filters the listing to models jpi
  NB. can actually call (jpi speaks chat only - embed/transcribe
  NB. models would dead-end with an API error). Empty = no filter.
  chatfield =. ''
  if. 10 < # y do. chatfield =. > 10 { y end.
  ml =. 0 $ <''
  il =. 0 $ <''
  if. -. has_api_key envkey do. ((<ml) , <il) return. end.
  echo 'Fetching models from ' , prov , '...'
  try.
    hcfg =. 'header = "Content-Type: application/json"' , LF
    if. use_auth do.
      hcfg =. hcfg , 'header = "Authorization: Bearer ' , (get_api_key envkey) , '"' , LF
    end.
    hcfg fwrite HTTP_HEADERFILE
    base =. 'curl -s -K ' , HTTP_HEADERFILE
    'code res' =. base curl_run url
    if. 'ERROR:' -: 6 {. res do.
      echo 'Failed to fetch from ' , prov , ': ' , res
      ((<ml) , <il) return.
    end.
    js =. dec_json res
    err =. 'error' gethash_json js
    if. _1 -: err do.
      marr =. datakey gethash_json js
      if. marr -.@-: _1 do.
        for_m. > marr do.
          m =. > m
          NB. chat-only filter when the caller asked for it
          if. 0 < # chatfield do.
            eps =. chatfield gethash_json m
            if. (eps -.@-: _1) *. -. (< 'chat') e. > eps do. continue. end.
          end.
          idv =. idfield gethash_json m
          if. idv -.@-: _1 do.
            id =. > idv
            if. 0 < # namefield do.
              nv =. namefield gethash_json m
              if. nv -.@-: _1 do. suffix =. > nv else. suffix =. disp_suffix end.
            else.
              suffix =. disp_suffix
            end.
            NB. advertised context window when the listing has one
            NB. (mistral: max_context_length; openrouter/hyai: context_length)
            cw =. json_num 'max_context_length' gethash_json m
            if. _1 = cw do. cw =. json_num 'context_length' gethash_json m end.
            ctx =. ''
            if. 0 < cw do. ctx =. '  [' , (fmt_ctx_window cw) , ']' end.
            NB. per-model pricing when the listing has it (hyai;
            NB. mistral's listing carries NO pricing - published on
            NB. their website only). hyai prices are EUR per million.
            pr =. 'pricing' gethash_json m
            price =. ''
            if. pr -.@-: _1 do.
              pr =. > pr
              pi =. json_num 'input_per_million' gethash_json pr
              po =. json_num 'output_per_million' gethash_json pr
              if. 0 < pi do.
                price =. '  ' , (": pi) , 'EUR/M in'
                if. 0 < po do. price =. price , ' ' , (": po) , 'EUR/M out' end.
              end.
            end.
            ml =. ml , < (disp_prefix , id , '  -  ' , suffix , ctx , price)
            il =. il , < (id_prefix , id)
          end.
        end.
      end.
    end.
  catch.
    echo 'Error fetching from ' , prov , ': ' , 13!:12 ''
  end.
  NB. (<ml) , <il — always exactly 2 boxes. Dyadic ; (Link) would
  NB. append <il to ml as items when ml is a non-empty boxed list,
  NB. breaking the 'ml il' destructuring at call sites.
  (<ml) , <il
)

NB. Fetch Google models (special: x-goog-api-key header, 'models' data key,
NB. 'name'/'displayName' fields, strips 'models/' prefix from id).
NB. Returns: boxed (models_list ; ids_list)
fetch_google_models =: monad define
  ml =. 0 $ <''
  il =. 0 $ <''
  if. -. has_api_key 'GEMINI_API_KEY' do. ((<ml) , <il) return. end.
  echo 'Fetching models from Google...'
  try.
    hcfg =. 'header = "x-goog-api-key: ' , (get_api_key 'GEMINI_API_KEY') , '"' , LF
    hcfg fwrite HTTP_HEADERFILE
    base =. 'curl -s -K ' , HTTP_HEADERFILE
    'code res' =. base curl_run 'https://generativelanguage.googleapis.com/v1beta/models'
    if. 'ERROR:' -: 6 {. res do.
      echo 'Failed to fetch from Google: ' , res
      ((<ml) , <il) return.
    end.
    js =. dec_json res
    err =. 'error' gethash_json js
    if. _1 -: err do.
      marr =. 'models' gethash_json js
      if. marr -.@-: _1 do.
        for_m. > marr do.
          m =. > m
          nm =. > 'name' gethash_json m
          disp =. > 'displayName' gethash_json m
          if. 'models/' -: 7 {. nm do. nm =. 7 }. nm end.
          ml =. ml , < ('google/' , nm , '  -  ' , disp)
          il =. il , < nm
        end.
      end.
    end.
  catch.
    echo 'Error fetching from Google: ' , 13!:12 ''
  end.
  (<ml) , <il
)

NB. List available models from all configured providers.
NB. Native models are injected first, then live-fetched from each provider.
list_models =: monad define
  models_list =. 0 $ <''
  ids_list =. 0 $ <''

  NB. Inject primary native models
  models_list =. models_list , < 'google/gemini-2.5-flash  -  [Direct Google AI Studio]'
  ids_list =. ids_list , < 'gemini-2.5-flash'
  models_list =. models_list , < 'google/gemini-2.5-pro  -  [Direct Google AI Studio]'
  ids_list =. ids_list , < 'gemini-2.5-pro'
  models_list =. models_list , < 'local/llama-server  -  [Localhost 8080]'
  ids_list =. ids_list , < 'local/llama-server'
  models_list =. models_list , < 'local/ollama  -  [Localhost 11434]'
  ids_list =. ids_list , < 'local/ollama'
  models_list =. models_list , < 'xai/grok-4.7  -  [xAI]'
  ids_list =. ids_list , < 'xai/grok-4.7'

  NB. Fetch from Google (special API — key in x-goog-api-key header)
  'ml il' =. fetch_google_models ''
  models_list =. models_list , ml
  ids_list =. ids_list , il

  NB. Fetch from OpenAI-compatible providers (key via curl -K, not in args)
  'ml il' =. fetch_models 'Localhost 8080';'http://localhost:8080/v1/models';'LOCAL_API_KEY';'data';'id';'';'local/';'local/';'Local';0
  models_list =. models_list , ml
  ids_list =. ids_list , il

  'ml il' =. fetch_models 'Ollama';'http://localhost:11434/v1/models';'OLLAMA_API_KEY';'data';'id';'';'ollama/';'ollama/';'Ollama';0
  models_list =. models_list , ml
  ids_list =. ids_list , il

  'ml il' =. fetch_models 'TCM';'https://tcmcguire.servehttp.com/v1/models';'TCM_API_KEY';'data';'id';'';'tcm/';'tcm/';'TCM Hosted';0
  models_list =. models_list , ml
  ids_list =. ids_list , il

  'ml il' =. fetch_models 'HostYourAI';'https://hostyourai.com/api/v1/models';'HYAI_API_KEY';'data';'id';'';'hyai/';'hyai/';'HostYourAI';1
  models_list =. models_list , ml
  ids_list =. ids_list , il

  'ml il' =. fetch_models 'Mistral';'https://api.mistral.ai/v1/models';'MISTRAL_API_KEY';'data';'id';'';'mistral/';'mistral/';'Mistral API';1
  models_list =. models_list , ml
  ids_list =. ids_list , il

  NB. Cohere: the listing uses 'models' (not 'data') and 'name'
  NB. (not 'id'); context_length feeds the picker's ctx column.
  NB. The cohere/ prefix routes ALL listed models uniformly
  NB. (command-*, aya...); legacy command-*/north-* names keep
  NB. working unchanged.
  'ml il' =. fetch_models 'Cohere';'https://api.cohere.com/v1/models';'COHERE_API_KEY';'models';'name';'';'cohere/';'cohere/';'Cohere API';1;'endpoints'
  models_list =. models_list , ml
  ids_list =. ids_list , il

  'ml il' =. fetch_models 'xAI';'https://api.x.ai/v1/models';'XAI_API_KEY';'data';'id';'';'xai/';'xai/';'xAI';1
  models_list =. models_list , ml
  ids_list =. ids_list , il

  echo 'Fetching model list from OpenRouter...'
  'ml il' =. fetch_models 'OpenRouter';'https://openrouter.ai/api/v1/models';'OPENROUTER_API_KEY';'data';'id';'name';'openrouter/';'';'N/A';1
  models_list =. models_list , ml
  ids_list =. ids_list , il

  sort_idx =. /: models_list
  models_list =. sort_idx { models_list
  ids_list =. sort_idx { ids_list

  if. 3 = 4!:0 <'tui_filter_menu' do.
    sel_idx =. 'Select a model (type to filter)' tui_filter_menu models_list
    if. sel_idx -.@-: _1 do.
      new_model =. > sel_idx { ids_list
      MODEL =: new_model
      save_model ''
      echo 'Model dynamically routed to: ' , MODEL
    else.
      echo 'Model selection aborted.'
    end.
  elseif. 3 = 4!:0 <'tui_select_menu' do.
    sel_idx =. 'Select a model:' tui_select_menu models_list
    if. sel_idx -.@-: _1 do.
      new_model =. > sel_idx { ids_list
      MODEL =: new_model
      save_model ''
      echo 'Model dynamically routed to: ' , MODEL
    else.
      echo 'Model selection aborted.'
    end.
  else.
    echo 'Available fallback models:'
    for_v. models_list do. echo > v end.
  end.
)

NB. Load plugins at startup
load_extensions ''

NB. ----------------------------------------------------------------
NB. Direct-mode action verbs (no LLM needed)

read_verb =: monad define
  echo 'Reading: ', y
  echo read_file_auto y
)

run_verb =: monad define
  if. -. is_safe y do.
    log 'BLOCKED: ', y
    echo 'Command blocked for safety.'
    return.
  end.
  echo 'Running: ', y
  echo run_cmd_str y
)

NB. edit <file> <old> <new>  (use quotes if text has spaces)
edit_verb =: monad define
  parts =. chopstring y
  if. 3 > #parts do.
    echo 'Usage: edit <file> <oldtext> <newtext>'
    return.
  end.
  fn =. > 0 { parts
  old =. > 1 { parts
  new =. > 2 { parts
  if. edit_file fn ; old ; new do.
    echo 'Edit successful: ' , fn
  else.
    echo 'Edit failed: text not found in ' , fn
  end.
)

NB. write <file> <content...>
write_verb =: monad define
  parts =. chopstring y
  if. 2 > #parts do.
    echo 'Usage: write <file> <content>'
    return.
  end.
  fn =. > {. parts
  NB. rejoin remaining words as the content
  content =. _1 }. ; (,&' ') each }. parts
  if. write_file fn ; content do.
    echo 'Written: ' , fn
  else.
    echo 'Write failed: ' , fn
  end.
)

ask_verb =: monad define
  q =. y
  if. 3 = 4!:0 <'expand_mentions' do. q =. expand_mentions y end.
  echo 'Asking LLM...'
  log 'ask: ', q
  reply =. llm_ask q
  shown =. 0
  try. shown =. STREAM_SHOWN catch. shown =. 0 end.
  if. shown = 0 do. echo reply end.
)

NB. /help [word] - list commands grouped, one line each.
NB. Optional argument filters to matching entries (command names
NB. and descriptions). TUI-local commands (less, nvim, retry,
NB. exit) are listed too - they dispatch before the agent, but
NB. a help that omits them would mislead.
help_verb =: monad define
  flt =. deb tolower y
  for_l. help_lines '' do.
    ln =. > l
    keep =. 1
    if. 0 < # flt do.
      keep =. +./ flt E. tolower ln
    end.
    if. keep do. echo ln end.
  end.
  i. 0 0
)

NB. the help catalog: section headers and 'cmd - description'
NB. lines. One string per line, in display order.
help_lines =: monad define
  h =. 0 $ <''
  h =. h , <'conversation:'
  h =. h , <'  ask [text]       - send a prompt to the model'
  h =. h , <'  clear            - start a fresh conversation'
  h =. h , <'  compact [N|text] - summarize the oldest N messages (default half);'
  h =. h , <'                     text is extra guidance for the summary'
  h =. h , <'  retry            - recall the last prompt for editing (TUI)'
  h =. h , <'  session [name]   - switch session (no name: pick from list)'
  h =. h , <'  fork [name [id]] - branch; an id copies only through that entry'
  h =. h , <'  tree [id]        - user messages on this branch; an id checks out'
  h =. h , <'  clone [name]     - copy this branch into a new session'
  h =. h , <'  name [label]     - set the session display name'
  h =. h , <'  export / import  - save / reload the conversation (JSONL)'
  h =. h , <'  transcript [f]   - write the conversation as markdown'
  h =. h , <'model and budget:'
  h =. h , <'  model [name]     - pick a model (no name: searchable list,'
  h =. h , <'                      context windows and pricing shown)'
  h =. h , <'  context [N|auto] - view/set the context budget; N pins a'
  h =. h , <'                      number, auto adopts the model window'
  h =. h , <'  think [on|off|N] - reasoning budget configuration'
  h =. h , <'  status           - one dashboard: model, budget, session,'
  h =. h , <'                      usage, manual, plugins'
  h =. h , <'  usage            - session token/cost totals'
  h =. h , <'  prompt           - show the system prompt'
  h =. h , <'tools and files:'
  h =. h , <'  read [f]         - read a file into context'
  h =. h , <'  run [cmd]        - run a shell command (!cmd keeps the output'
  h =. h , <'                     in the conversation, !!cmd does not)'
  h =. h , <'  edit / write     - modify or create files'
  h =. h , <'  grep / find / git - project search and git helpers'
  h =. h , <'viewing:'
  h =. h , <'  less [N]         - open the last reply in the pager (TUI)'
  h =. h , <'  nvim             - compose a prompt in nvim (TUI)'
  h =. h , <'  theme            - color theme picker'
  h =. h , <'system:'
  h =. h , <'  skills / plugins - list loaded skills / plugins'
  h =. h , <'  skill:name       - run that skill as the next prompt'
  h =. h , <'  login [provider] - save an API key (input is hidden)'
  h =. h , <'  logout [provider]- remove a saved API key'
  h =. h , <'  reload           - reload skills, prompts, and the theme'
  h =. h , <'  help [word]      - this list; a word filters it'
  h =. h , <'  exit             - quit (TUI: also Ctrl+C)'
  h
)

NB. Explicit original:
NB.   clear_verb =: monad define
NB.     clear_history ''
NB. )
clear_verb =: clear_history

session_verb =: monad define
  if. 0 = #y do.
    list_sessions ''
    return.
  end.
  switch_session y
)

NB. fork [name [id]]. One word copies the active head. Two words
NB. copy only through that entry id.
fork_verb =: monad define
  parts =. chopstring y
  if. 2 = # parts do.
    (> 0 { parts) fork_at > 1 { parts
  else.
    fork_session y
  end.
)

NB. Explicit original:
NB.   export_verb =: monad define
NB.     save_session ''
NB. )
export_verb =: save_session

NB. Explicit original:
NB.   import_verb =: monad define
NB.     load_session ''
NB. )
import_verb =: load_session

model_verb =: monad define
  if. 0 = #y do.
    list_models ''
    return.
  end.
  MODEL =: y
  save_model ''
  NB. re-derive routing + budget for the new model: provider,
  NB. API_URL and the provider-default cost cap (previously NOT
  NB. updated on /model, so switching providers kept the old URL)
  update_config_state ''
  echo 'Model set to: ' , MODEL
  NB. inform, never inflate: report the advertised window
  try. report_model_window '' catch. end.
)

NB. Explicit original:
NB.   usage_verb =: monad define
NB.     show_usage ''
NB. )
usage_verb =: show_usage

NB. /status - one dashboard: everything the session depends on.
status_verb =: monad define
  echo '--- jpi status ---'
  echo 'Model:    ' , MODEL , '  (provider: ' , PROVIDER , ')'
  echo 'Context:  budget ' , (": MAX_TOKENS) , ' tokens'
  if. 0 < MODEL_WINDOW do.
    echo '          model advertises ' , (": MODEL_WINDOW) , ' (/context auto to adopt)'
  end.
  echo 'Session:  ' , CURRENT_SESSION , '  (' , (": # HISTORY) , ' messages)'
  echo 'Usage:    input ' , (": TOTAL_INPUT_TOKENS) , ' / output ' , (": TOTAL_OUTPUT_TOKENS) , ' tokens, $' , (": TOTAL_COST)
  if. 0 < # JCORE_PATH do.
    echo 'J-CORE:   ' , JCORE_PATH
  else.
    echo 'J-CORE:   not set (JPI_JCORE; manual features degrade)'
  end.
  echo 'Plugins:  ' , (": # PLUGINS) , ' plugin(s), ' , (": # MCP_SERVERS) , ' MCP server(s)'
  i. 0 0
)

NB. /transcript [file] - write the conversation as readable
NB. markdown. Default filename: jpi-transcript-<session>-<ts>.md
NB. in the current directory. Tool-call turns without text
NB. content are marked; tool results are included.
transcript_verb =: monad define
  if. 0 = # HISTORY do.
    echo 'No conversation to transcribe.'
    return.
  end.
  path =. deb y
  if. 0 = # path do.
    path =. 'jpi-transcript-' , CURRENT_SESSION , '-' , (6!:0 'YYYYMMDD-hhmm') , '.md'
  end.
  out =. 0 $ <''
  out =. out , < '# jpi transcript - session ' , CURRENT_SESSION , LF , LF
  for_m. HISTORY do.
    js =. dec_json > m
    role =. 'role' gethash_json js
    content =. 'content' gethash_json js
    if. (role -.@-: _1) *. (content -.@-: _1) do.
      out =. out , < '## ' , (> role) , LF , LF , (> content) , LF , LF
    elseif. role -.@-: _1 do.
      NB. assistant turn with tool_calls and no text content
      out =. out , < '## ' , (> role) , LF , LF , '(tool calls - see session file)' , LF , LF
    end.
  end.
  (; out) fwrite path
  echo 'Transcript written: ' , path
  i. 0 0
)

NB. /prompt - show the system prompt the model actually sees.
NB. (it varies by model config, manual presence, workspace).
prompt_verb =: monad define
  if. 3 = 4!:0 <'get_system_prompt' do.
    echo get_system_prompt ''
  else.
    echo 'system prompt not available (system_prompt.ijs not loaded)'
  end.
  i. 0 0
)

theme_verb =: monad define
  if. 0 = #y do.
    list_themes ''
    return.
  end.
  set_theme y
)

NB. View or set thinking configuration (reasoning models).
NB.   /think            show current state
NB.   /think off         disable thinking
NB.   /think on          enable, unlimited budget
NB.   /think unlimited   enable, no budget cap
NB.   /think 2000        enable with a thinking token budget
NB. State persists in ~/.jpi_think and is sent per-provider by
NB. thinking_param (llm.ijs); providers without a thinking API
NB. ignore it.
think_verb =: monad define
  if. 0 = #y do.
    if. THINK_ON do.
      echo 'Thinking: ON, budget: ' , (": THINK_BUDGET) , ' tokens (0 = unlimited)'
    else.
      echo 'Thinking: OFF'
    end.
    return.
  end.
  arg =. tolower dlb y
  if. arg -: 'off' do.
    THINK_ON =: 0
  elseif. (arg -: 'on') +. (arg -: 'unlimited') do.
    THINK_ON =: 1 [ THINK_BUDGET =: 0
  elseif. do.
    NB. ". returns an empty noun silently for non-noun do-strings.
    NB. An AND chain over an empty noun is empty, and if. on an
    NB. empty condition is TRUE — so test the item count as its own
    NB. scalar guard before touching the value.
    n =. ". arg
    if. 1 ~: #n do.
      echo 'Usage: /think [on|off|unlimited|<budget tokens>]'
      return.
    end.
    if. ((3!:0 n) e. 4 8) *. (n = <. n) *. (n > 0) do.
      THINK_ON =: 1
      THINK_BUDGET =: n
    else.
      echo 'Usage: /think [on|off|unlimited|<budget tokens>]'
      return.
    end.
  end.
  save_think ''
  if. THINK_ON do.
    echo 'Thinking: ON, budget: ' , (": THINK_BUDGET) , ' tokens (0 = unlimited)'
  else.
    echo 'Thinking: OFF'
  end.
)

git_verb =: monad define
  if. 0 = #y do.
    NB. show git summary
    if. -. is_git_repo '' do. echo 'Not a git repo.' return. end.
    echo 'Branch: ' , git_branch ''
    echo git_status ''
  else.
    NB. Quote each word, and run the same blocklist as bash.
    if. -. is_safe y do.
      log 'BLOCKED: ', y
      echo 'Command blocked for safety.'
      return.
    end.
    echo run_cmd_str 'git ' , quote_words y
  end.
)

grep_verb =: monad define
  if. -. is_safe y do.
    log 'BLOCKED: ', y
    echo 'Command blocked for safety.'
    return.
  end.
  echo run_cmd_str 'grep -rn ' , quote_words y
)

find_verb =: monad define
  if. -. is_safe y do.
    log 'BLOCKED: ', y
    echo 'Command blocked for safety.'
    return.
  end.
  echo run_cmd_str 'find ' , quote_words y
)

compact_verb =: monad define
  arg =. deb y
  note =. ''
  if. 0 = # arg do.
    idx =. <. (# HISTORY) % 2
  elseif. *./ arg e. '0123456789' do.
    idx =. ". arg
  else.
    idx =. <. (# HISTORY) % 2
    note =. arg
  end.
  if. 0 < # note do.
    force_compact idx ; note
  else.
    force_compact idx
  end.
)

NB. /tree lists user messages on the active branch. /tree id
NB. moves the head to that entry.
tree_verb =: monad define
  arg =. deb y
  if. 0 < # arg do.
    session_checkout arg
    return.
  end.
  echo 'Head: ' , SESSION_HEAD
  pts =. session_user_points ''
  if. 0 = # pts do.
    echo 'No user messages on this branch.'
    return.
  end.
  for_i. i. # pts do.
    echo (> (< i, 0) { pts) , '  ' , > (< i, 1) { pts
  end.
)

NB. /clone copies the active branch. Same as /fork.
clone_verb =: clone_session

NB. /name sets the display name. The file name stays put.
name_verb =: session_set_label

login_verb =: login_provider
logout_verb =: logout_provider

NB. Skills, prompt templates, and the theme. Does not reconnect
NB. MCP servers and does not run extensions again.
reload_verb =: monad define
  if. 3 = 4!:0 <'discover_all_skills' do. discover_all_skills '' end.
  if. 3 = 4!:0 <'discover_prompts' do. discover_prompts '' end.
  if. 3 = 4!:0 <'apply_theme' do.
    try. apply_theme '' catch. end.
  end.
  echo 'Reloaded skills, prompts, and theme. Project context is read on the next request.'
)

NB. /skill:name reads that SKILL.md and sends it as the prompt.
skill_run =: monad define
  'name args' =. y
  if. 0 = # SKILLS do.
    echo 'No skills loaded.'
    return.
  end.
  names =. tolower each 0 {"1 SKILLS
  i =. names i. < tolower name
  if. i >: # SKILLS do.
    echo 'Unknown skill: ' , name
    return.
  end.
  path =. > (< i, 2) { SKILLS
  body =. ''
  try. body =. fread path catch. body =. '' end.
  if. 2 ~: 3!:0 body do. body =. '' end.
  ask_verb body , LF , 'Arguments: ' , args
)

NB. /context - the context BUDGET: the money knob. A lower
NB. budget fires compaction earlier and keeps requests cheap.
NB. no arg: show the budget and the model's advertised window
NB. N: set the budget manually
NB. auto: adopt the advertised window if the provider lists one,
NB.       else the provider default
context_verb =: monad define
  if. 0 = # y do.
    echo 'Context budget: ' , (": MAX_TOKENS) , ' tokens'
    if. 0 < MODEL_WINDOW do.
      echo 'Model advertises: ' , (": MODEL_WINDOW) , ' tokens (/context auto to adopt)'
    else.
      echo '(advertised window unknown; /context auto uses the provider default)'
    end.
    return.
  end.
  arg =. deb tolower y
  if. 'auto' -: arg do.
    try. adopt_context_window '' catch. end.
    NB. PIN the adopted number: number-only persistence means
    NB. the next startup applies it instantly, no lookup
    (": MAX_TOKENS) fwrite CONFIG_CONTEXT_FILE
    echo '(pinned: ' , (": MAX_TOKENS) , ' is now the default budget)'
    return.
  end.
  n =. (". :: 0:) deb y
  NB. length guard first: a failed parse can yield an EMPTY
  NB. numeric, and if. on an empty array is TRUE (AND of empty)
  if. 0 = # , n do.
    echo 'usage: /context [N | auto]'
    return.
  end.
  if. 0 < n do.
    MAX_TOKENS =: n
    (": n) fwrite CONFIG_CONTEXT_FILE
    echo 'Context budget set to: ' , (": n) , ' tokens (saved as default)'
  else.
    echo 'usage: /context [N | auto]'
  end.
)

NB. Explicit original:
NB.   skills_verb =: monad define
NB.     echo list_skills ''
NB. )
skills_verb =: echo @ list_skills

NB. Explicit original:
NB.   plugins_verb =: monad define
NB.     echo list_plugins ''
NB. )
plugins_verb =: echo @ list_plugins

NB. Boxed action names
ACTIONS =: 'read';'run';'edit';'write';'ask';'help';'clear';'export';'import';'session';'fork';'model';'compact';'context';'status';'transcript';'prompt';'usage';'git';'grep';'find';'theme';'skills';'plugins';'think';'tree';'clone';'name';'login';'logout';'reload'

NB. Gerund list must stay in sync with ACTIONS.
NB. Assert catches mismatches at load time.
ACTION_GERUNDS =: read_verb`run_verb`edit_verb`write_verb`ask_verb`help_verb`clear_verb`export_verb`import_verb`session_verb`fork_verb`model_verb`compact_verb`context_verb`status_verb`transcript_verb`prompt_verb`usage_verb`git_verb`grep_verb`find_verb`theme_verb`skills_verb`plugins_verb`think_verb`tree_verb`clone_verb`name_verb`login_verb`logout_verb`reload_verb
assert (#ACTIONS) = #ACTION_GERUNDS

NB. ----------------------------------------------------------------
NB. Main agent verb
agent =: monad define
  raw =. dlb y
  words =. chopstring raw
  if. 0 = #words do. return. end.
  cmd =. tolower > {. words
  cmd_len =. # > {. words
  remainder =. dlb cmd_len }. raw
  if. 'skill:' -: 6 {. cmd do.
    skill_run (6 }. > {. words) ; remainder
    return.
  end.
  idx =. ACTIONS i. < cmd
  if. idx < #ACTIONS do.
    NB. built-in command. These win over a template of the same name.
    (ACTION_GERUNDS @. idx) remainder
  elseif. is_ext_command cmd do.
    NB. extension command
    cmd ext_exec_command remainder
  elseif. do.
    hit =. 0
    if. 3 = 4!:0 <'is_prompt' do.
      if. is_prompt cmd do.
        cmd prompt_run remainder
        hit =. 1
      end.
    end.
    if. -. hit do.
      echo 'Unknown command: ' , cmd
    end.
  end.
)

load 'editor.ijs'
load 'prompts.ijs'
discover_prompts ''

echo 'J-PI agent loaded.'
