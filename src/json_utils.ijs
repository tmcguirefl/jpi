NB. JSON utilities
NB. json_utils.ijs
NB. Loads the standard J json addon (dec_json / enc_json)

require 'convert/json'

NB. Convenience wrappers using standard library verbs
NB. dec_json and enc_json are already in z-locale after require

NB. Build a key-value pair for JSON objects (2-row boxed matrix)
jkv =: monad define
  'k v' =. y
  (,< k) ,: ,< v
)

NB. Merge key-value pairs into a single JSON object
jmerge =: monad define
  r =. 0 2 $ <''
  for_p. y do.
    r =. r ,. > p
  end.
  r
)

echo 'json_utils loaded (dec_json / enc_json from convert/json).'
