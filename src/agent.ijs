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

NB. ----------------------------------------------------------------
NB. Direct-mode action verbs (no LLM needed)

read_verb =: monad define
  echo 'Reading: ', y
  read_file_str y
)

run_verb =: monad define
  if. -. is_safe y do.
    log 'BLOCKED: ', y
    echo 'Command blocked for safety.'
    return.
  end.
  echo 'Running: ', y
  run_cmd_str y
)

edit_verb =: monad define
  echo 'Edit: ', y
)

write_verb =: monad define
  echo 'Write: ', y
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

unknown_verb =: monad define
  echo 'Unknown command: ', y
)

NB. Boxed action names
ACTIONS =: 'read';'run';'edit';'write';'ask';'clear'

NB. ----------------------------------------------------------------
NB. Main agent verb
agent =: monad define
  words =. chopstring y
  cmd =. tolower > {. words
  remainder =. _1 }. ; (,&' ') each }. words
  idx =. ACTIONS i. < cmd
  (read_verb`run_verb`edit_verb`write_verb`ask_verb`clear_verb`unknown_verb) @. idx remainder
)

echo 'J-PI agent loaded.'
