NB. Isolated enc_json failure tests (each in a monad for try/catch)
require 'convert/json'

test3 =: monad define
  echo '=== Test 3: Array of objects ==='
  p =. dec_json '[{"name":"read"},{"name":"write"}]'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 3: ' , 13!:12 '' end.
)

test4 =: monad define
  echo '=== Test 4: Nested object ==='
  p =. dec_json '{"func":{"name":"read","desc":"Read file"},"type":"function"}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 4: ' , 13!:12 '' end.
)

test5 =: monad define
  echo '=== Test 5: Object with array value ==='
  p =. dec_json '{"items":[1,2,3],"name":"test"}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 5: ' , 13!:12 '' end.
)

test6 =: monad define
  echo '=== Test 6: Object with null ==='
  p =. dec_json '{"role":"assistant","content":null}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 6: ' , 13!:12 '' end.
)

test7 =: monad define
  echo '=== Test 7: Complex nested (tool_calls) ==='
  p =. dec_json '{"role":"assistant","content":null,"tool_calls":[{"id":"call_123","type":"function","function":{"name":"bash","arguments":"{\"command\":\"ls\"}"}}]}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 7: ' , 13!:12 '' end.
)

test8 =: monad define
  echo '=== Test 8: Array of mixed objects ==='
  p =. dec_json '[{"role":"user","content":"hello"},{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"bash","arguments":"{\"command\":\"ls\"}"}}]}]'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 8: ' , 13!:12 '' end.
)

test9 =: monad define
  echo '=== Test 9: Boolean values ==='
  p =. dec_json '{"active":true,"deleted":false}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 9: ' , 13!:12 '' end.
)

test10 =: monad define
  echo '=== Test 10: Deeply nested ==='
  p =. dec_json '{"a":{"b":{"c":{"d":"deep"}}}}'
  echo 'shape: ' , (": $ p) , '  $$: ' , ": $$ p
  try. echo enc_json p catch. echo 'FAILED test 10: ' , 13!:12 '' end.
)

test3 ''
test4 ''
test5 ''
test6 ''
test7 ''
test8 ''
test9 ''
test10 ''
echo '=== All tests done ==='
