NB. Tests for run_cmd.ijs — squote, dquote, jconsole alias, is_j_jconsole
NB. test_run_cmd.ijs
NB.
NB. Run from src/:  jconsole < ../tests/test_run_cmd.ijs

load 'run_cmd.ijs'

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

NB. --- squote tests ---

echo '=== squote ==='
NB. squote wraps in single quotes
sq =. squote '/foo/bar'
check '''' = {. sq
check '''' = {: sq
check (2 + # '/foo/bar') = # sq

NB. squote with spaces
sq2 =. squote '/path/with space/jconsole'
check '''' = {. sq2
check '''' = {: sq2
check (2 + # '/path/with space/jconsole') = # sq2

NB. squote with single quote in path: ' → '\''
sq3 =. squote '/foo''bar'
NB. squote replaces ' with '\'' (4 chars), then wraps in outer quotes.
NB. '/foo'bar' (8 chars) → '/foo'\''bar' (13 chars)
check 13 = # sq3

NB. --- dquote tests ---

echo '=== dquote ==='
dq =. dquote 'hello'
check '"' = {. dq
check '"' = {: dq
check 7 = # dq  NB. "hello" = 7 chars

check '\$' +./@E. dquote 'a$b'
check '\"' +./@E. dquote 'a"b'

NB. --- is_j_jconsole tests ---

echo '=== is_j_jconsole ==='
NB. candidate validation uses the resolved JBIN_PATH (env-driven,
NB. see resolve_jbin); a hardcoded machine path would not port
check -. is_j_jconsole '/usr/bin/jconsole'
check -. is_j_jconsole '/nonexistent/jconsole'

NB. --- JBIN_PATH tests ---

echo '=== JBIN_PATH ==='
check 0 < #JBIN_PATH
check is_j_jconsole JBIN_PATH

NB. --- jconsole alias tests ---

echo '=== jconsole alias ==='
NB. jconsole in a run_cmd subprocess should call J's jconsole
out =. run_cmd 'echo ''i. 5'' | jconsole'
check '0 1 2 3 4' +./@E. > out

NB. jconsole should be a shell function (not PATH lookup)
out2 =. run_cmd 'type jconsole 2>&1'
check 'function' +./@E. > out2

NB. Basic commands still work
out3 =. run_cmd 'echo hello'
check 'hello' -: }: > out3

NB. --- Report ---
report ''
