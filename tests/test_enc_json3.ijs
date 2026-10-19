NB. Test enc_json_fixed on manually-built structures (what our code creates)
NB.
NB. Structures are built beta9-safe: a boxed value linked with ; must be
NB. singly boxed ('key' ; < value is safe — splicing a 1-item box appends
NB. exactly one item), but a boxed LIST (more than one item) as the right
NB. operand of ; gets its items spliced in. Append such values with ,
NB. instead. See the header of enc_json_fixed.ijs.
NB.
NB. Visual coverage of the no-box (mangled) builds lives in
NB. test_enc_fixed2.ijs; this file asserts exact encoder output.

require 'convert/json'
load '../src/enc_json_fixed.ijs'

PASS =: 0
FAIL =: 0

check =: monad define
  if. y do.
    PASS =: PASS + 1
  else.
    FAIL =: FAIL + 1
    echo 'FAIL'
  end.
  ''
)

NB. x = expected JSON string, y = J structure
assert_enc =: dyad define
  try.
    r =. enc_json_fixed y
    if. x -: r do.
      check 1
    else.
      check 0
      echo '  expected: ' , x
      echo '  got     : ' , r
    end.
  catch.
    FAIL =: FAIL + 1
    echo 'FAIL: encoder error: ' , 13!:12 ''
  end.
  ''
)

NB. Round-trip: dec_json (enc_json_fixed y) must match y
assert_rt =: monad define
  try.
    r =. dec_json enc_json_fixed y
    check r -: y
  catch.
    FAIL =: FAIL + 1
    echo 'FAIL: round-trip error: ' , 13!:12 ''
  end.
  ''
)

NB. --- Manual 1: 2-row table built with ,: ---
echo '=== Manual 1: 2-row table built with ,: ==='
obj1 =. ('name';'desc') ,: 'read';'Read file'
'{"name":"read","desc":"Read file"}' assert_enc obj1
assert_rt obj1

NB. --- Manual 2: nested - object value is a 2-row table ---
echo '=== Manual 2: Nested - object value is a 2-row table ==='
inner =. ('name';'desc') ,: 'read';'Read file'
outer =. ('type';'function') ,: 'function'; < inner
'{"type":"function","function":{"name":"read","desc":"Read file"}}' assert_enc outer
assert_rt outer

NB. --- Manual 3: object value is a parsed JSON schema ---
echo '=== Manual 3: Object value is a parsed JSON schema ==='
schema =. dec_json '{"type":"object","properties":{"path":{"type":"string"}}}'
obj3 =. ('name';'description';'parameters') ,: 'read';'Read file'; < schema
'{"name":"read","description":"Read file","parameters":{"type":"object","properties":{"path":{"type":"string"}}}}' assert_enc obj3
assert_rt obj3

NB. --- Manual 4: array of manually-built objects ---
echo '=== Manual 4: Array of manually-built objects ==='
o1 =. ('name';'desc') ,: 'read';'Read file'
o2 =. ('name';'desc') ,: 'bash';'Run cmd'
arr4 =. (< o1) , < o2
'[{"name":"read","desc":"Read file"},{"name":"bash","desc":"Run cmd"}]' assert_enc arr4
assert_rt arr4

NB. --- Manual 5: boxed list with < ---
echo '=== Manual 5: Boxed list with < ==='
o5 =. (<'read';'Read file';'{}') , <'bash';'Run cmd';'{}'
'[["read","Read file","{}"],["bash","Run cmd","{}"]]' assert_enc o5

NB. --- Manual 6: message object ---
echo '=== Manual 6: Message object ==='
msg =. ('role';'content') ,: 'user'; 'hello world'
'{"role":"user","content":"hello world"}' assert_enc msg
assert_rt msg

NB. --- Manual 7: array of message objects ---
echo '=== Manual 7: Array of message objects ==='
m1 =. ('role';'content') ,: 'user'; 'hello'
m2 =. ('role';'content') ,: 'assistant'; 'hi there'
arr7 =. (< m1) , < m2
'[{"role":"user","content":"hello"},{"role":"assistant","content":"hi there"}]' assert_enc arr7
assert_rt arr7

NB. --- Manual 8: full payload-like structure ---
echo '=== Manual 8: Full payload-like structure ==='
msg8 =. ('role';'content') ,: 'user'; 'hello'
msgs8 =. ,< msg8
schema8 =. dec_json '{"type":"object","properties":{"command":{"type":"string"}}}'
tool_f8 =. ('name';'description';'parameters') ,: 'bash';'Run cmd'; < schema8
tool8 =. ('type';'function') ,: 'function'; < tool_f8
tools8 =. ,< tool8
payload8 =. ('model';'max_tokens';'tools';'messages') ,: ('test-model'; 4096) , (< tools8) , < msgs8
'{"model":"test-model","max_tokens":4096,"tools":[{"type":"function","function":{"name":"bash","description":"Run cmd","parameters":{"type":"object","properties":{"command":{"type":"string"}}}}}],"messages":[{"role":"user","content":"hello"}]}' assert_enc payload8
assert_rt payload8

NB. Summary (control words are definition-body-only, so wrap in a def)
summarize =: monad define
  ps =. ": PASS
  fs =. ": FAIL
  echo 'passed: ' , ps , '  failed: ' , fs
  if. 0 = FAIL do.
    echo 'ALL TESTS PASSED'
  else.
    echo 'TESTS FAILED'
  end.
)
summarize ''
