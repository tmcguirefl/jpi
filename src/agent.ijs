NB. Phase 6 (final): Agent with explicit definition + standard constants
NB. agent.ijs

load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'

NB. ----------------------------------------------------------------
NB. Action verbs (explicit monads using monad define)

read_verb =: monad define
  echo 'Reading file...'
  read_file_str 'README.md'
)

run_verb =: monad define
  echo 'Running command...'
  run_cmd_str 'ls'
)

edit_verb =: monad define
  echo 'Editing file...'
)

write_verb =: monad define
  echo 'Writing file...'
)

unknown_verb =: monad define
  echo 'Unknown command'
)

NB. Boxed action names (semicolon literal style)
ACTIONS =: 'read';'run';'edit';'write'

NB. ----------------------------------------------------------------
NB. Main agent verb - i. lookup inline (common J idiom)
agent =: monad define
  idx =. ACTIONS i. < tolower y
  (read_verb`run_verb`edit_verb`write_verb`unknown_verb) @. idx y
)

echo 'Phase 6: agent loaded (explicit monad + monad define + boxed agenda)'