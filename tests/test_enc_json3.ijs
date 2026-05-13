NB. Test enc_json on manually-built structures (what our code creates)
require 'convert/json'

test_manual1 =: monad define
  echo '=== Manual 1: 2-row table built with ,: ==='
  obj =. ('name';'desc') ,: 'read';'Read file'
  echo 'shape: ' , (": $ obj) , '  $$: ' , ": $$ obj
  try. echo enc_json obj catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual2 =: monad define
  echo '=== Manual 2: Nested - object value is a 2-row table ==='
  inner =. ('name';'desc') ,: 'read';'Read file'
  outer =. ('type';'function') ,: 'function'; inner
  echo 'shape: ' , (": $ outer) , '  $$: ' , ": $$ outer
  try. echo enc_json outer catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual3 =: monad define
  echo '=== Manual 3: Object value is a parsed JSON schema ==='
  schema =. dec_json '{"type":"object","properties":{"path":{"type":"string"}}}'
  obj =. ('name';'description';'parameters') ,: 'read';'Read file'; schema
  echo 'shape: ' , (": $ obj) , '  $$: ' , ": $$ obj
  echo 'schema type: ' , ": 3!:0 schema
  echo 'schema shape: ' , ": $ schema
  try. echo enc_json obj catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual4 =: monad define
  echo '=== Manual 4: Array of manually-built objects ==='
  o1 =. ('name';'desc') ,: 'read';'Read file'
  o2 =. ('name';'desc') ,: 'bash';'Run cmd'
  arr =. o1 ; o2
  echo 'shape: ' , (": $ arr) , '  $$: ' , ": $$ arr
  try. echo enc_json arr catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual5 =: monad define
  echo '=== Manual 5: Boxed list with < ==='
  o1 =. (<'read';'Read file';'{}')
  o2 =. (<'bash';'Run cmd';'{}')
  arr =. o1 , o2
  echo 'shape: ' , (": $ arr) , '  $$: ' , ": $$ arr
  echo 'item 0 shape: ' , (": $ > 0 { arr) , '  type: ' , ": 3!:0 > 0 { arr
  try. echo enc_json arr catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual6 =: monad define
  echo '=== Manual 6: Message object ==='
  msg =. ('role';'content') ,: 'user'; 'hello world'
  echo 'shape: ' , (": $ msg) , '  $$: ' , ": $$ msg
  try. echo enc_json msg catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual7 =: monad define
  echo '=== Manual 7: Array of message objects ==='
  m1 =. ('role';'content') ,: 'user'; 'hello'
  m2 =. ('role';'content') ,: 'assistant'; 'hi there'
  arr =. (< m1) , (< m2)
  echo 'shape: ' , (": $ arr) , '  $$: ' , ": $$ arr
  try. echo enc_json arr catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual8 =: monad define
  echo '=== Manual 8: Full payload-like structure ==='
  m1 =. ('role';'content') ,: 'user'; 'hello'
  msgs =. ,< m1
  schema =. dec_json '{"type":"object","properties":{"command":{"type":"string"}}}'
  tool_f =. ('name';'description';'parameters') ,: 'bash';'Run cmd'; schema
  tool =. ('type';'function') ,: 'function'; tool_f
  tools =. ,< tool
  payload =. ('model';'max_tokens';'tools';'messages') ,: 'test-model'; 4096; tools; msgs
  echo 'shape: ' , (": $ payload) , '  $$: ' , ": $$ payload
  try. echo enc_json payload catch. echo 'FAILED: ' , 13!:12 '' end.
)

test_manual1 ''
test_manual2 ''
test_manual3 ''
test_manual4 ''
test_manual5 ''
test_manual6 ''
test_manual7 ''
test_manual8 ''
echo '=== All manual tests done ==='
