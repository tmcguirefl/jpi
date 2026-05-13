NB. Test enc_json_fixed against all known failure cases
require 'convert/json'
load '../src/enc_json_fixed.ijs'

NB. Helper: test round-trip through dec_json then enc_json_fixed
test_rt =: monad define
  'label json' =. y
  p =. dec_json json
  r =. enc_json_fixed p
  echo label , ':'
  echo '  in:  ' , json
  echo '  out: ' , r
  echo '  match: ' , ": json -: r
  echo ''
)

NB. Helper: test manually built structure
test_manual =: monad define
  'label obj expected' =. y
  r =. enc_json_fixed obj
  echo label , ':'
  echo '  shape: ' , (": $ obj) , '  $$: ' , ": $$ obj
  echo '  out: ' , r
  if. # expected do. echo '  expected: ' , expected end.
  echo ''
)

echo '=== Round-trip tests (dec_json then enc_json_fixed) ==='
test_rt 'simple object' ; '{"name":"test","value":42}'
test_rt 'array of strings' ; '["a","b","c"]'
test_rt 'array of objects' ; '[{"name":"read"},{"name":"write"}]'
test_rt 'nested object' ; '{"func":{"name":"read"},"type":"function"}'
test_rt 'object with array' ; '{"items":[1,2,3],"name":"test"}'
test_rt 'object with null' ; '{"role":"assistant","content":null}'
test_rt 'booleans' ; '{"active":true,"deleted":false}'
test_rt 'deeply nested' ; '{"a":{"b":{"c":{"d":"deep"}}}}'
test_rt 'tool_calls response' ; '{"role":"assistant","content":null,"tool_calls":[{"id":"call_123","type":"function","function":{"name":"bash","arguments":"{\"command\":\"ls\"}"}}]}'

echo ''
echo '=== Manual build tests (previously failed with enc_json) ==='

m2_test =: monad define
  echo '--- Manual 2: Nested object value is 2-row table ---'
  inner =. ('name';'desc') ,: 'read';'Read file'
  outer =. ('type';'function') ,: 'function'; < inner
  NB. note: < inner boxes it to prevent rank inflation
  r =. enc_json_fixed outer
  echo '  out: ' , r
  echo ''
)

m3_test =: monad define
  echo '--- Manual 3: Object with parsed schema as value ---'
  schema =. dec_json '{"type":"object","properties":{"path":{"type":"string"}}}'
  obj =. ('name';'description';'parameters') ,: 'read';'Read file'; < schema
  r =. enc_json_fixed obj
  echo '  out: ' , r
  echo ''
)

m4_test =: monad define
  echo '--- Manual 4: Array of objects using (<obj),(<obj) ---'
  o1 =. ('name';'desc') ,: 'read';'Read file'
  o2 =. ('name';'desc') ,: 'bash';'Run cmd'
  arr =. (<o1) , (<o2)
  r =. enc_json_fixed arr
  echo '  out: ' , r
  echo ''
)

m8_test =: monad define
  echo '--- Manual 8: Full payload structure ---'
  m1 =. ('role';'content') ,: 'user'; 'hello'
  msgs =. ,< m1
  schema =. dec_json '{"type":"object","properties":{"command":{"type":"string"}}}'
  tool_f =. ('name';'description';'parameters') ,: 'bash';'Run cmd'; < schema
  tool =. ('type';'function') ,: 'function'; < tool_f
  tools =. ,< tool
  payload =. ('model';'max_tokens';'tools';'messages') ,: 'test-model'; 4096; < tools; < msgs
  r =. enc_json_fixed payload
  echo '  out: ' , r
  echo ''
)

m2_test ''
m3_test ''
m4_test ''
m8_test ''

echo '=== All tests done ==='
