NB. Phase 3: Command Execution Tool
NB. run_cmd.ijs

NB. run_cmd: execute shell command, returns boxed output
run_cmd =: monad define
  try.
    < 2!:0 y
  catch.
    < 'ERROR: command failed: ', y
  end.
)

NB. run_cmd_str: returns raw string (empty on error)
run_cmd_str =: monad define
  try. 2!:0 y catch. '' end.
)

echo 'run_cmd loaded.'
