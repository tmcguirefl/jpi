NB. Batch test runner
NB. tests/run_all.ijs
NB.
NB. Run from project root:  jconsole tests/run_all.ijs
NB. Finds jconsole, runs each test_*.ijs in a subprocess from the
NB. correct working directory, reports pass/fail summary.

require 'files'

NB. ----------------------------------------------------------------
NB. Find jconsole. Rejects Java's jconsole (a GUI app that shares
NB. the name) by validating each candidate. Order: JBIN env,
NB. machine-local local/env.sh (export JBIN=..., also sourced by
NB. the jpi launcher), common install locations, then PATH.
is_j_jconsole =: monad define
  try.
    out =. 2!:0 'echo ''i. 3'' | perl -e ''alarm 10; exec @ARGV'' ' , y , ' 2>/dev/null'
    '0 1 2' +./@E. out
  catch.
    0
  end.
)

NB. parse JBIN= from local/env.sh (bash-sourced by the launcher;
NB. J cannot source shell files, so read the simple KEY=VALUE lines)
env_jbin =: monad define
  txt =. fread 'local/env.sh'
  if. (2 ~: 3!:0 txt) +. 0 = # txt do. '' return. end.
  for_l. <;._2 txt do.
    ln =. > l
    if. '#' = {. deb ln do. continue. end.
    m =. 'export JBIN=' E. ln
    if. +./ m do.
      p =. (m i. 1) + # 'export JBIN='
      deb p }. ln return.
    end.
  end.
  ''
)

find_jconsole =: monad define
NB. NB. j9.8-beta9 dyadic ; boxes the left argument whole, so
NB. incremental linking nests instead of appending. Build the
NB. candidate list in a single expression.
  e =. > 2!:5 'JBIN'
  if. 2 = 3!:0 e do.
    if. is_j_jconsole e do. e return. end.
  end.
  e =. env_jbin ''
  if. (0 < # e) *. is_j_jconsole e do. e return. end.
  home =. > 2!:5 'HOME'
  candidates =. '/Applications/j9.8/bin/ijconsole' ; '/Applications/j9.8/bin/jconsole' ; '/usr/local/bin/ijconsole' ; '/usr/local/j9.8/bin/ijconsole' ; '/usr/local/j9.8/bin/jconsole' ; '/usr/local/bin/jconsole'
  if. 2 = 3!:0 home do. candidates =. ((home , '/j9.8/bin/ijconsole') ; (home , '/j9.8/bin/jconsole')) , candidates end.
  for_c. candidates do.
    if. is_j_jconsole > c do. > c return. end.
  end.
  for_w. 'ijconsole' ; 'jconsole' do.
    path =. ''
    try.
      path =. _1 }. 2!:0 'which ' , (> w) , ' 2>/dev/null'
    catch.
      path =. ''
    end.
    if. (0 < # path) *. is_j_jconsole path do. path return. end.
  end.
  ''
)

NB. ----------------------------------------------------------------
NB. Run a single test file in a subprocess
NB. x = jconsole path, y = test file path (e.g. 'tests/test_utils.ijs')
NB. Returns 1 if passed, 0 if failed
run_one =: dyad define
  jbin =. x
  path =. y
  name =. (#'tests/') }. path
  echo '=== ' , name , ' ==='
  
  NB. All tests run from src/ — src modules load their dependencies
  NB. by relative name (agent.ijs load 'config.ijs'), which resolves
  NB. against the cwd, not the loading script's directory. From src/,
  NB. both those loads and the tests' '../src/...' paths resolve.
  NB. Export JPI_SRC: tui.ijs locates vendor/vt.ijs and its sibling
  NB. loads through it (the jpi launcher exports it the same way).
  NB. Export JBIN so run_cmd's resolve_jbin finds this validated
  NB. jconsole inside the test subprocesses.
  cmd =. 'cd src && JBIN=' , jbin , ' JPI_SRC=' , (1!:43 '') , '/src timeout 15 ' , jbin , ' < ../' , path , ' 2>&1'
  
  out =. 2!:0 cmd
  
  NB. Print output (indented)
  if. 0 < #out do.
    if. LF ~: {: out do. out =. out , LF end.
    for_l. <;._2 out do.
      echo '  ' , > l
    end.
  end.
  
  NB. Check for failure indicators
  failed =. 'FAIL' +./@E. out
  failed =. failed +. 'TESTS FAILED' +./@E. out
  failed =. failed +. '|domain error' +./@E. out
  failed =. failed +. '|value error' +./@E. out
  failed =. failed +. '|syntax error' +./@E. out
  
  if. failed do.
    echo '  FAIL'
    0
  else.
    echo '  PASS'
    1
  end.
)

NB. ----------------------------------------------------------------
NB. Main
main =: monad define
  jbin =. find_jconsole ''
  if. 0 = #jbin do.
    echo 'ERROR: jconsole not found'
    0 return.
  end.
  echo 'Using jconsole: ' , jbin
  echo ''
  
  NB. Discover test files via ls
  ls_out =. 2!:0 'ls -1 tests/test_*.ijs 2>/dev/null'
  if. 0 = #ls_out do.
    echo 'ERROR: no test files found'
    0 return.
  end.
  if. LF ~: {: ls_out do. ls_out =. ls_out , LF end.
  test_paths =. /:~ <;._2 ls_out
  
  echo (": # test_paths) , ' test files found.'
  echo ''
  
  pass_count =. 0
  fail_count =. 0
  failed_names =. 0 $ <''
  
  for_t. test_paths do.
    path =. > t
    try.
      result =. jbin run_one path
      if. result do.
        pass_count =. pass_count + 1
      else.
        fail_count =. fail_count + 1
        failed_names =. failed_names , < path
      end.
    catch.
      fail_count =. fail_count + 1
      failed_names =. failed_names , < path
      echo '  ERROR: ' , 13!:12 ''
    end.
    echo ''
  end.
  
  NB. Summary
  echo '========================================'
  echo 'RESULTS: ' , (": pass_count) , ' passed, ' , (": fail_count) , ' failed'
  if. 0 < # failed_names do.
    echo 'Failed tests:'
    for_f. failed_names do.
      echo '  ' , > f
    end.
  end.
  echo '========================================'
  
  if. 0 < fail_count do. 1 else. 0 end.
)

rc =. main ''
NB. Top-level if. is a spelling error in J; use a verb
report_rc =: monad define
  if. y do.
    2!:55 (1)
  end.
)
report_rc rc
