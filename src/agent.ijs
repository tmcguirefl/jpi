NB. Phase 6 (final): Agent with explicit definition + standard constants
NB. agent.ijs

load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'

NB. ----------------------------------------------------------------
NB. Action verbs (explicit monads using monad define)

read_verb =: monad define
  echo 'Reading: ', y
  read_file_str y
)

run_verb =: monad define
  echo 'Running: ', y
  run_cmd_str y
)

edit_verb =: monad define
  echo 'Edit: ', y
)

write_verb =: monad define
  echo 'Write: ', y
)

unknown_verb =: monad define
  echo 'Unknown command: ', y
)

NB. Boxed action names (semicolon literal style)
ACTIONS =: 'read';'run';'edit';'write'

NB. ----------------------------------------------------------------
NB. Main agent verb
NB. cutopen boxes words by whitespace, {. takes command, }. takes args
agent =: monad define
  words =. cutopen y
  cmd =. tolower > {. words          NB. first word (unboxed, lowered)
  remainder =. }. ; ' '&,&.> }. words  NB. drop cmd, rejoin rest with spaces
  idx =. ACTIONS i. < cmd
  (read_verb`run_verb`edit_verb`write_verb`unknown_verb) @. idx remainder
)

echo 'Phase 6: agent loaded (explicit monad + monad define + boxed agenda)'