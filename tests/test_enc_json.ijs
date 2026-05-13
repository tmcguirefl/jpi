NB. Test cases for enc_json round-trip failures
require 'convert/json'

NB. Test helper: try enc_json, catch errors
test_rt =: monad define
  echo 'round-trip: ' , enc_json y
)

NB. ----------------------------------------------------------------
echo '=== Test 1: Simple object ==='
j1 =: '{"name":"test","value":42}'
p1 =: dec_json j1
echo 'shape: ' , (": $ p1) , '  $$: ' , ": $$ p1
echo enc_json p1
echo ''

echo '=== Test 2: Array of strings ==='
j2 =: '["a","b","c"]'
p2 =: dec_json j2
echo 'shape: ' , (": $ p2) , '  $$: ' , ": $$ p2
echo enc_json p2
echo ''

echo '=== Test 3: Array of objects ==='
j3 =: '[{"name":"read"},{"name":"write"}]'
p3 =: dec_json j3
echo 'shape: ' , (": $ p3) , '  $$: ' , ": $$ p3
echo 'item 0 shape: ' , (": $ > 0 { p3) , '  $$: ' , ": $$ > 0 { p3
echo 'item 0 type:  ' , ": 3!:0 > 0 { p3
echo ''

echo '=== Test 4: Nested object ==='
j4 =: '{"func":{"name":"read","desc":"Read file"},"type":"function"}'
p4 =: dec_json j4
echo 'shape: ' , (": $ p4) , '  $$: ' , ": $$ p4
echo ''

echo '=== Test 5: Object with array value ==='
j5 =: '{"items":[1,2,3],"name":"test"}'
p5 =: dec_json j5
echo 'shape: ' , (": $ p5) , '  $$: ' , ": $$ p5
echo ''

echo '=== Test 6: Object with null ==='
j6 =: '{"role":"assistant","content":null}'
p6 =: dec_json j6
echo 'shape: ' , (": $ p6) , '  $$: ' , ": $$ p6
echo 'content value: ' , ": > 'content' gethash_json p6
echo 'content type:  ' , ": 3!:0 > 'content' gethash_json p6
echo ''

echo '=== Test 7: Complex nested (tool_calls) ==='
j7 =: '{"role":"assistant","content":null,"tool_calls":[{"id":"call_123","type":"function","function":{"name":"bash","arguments":"{\"command\":\"ls\"}"}}]}'
p7 =: dec_json j7
echo 'shape: ' , (": $ p7) , '  $$: ' , ": $$ p7
echo ''

echo '=== Now test enc_json on each ==='

echo 'Test 1 enc: ' , enc_json p1
echo 'Test 2 enc: ' , enc_json p2
echo ''
