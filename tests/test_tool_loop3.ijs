NB. Minimal test of gethash_json on 2x1 table
require 'convert/json'

debug3 =: monad define
  args =. dec_json '{"command": "ls -la"}'
  echo 'args shape: ' , ": $ args
  echo 'args rank: ' , ": $$ args
  echo 'args type: ' , ": 3!:0 args
  echo ''
  NB. test gethash_json directly
  echo 'gethash result: ' , ": 'command' gethash_json args
  echo 'unboxed: ' , > 'command' gethash_json args
)

debug3 ''
