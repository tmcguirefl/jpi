NB. Phase 3: Command Execution Tool
NB. run_cmd.ijs

NB. run_cmd: execute shell command (y = command string)
NB. Returns boxed result: success=0; result=1 or (boxed output)
NB. Uses 2!:0 (host command foreign)
run_cmd =: 3 : 0
  try.
    out =. 2!:0 y
    < out
  catch.
    < 'ERROR: command failed: ', y
  end.
)

NB. Convenience: run and return raw string (empty on error)
run_cmd_str =: 3 : 0
  try. 2!:0 y catch. '' end.
)

echo 'Phase 3: run_cmd loaded.'