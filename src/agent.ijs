NB. Agent - integrated dispatcher
NB. agent.ijs
NB. Supports both direct commands and LLM-backed mode

load 'config.ijs'
load 'log.ijs'
load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'
load 'llm.ijs'
load 'tool_exec.ijs'
load 'session.ijs'
load 'extensions.ijs'

NB. ----------------------------------------------------------------
NB. List available models from OpenRouter (used by model_verb)
list_models =: monad define
  models_list =. 0 $ <''
  ids_list =. 0 $ <''
  
  NB. Inject primary native models
  models_list =. models_list , < 'claude-3-7-sonnet-20250219  -  [Direct Anthropic API]'
  ids_list =. ids_list , < 'claude-3-7-sonnet-20250219'
  models_list =. models_list , < 'gemini-2.5-flash  -  [Direct Google AI Studio]'
  ids_list =. ids_list , < 'gemini-2.5-flash'
  models_list =. models_list , < 'gemini-2.5-pro  -  [Direct Google AI Studio]'
  ids_list =. ids_list , < 'gemini-2.5-pro'
  models_list =. models_list , < 'tcm/llama.cpp9270  -  [tcmcguire.servehttp.com]'
  ids_list =. ids_list , < 'tcm/llama.cpp9270'
  models_list =. models_list , < 'local/llama-server  -  [Localhost 8080]'
  ids_list =. ids_list , < 'local/llama-server'
  models_list =. models_list , < 'local/ollama  -  [Localhost 11434]'
  ids_list =. ids_list , < 'local/ollama'
  
  NB. Fetch Google models if available
  try.
    if. has_api_key 'GEMINI_API_KEY' do.
      echo 'Fetching models from Google...'
      raw =. 2!:0 'curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=' , (get_api_key 'GEMINI_API_KEY') , '"'
      js  =. dec_json raw
      err =. 'error' gethash_json js
      if. _1 -: err do.
        marr =. 'models' gethash_json js
        if. marr -.@-: _1 do.
          for_m. > marr do.
            m =. > m
            nm =. > 'name' gethash_json m
            disp =. > 'displayName' gethash_json m
            if. 'models/' -: 7 {. nm do. nm =. 7 }. nm end.
            models_list =. models_list , < (nm , '  -  ' , disp)
            ids_list =. ids_list , < nm
          end.
        end.
      end.
    end.
  catch. end.

  NB. Fetch local models if available
  try.
    if. has_api_key 'LOCAL_API_KEY' do.
      echo 'Fetching models from Localhost 8080...'
      raw =. 2!:0 'curl -s http://localhost:8080/v1/models'
      js  =. dec_json raw
      err =. 'error' gethash_json js
      if. _1 -: err do.
        marr =. 'data' gethash_json js
        if. marr -.@-: _1 do.
          for_m. > marr do.
            m =. > m
            id =. > 'id' gethash_json m
            models_list =. models_list , < ('local/' , id , '  -  Local')
            ids_list =. ids_list , < ('local/' , id)
          end.
        end.
      end.
    end.
  catch. end.

  try.
    if. has_api_key 'OLLAMA_API_KEY' do.
      echo 'Fetching models from Ollama...'
      raw =. 2!:0 'curl -s http://localhost:11434/v1/models'
      js  =. dec_json raw
      err =. 'error' gethash_json js
      if. _1 -: err do.
        marr =. 'data' gethash_json js
        if. marr -.@-: _1 do.
          for_m. > marr do.
            m =. > m
            id =. > 'id' gethash_json m
            models_list =. models_list , < ('ollama/' , id , '  -  Ollama')
            ids_list =. ids_list , < ('ollama/' , id)
          end.
        end.
      end.
    end.
  catch. end.

  try.
    if. has_api_key 'TCM_API_KEY' do.
      echo 'Fetching models from TCM...'
      raw =. 2!:0 'curl -s https://tcmcguire.servehttp.com/v1/models'
      js  =. dec_json raw
      err =. 'error' gethash_json js
      if. _1 -: err do.
        marr =. 'data' gethash_json js
        if. marr -.@-: _1 do.
          for_m. > marr do.
            m =. > m
            id =. > 'id' gethash_json m
            models_list =. models_list , < ('tcm/' , id , '  -  TCM Hosted')
            ids_list =. ids_list , < ('tcm/' , id)
          end.
        end.
      end.
    end.
  catch. end.

  echo 'Fetching model list from OpenRouter...'
  
  NB. try to fetch OpenRouter models transparently as appendable backup list
  try.
    if. has_api_key 'OPENROUTER_API_KEY' do.
      raw =. 2!:0 'curl -s -H "Authorization: Bearer ' , (get_api_key 'OPENROUTER_API_KEY') , '" https://openrouter.ai/api/v1/models'
      js  =. dec_json raw
      err =. 'error' gethash_json js
      if. _1 -: err do.
        data =. > 'data' gethash_json js
        for_m. data do.
          m =. > m
          idv =. 'id' gethash_json m
          if. idv -.@-: _1 do.
            id =. > idv
            name =. 'N/A'
            namev =. 'name' gethash_json m
            if. namev -.@-: _1 do. name =. > namev end.
            
            models_list =. models_list , < (id , '  -  ' , name)
            ids_list =. ids_list , < id
          end.
        end.
      end.
    end.
  catch. end.

  if. 3 = 4!:0 <'tui_select_menu' do.
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
  echo 'Asking LLM...'
  log 'ask: ', y
  reply =. llm_ask y
  echo reply
)

