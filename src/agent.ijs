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

NB. ----------------------------------------------------------------
NB. Direct-mode action verbs (no LLM needed)

read_verb =: monad define
  echo 'Reading: ', y
  echo read_file_str y
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

save_verb =: monad define
  save_session ''
)

load_verb =: monad define
  load_session ''
)

model_verb =: monad define
  if. 0 = #y do.
    echo 'Current model: ' , MODEL
    return.
  end.
  MODEL =: y
  echo 'Model set to: ' , MODEL
)

usage_verb =: monad define
  show_usage ''
)

unknown_verb =: monad define
  echo 'Unknown command: ', y
)

NB. Boxed action names
ACTIONS =: 'read';'run';'edit';'write';'ask';'clear';'save';'load';'model';'usage'

NB. ----------------------------------------------------------------
NB. Main agent verb
agent =: monad define
  words =. chopstring y
  cmd =. tolower > {. words
  remainder =. _1 }. ; (,&' ') each }. words
  idx =. ACTIONS i. < cmd
  (read_verb`run_verb`edit_verb`write_verb`ask_verb`clear_verb`save_verb`load_verb`model_verb`usage_verb`unknown_verb) @. idx remainder
)

echo 'J-PI agent loaded.'
