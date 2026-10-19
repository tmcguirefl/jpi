NB. Regression tests for recent fixes
NB. test_regression.ijs
NB.
NB. Run from src/:  jconsole < ../tests/test_regression.ijs
NB.
NB. Covers:
NB.   1. mk_tool JSON escaping (newlines, quotes, backslashes)
NB.   2. MCP schema serialization (enc_json_fixed, not ": display)
NB.   3. is_safe injection blocking (blocked command patterns)
NB.   4. require_field / is_error helpers
NB.   5. is_ext_tool dispatch + exec_tool fallback to error
NB.   6. build_payload produces valid JSON with required fields

require 'convert/json'
load 'enc_json_fixed.ijs'
load 'config.ijs'
load 'log.ijs'
load 'safety.ijs'
load 'image.ijs'
load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'
load 'skills.ijs'
load 'git.ijs'
load 'system_prompt.ijs'
load 'mcp.ijs'
load 'plugins.ijs'
load 'extensions.ijs'
load 'context.ijs'
load 'usage.ijs'
load 'llm.ijs'
load 'confirm.ijs'
load 'tool_exec.ijs'

NB. Override provider/model for deterministic tests (after config load)
PROVIDER =: 'openrouter'
MODEL =: 'openrouter/test-model'
HISTORY =: 0 $ <''

NB. Test harness
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

NB. Safe dec_json wrapper (returns _1 on parse failure instead of error)
safe_dec =: monad define
  r =. _1
  try.
    r =. dec_json y
  catch.
    r =. _1
  end.
  r
)

echo '=== Test 1: mk_tool escapes newlines in description ==='
t1 =. 'parameters' mk_tool 'test';('line1',(10{a.),'line2');'{}'
check 'line1\nline2' +./@E. t1
check -. (10{a.) +./@E. t1

echo '=== Test 2: mk_tool escapes double quotes ==='
t2 =. 'parameters' mk_tool 'te"st';'say "hi"';'{}'
check '\"' +./@E. t2

echo '=== Test 3: mk_tool escapes backslashes ==='
t3 =. 'parameters' mk_tool 'test';'path\to';'{}'
check '\\' +./@E. t3

echo '=== Test 4: mk_tool output is valid JSON ==='
t4 =. 'parameters' mk_tool 'read';'Read file';'{"type":"object"}'
t4p =. safe_dec t4
check _1 ~: t4p

echo '=== Test 5: MCP schema serialized as JSON, not J display ==='
schema =. dec_json '{"type":"object","properties":{"q":{"type":"string"}}}'
encoded =. enc_json_fixed schema
check '{' = {. encoded
check 'type' +./@E. encoded
check 'properties' +./@E. encoded
check -. '+' = {. encoded

echo '=== Test 6: is_safe blocks dangerous commands ==='
check 0 = is_safe 'rm -rf /'
check 0 = is_safe 'mkfs /dev/sda'
check 0 = is_safe 'dd if=/dev/zero of=/dev/sda'
check 0 = is_safe ':(){ :|:& };:'
check 0 = is_safe 'echo bad > /dev/sda'

echo '=== Test 7: is_safe allows safe commands ==='
check 1 = is_safe 'ls -la'
check 1 = is_safe 'cat file.txt'
check 1 = is_safe 'grep pattern file'
check 1 = is_safe 'echo hello'

echo '=== Test 8: is_error detects ERROR: prefix ==='
check is_error 'ERROR: something went wrong'
check -. is_error 'success'
check -. is_error ''
check -. is_error 42

echo '=== Test 9: require_field returns value when present ==='
obj =. dec_json '{"path":"/tmp/test","limit":100}'
pv =. 'path' require_field obj
check '/tmp/test' -: > pv
lv =. 'limit' require_field obj
check 100 = > lv

echo '=== Test 10: require_field returns error when missing ==='
mv =. 'nonexistent' require_field obj
check is_error mv

echo '=== Test 11: exec_tool dispatches built-in tools ==='
check 0 = (, each TOOLS) i. < ,'read'
check 1 = (, each TOOLS) i. < ,'bash'
check 4 = (, each TOOLS) i. < ,'j'
check 4 < # TOOLS

echo '=== Test 12: exec_tool returns error for unknown tools ==='
result =. exec_tool 'nonexistent'; (dec_json '{}')
check is_error result

echo '=== Test 13: is_ext_tool returns 0 for empty registry ==='
check 0 = is_ext_tool 'anything'

echo '=== Test 14: build_payload produces valid JSON ==='
pl =. build_payload ''
plp =. safe_dec pl
check _1 ~: plp

echo '=== Test 15: build_payload contains required fields ==='
pl2 =. build_payload ''
plp2 =. safe_dec pl2
check _1 ~: 'model' gethash_json plp2
check _1 ~: 'tools' gethash_json plp2
check _1 ~: 'messages' gethash_json plp2

echo ''
echo '=== Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed ==='