clear_verb =: monad define
  clear_history ''
)

session_verb =: monad define
  if. 0 = #y do.
    list_sessions ''
    return.
  end.
  switch_session y
)

export_verb =: monad define
  save_session ''
)

import_verb =: monad define
  load_session ''
)

model_verb =: monad define
  if. 0 = #y do.
    list_models ''
    return.
  end.
  MODEL =: y
  save_model ''
  echo 'Model set to: ' , MODEL
)

usage_verb =: monad define
  show_usage ''
)

theme_verb =: monad define
  if. 0 = #y do.
    list_themes ''
    return.
  end.
  set_theme y
)

git_verb =: monad define
  if. 0 = #y do.
    NB. show git summary
    if. -. is_git_repo '' do. echo 'Not a git repo.' return. end.
    echo 'Branch: ' , git_branch ''
    echo git_status ''
  else.
    NB. pass through to git command
    echo run_cmd_str 'git ' , y
  end.
)

grep_verb =: monad define
  echo run_cmd_str 'grep -rn ' , y
)

find_verb =: monad define
  echo run_cmd_str 'find ' , y
)

unknown_verb =: monad define
  echo 'Unknown command: ', y
)

compact_verb =: monad define
  if. 0 = #y do.
    NB. default carefully compacts half the history
    idx =. <. (#HISTORY) % 2
  else.
    try. idx =. 0 ". y catch. idx =. 4 end.
  end.
  force_compact idx
)

NB. Boxed action names
ACTIONS =: 'read';'run';'edit';'write';'ask';'clear';'export';'import';'session';'model';'compact';'usage';'git';'grep';'find';'theme'

NB. ----------------------------------------------------------------
NB. Main agent verb
agent =: monad define
  raw =. dlb y
  words =. chopstring raw
  if. 0 = #words do. return. end.
  cmd =. tolower > {. words
  cmd_len =. # > {. words
  remainder =. dlb cmd_len }. raw
  idx =. ACTIONS i. < cmd
  if. idx < #ACTIONS do.
    NB. built-in command
    (read_verb`run_verb`edit_verb`write_verb`ask_verb`clear_verb`export_verb`import_verb`session_verb`model_verb`compact_verb`usage_verb`git_verb`grep_verb`find_verb`theme_verb) @. idx remainder
  elseif. is_ext_command cmd do.
    NB. extension command
    cmd ext_exec_command remainder
  elseif. do.
    echo 'Unknown command: ' , cmd
  end.
)

echo 'J-PI agent loaded.'
