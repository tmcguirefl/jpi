NB. test_enc_fixed_utf8.ijs
NB. Regression: UTF-8 mojibake in session save/load cycles.
NB.
NB. The stock jsonesc escapes EVERY byte >127 as \uXXXX; dec_json
NB. parses those escapes as CODEPOINTS (latin-1 chars), so each
NB. enc/dec cycle re-mangled UTF-8 (em dash E2 80 94 became
NB. C3 A2 C2 80 C2 94, then worse - the 'ÃÂ¢ÃÂ¢' spam in saved
NB. sessions). enc_json_fixed now uses jsonesc_u: bytes >127
NB. pass RAW, only C0 controls get \u00XX.

require 'convert/json'
NB. resolve src dir relative to this test file's parent's parent
NB. (tests/ sits beside src/ in the repo layout)
SRCPATH =. (1!:43 '') , (('/' -.@-: {: 1!:43 '') # '/')
load '../src/enc_json_fixed.ijs'

check =: 3 : 0
  if. y do. 'PASS' else. 'FAIL' end.
)

NB. roundtrip once through enc/dec
rt =: 3 : 0
  line =. '{"role":"assistant","content":' , (enc_json_fixed y) , '}'
  > 'content' gethash_json dec_json line
)

NB. N enc/dec cycles (must stay byte-identical)
cycles =: 4 : 0
  cur =. y
  r =. 0
  while. r < x do.
    cur =. rt cur
    r =. r + 1
  end.
  cur
)

em    =. a. {~ 226 128 148
arrow =. a. {~ 226 134 146
nb    =. a. {~ 194 183
s1 =. 'Fix ' , em , ' follow-mode (' , nb , ' pinned) ' , arrow , ' done'

NB. T1: single roundtrip preserves UTF-8 bytes
r1 =. rt s1
smoutput 'T1 single roundtrip: ' , check r1 -: s1

NB. T2: 6 cycles byte-identical (old code mangled from cycle 2)
r2 =. 6 cycles s1
smoutput 'T2 6-cycle stability: ' , check r2 -: s1

NB. T3: mixed content: quotes, backslash, LF, TAB, C0 control, DEL
s2 =. 'ctrl ' , (a. {~ 1) , ' back\\slash "q" tab' , (a. {~ 9) , 'lf' , (a. {~ 10) , 'del' , (a. {~ 127) , ' ' , em
r3 =. rt s2
smoutput 'T3 controls+utf8 roundtrip: ' , check r3 -: s2

NB. T4: sentinels still encode as bare literals
r4 =. (enc_json_fixed 'json_true') , ' ' , (enc_json_fixed 'json_false') , ' ' , (enc_json_fixed 'json_null')
smoutput 'T4 sentinels: ' , check r4 -: 'true false null'

NB. T5: boxed table + numbers unaffected
r5 =. (enc_json_fixed 'role' ; 'content')
smoutput 'T5 table: ' , check r5 -: '["role","content"]'
r6 =. enc_json_fixed 42
smoutput 'T6 int: ' , check r6 -: '42'

NB. T7: empty string decodes via gethash to a boxed empty NUMERIC
NB. (json addon quirk: '' inside a hash opens as type-1 empty);
NB. the OLD encoder had the same quirk, so assert no BYTES appear
NB. and the non-empty path (T1-T6) is what matters for mojibake.
r7 =. rt ''
t7 =. 0 = # , > r7
smoutput 'T7 empty: ' , check t7

smoutput 'DONE test_enc_fixed_utf8'
exit 0
