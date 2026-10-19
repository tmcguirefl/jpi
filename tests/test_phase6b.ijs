NB. Phase 6 (revised) Tests — agent dispatcher
NB. test_phase6b.ijs
NB.
NB. Run from src/:  jconsole < ../tests/test_phase6b.ijs
NB.
NB. get_action_index was removed when dispatch moved to the
NB. ACTIONS/ACTION_GERUNDS table; these tests cover the current
NB. dispatcher: table integrity, built-in routing, and the
NB. unknown-command path (previously a live demo that wrote
NB. scratch files).

load '../src/agent.ijs'

PASS =: 0
FAIL =: 0

check =: monad define
  if. y do.
    PASS =: >: PASS
  else.
    FAIL =: >: FAIL
    echo '  FAIL'
  end.
)

report =: monad define
  echo ''
  echo 'Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed'
  if. FAIL > 0 do.
    echo 'TESTS FAILED'
  else.
    echo 'ALL TESTS PASSED'
  end.
)

echo '=== dispatch table integrity ==='
check (#ACTIONS) = #ACTION_GERUNDS
check (<'read') e. ACTIONS
check (<'think') e. ACTIONS
check -. (<'xyzzy') e. ACTIONS

echo '=== built-in dispatch (think toggles global state) ==='
NB. save the user's thinking config and restore it afterwards.
NB. (control words are definition-body-only, so save/restore are verbs)
save_think_cfg =: monad define
  SAVE_HAD_FILE =: fexist CONFIG_THINK_FILE
  SAVE_ORIG =: ''
  if. SAVE_HAD_FILE do. SAVE_ORIG =: fread CONFIG_THINK_FILE end.
)
restore_think_cfg =: monad define
  if. SAVE_HAD_FILE do. SAVE_ORIG fwrite CONFIG_THINK_FILE
  else. ferase CONFIG_THINK_FILE end.
  load_think ''
)

save_think_cfg ''
agent 'think off'
check 0 = THINK_ON
agent 'think 2000'
check 1 = THINK_ON
check 2000 = THINK_BUDGET
restore_think_cfg ''

echo '=== built-in dispatch (run verb) ==='
NB. smoke: dispatch through to run_cmd; errors surface as J errors
agent 'run echo phase6b ok'

echo '=== unknown command ==='
NB. smoke: prints 'Unknown command: xyzzy' and returns without error
agent 'xyzzy'

report ''
