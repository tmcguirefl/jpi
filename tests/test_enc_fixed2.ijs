NB. Test enc_json_fixed on structures built WITHOUT manual < boxing
NB. These are the cases that crash standard enc_json
require 'convert/json'
load '../src/enc_json_fixed.ijs'

test_nobox =: monad define
  echo '--- No-box test: object with object value (rank 3 input) ---'
  inner =. ('name';'desc') ,: 'read';'Read file'
  outer =. ('type';'function') ,: 'function'; inner   NB. NO < boxing
  echo '  shape: ' , (": $ outer) , '  $$: ' , ": $$ outer
  r =. enc_json_fixed outer
  echo '  out: ' , r
  echo ''
)

test_nobox2 =: monad define
  echo '--- No-box test 2: object with parsed schema value ---'
  schema =. dec_json '{"type":"object","properties":{"path":{"type":"string"}}}'
  obj =. ('name';'parameters') ,: 'read'; schema   NB. NO < boxing
  echo '  shape: ' , (": $ obj) , '  $$: ' , ": $$ obj
  r =. enc_json_fixed obj
  echo '  out: ' , r
  echo ''
)

test_nobox3 =: monad define
  echo '--- No-box test 3: semicolon join of objects (row stacking) ---'
  o1 =. ('name';'desc') ,: 'read';'Read file'
  o2 =. ('name';'desc') ,: 'bash';'Run cmd'
  arr =. o1 ; o2   NB. this creates a 3x2 table, not a list of 2 objects
  echo '  shape: ' , (": $ arr) , '  $$: ' , ": $$ arr
  r =. enc_json_fixed arr
  echo '  out: ' , r
  echo ''
)

test_nobox ''
test_nobox2 ''
test_nobox3 ''
echo '=== Done ==='
