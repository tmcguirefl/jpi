NB. enc_json_fixed: improved JSON encoder
NB. enc_json_fixed.ijs
NB.
NB. Fixes over the standard convert/json enc_json:
NB. 1. Rank > 2 boxed arrays no longer crash (encoded as nested arrays)
NB. 2. Rank-2 tables with rows ~: 2 handled as arrays of arrays
NB. 3. Scalar boxes (rank 0) unwrapped and recursed into
NB. 4. Unknown types get string representation instead of crash
NB.
NB. The standard enc_json crashes (13!:8[3) on:
NB.   - Boxed arrays with rank > 2
NB.   - Rank-2 boxed arrays where first dimension is not 0 or 2
NB.
NB. Round-trips perfectly with dec_json on all tested JSON structures
NB. including nested objects, arrays of objects, null values, booleans,
NB. and complex tool_calls responses.
NB.
NB. IMPORTANT: when building JSON objects manually, always box nested
NB. objects/arrays with < before placing them as values:
NB.   WRONG:  ('key';'val') ,: 'a'; nested_obj    NB. rank 3!
NB.   RIGHT:  ('key';'val') ,: 'a'; < nested_obj   NB. rank 2
NB.   WRONG:  obj1 ; obj2                          NB. row-stacks!
NB.   RIGHT:  (<obj1) , (<obj2)                    NB. boxed list
NB.
NB. Drop-in replacement: after loading, enc_json_fixed can replace enc_json.

require 'convert/json'

NB. Use the existing jsonesc from the json locale
jsonesc_f =: jsonesc_json_

enc_json_fixed =: monad define
  NB. get the J datatype
  t =. 3!:0 y
  select. t
  case. 2;131072;262144 do.
    NB. string types (literal, utf8, utf16)
    if. y -: 'json_true' do. 'true'
    elseif. y -: 'json_false' do. 'false'
    elseif. y -: 'json_null' do. 'null'
    elseif. do.
      '"' , '"' ,~ jsonesc_f utf8^:(2~:t) , y
    end.
  case. 1;4;8 do.
    NB. numeric types (boolean, integer, float)
    ":!.17 {. , y
  case. 32 do.
    NB. boxed — could be array, object, or nested structure
    rank =. $$ y
    if. rank < 2 do.
      NB. rank 0 or 1: JSON array (or single boxed value)
      if. 0 = # y do.
        '[]'
      elseif. 0 = rank do.
        NB. rank 0 (scalar box): unwrap and recurse
        enc_json_fixed > y
      elseif. do.
        NB. rank 1: JSON array — encode each element
        s =. '['
        for_v. y do.
          s =. s , ',' ,~ enc_json_fixed > v
        end.
        ']' ,~ }: s
      end.
    elseif. rank = 2 do.
      NB. rank 2: JSON object if 2 rows, otherwise try as array of arrays
      rows =. {. $ y
      if. rows = 2 do.
        NB. 2 rows: treat as JSON object (row 0 = keys, row 1 = values)
        cols =. {: $ y
        if. 0 = cols do.
          '{}'
        else.
          s =. '{'
          for_i. i. cols do.
            NB. encode key (should be a string)
            key =. enc_json_fixed > (<0,i) { y
            NB. encode value — use > to unbox, handles nested objects
            val =. enc_json_fixed > (<1,i) { y
            s =. s , key , ':' , val , ','
          end.
          '}' ,~ }: s
        end.
      elseif. rows = 0 do.
        '{}'
      elseif. do.
        NB. rows ~: 2: treat as array of arrays (each row is an element)
        s =. '['
        for_i. i. rows do.
          s =. s , ',' ,~ enc_json_fixed i { y
        end.
        ']' ,~ }: s
      end.
    elseif. do.
      NB. rank > 2: reduce by encoding each cell along leading axis
      s =. '['
      for_i. i. {. $ y do.
        s =. s , ',' ,~ enc_json_fixed i { y
      end.
      ']' ,~ }: s
    end.
  case. do.
    NB. unknown type — try string representation
    '"' , '"' ,~ jsonesc_f ": y
  end.
)

NB. Install into z locale for global access
enc_json_fixed_z_ =: enc_json_fixed

echo 'enc_json_fixed loaded.'
