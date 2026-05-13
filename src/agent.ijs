NB. Phase 7: Integrated Agent
NB. agent.ijs

load 'log.ijs'
load 'safety.ijs'
load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'

NB. ----------------------------------------------------------------
NB. Action verbs

read_verb =: monad define
  log 'read: ', y
  echo 'Reading: ', y
  read_file_str y
)

run_verb =: monad define
  if. -. is_safe y do.
    log 'BLOCKED: ', y
    echo 'Command blocked for safety.'
    return.
  end.
  log 'run: ', y
  echo 'Running: ', y
  run_cmd_str y
)

edit_verb =: monad define
  log 'edit: ', y
  echo 'Edit: ', y
)

write_verb =: monad define
  log 'write: ', y
  echo 'Write: ', y
)

unknown_verb =: monad define
  log 'unknown: ', y
  echo 'Unknown command: ', y
)

NB. Boxed action names
ACTIONS =: 'read';'run';'edit';'write'

NB. ----------------------------------------------------------------
NB. Main agent verb
agent =: monad define
  words =. chopstring y
  cmd =. tolower > {. words
  remainder =. _1 }. ; (,&' ') each }. words
  idx =. ACTIONS i. < cmd
  (read_verb`run_verb`edit_verb`write_verb`unknown_verb) @. idx remainder
)

echo 'J-PI agent loaded.'
