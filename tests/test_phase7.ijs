NB. Phase 7 Tests: End-to-end integration
NB. test_phase7.ijs
NB.
NB. Run from src/:  jconsole < ../tests/test_phase7.ijs
NB.
NB. assert. is definition-body-only in J (top-level control words
NB. are a syntax error), so checks use the check/report pattern
NB. shared with the other test files.

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

NB. ----------------------------------------------------------------
NB. Test 1: Write a file, read it back, edit it, read again
echo '=== file round trip ==='
testfile =. 'test_e2e.txt'
check 1 = write_file testfile ; 'Hello World'
NB. fwrites (line-oriented write) appends a trailing LF, so curtail
NB. the read-back before exact comparison.
check 'Hello World' -: }: read_file_str testfile
check 1 = edit_file testfile ; 'World' ; 'J-PI'
check 'Hello J-PI' -: }: read_file_str testfile
ferase testfile

NB. ----------------------------------------------------------------
NB. Test 2: Safety check blocks dangerous commands
echo '=== safety ==='
check 1 = is_safe 'ls -la'
check 0 = is_safe 'rm -rf /'
check 0 = is_safe 'dd if=/dev/zero'

NB. ----------------------------------------------------------------
NB. Test 3: Agent dispatch (smoke — errors surface as J error output)
echo '=== agent dispatch ==='
agent 'run echo hello from agent'

NB. ----------------------------------------------------------------
NB. Test 4: Logging
NB. run only logs blocked commands, so write an entry explicitly.
echo '=== logging ==='
log 'phase7 test entry'
check fexist LOGFILE
ferase LOGFILE

NB. ----------------------------------------------------------------
report ''
