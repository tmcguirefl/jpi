NB. Tests for utils.ijs
NB. test_utils.ijs
NB.
NB. Run from src/:  jconsole < ../tests/test_utils.ijs

load 'utils.ijs'

PASS =: 0
FAIL =: 0

check =: monad define
  if. y do.
    PASS =: >: PASS
  else.
    FAIL =: >: FAIL
    echo '  FAIL'
  end.
)

report =: monad define
  echo ''
  echo 'Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed'
  if. FAIL > 0 do.
    echo 'TESTS FAILED'
  else.
    echo 'ALL TESTS PASSED'
  end.
)

echo '=== human_size ==='
echo '  human_size 0'
check '0 B' -: human_size 0
echo '  human_size 512'
check '512 B' -: human_size 512
echo '  human_size 1024'
check '1 KB' -: human_size 1024
echo '  human_size 1536'
check '1.5 KB' -: human_size 1536
echo '  human_size 1048576'
check '1 MB' -: human_size 1048576
echo '  human_size 3355443'
check '3.2 MB' -: human_size 3355443
echo '  human_size 2147483648'
check '2 GB' -: human_size 2147483648

echo '=== truncate_mid ==='
echo '  truncate short (no-op)'
check 'hello' -: truncate_mid ('hello' ; 10)
echo '  truncate exact fit'
check 'hello' -: truncate_mid ('hello' ; 5)
echo '  truncate long'
check 'he...rld' -: truncate_mid ('hello world' ; 8)
echo '  truncate width 3 (too small)'
check 'hel' -: truncate_mid ('hello' ; 3)
echo '  truncate width 4'
check '...o' -: truncate_mid ('hello' ; 4)

echo '=== truncate_right ==='
echo '  tr short (no-op)'
check 'hello' -: truncate_right ('hello' ; 10)
echo '  tr exact fit'
check 'hello' -: truncate_right ('hello' ; 5)
echo '  tr long'
check 'hello...' -: truncate_right ('hello world' ; 8)
echo '  tr width 3 (too small)'
check 'hel' -: truncate_right ('hello' ; 3)

echo '=== pad_right ==='
echo '  pad short'
check 'hi   ' -: pad_right ('hi' ; 5)
echo '  pad exact'
check 'hello' -: pad_right ('hello' ; 5)
echo '  pad no-op (already long)'
check 'hello world' -: pad_right ('hello world' ; 5)
echo '  pad empty to zero'
check '' -: pad_right ('' ; 0)

echo '=== count_lines ==='
echo '  count empty string'
check 0 = count_lines ''
echo '  count single line (no LF)'
check 1 = count_lines 'hello'
echo '  count two lines'
check 2 = count_lines 'a' , LF , 'b'
echo '  count two lines with trailing LF'
check 2 = count_lines 'a' , LF , 'b' , LF
echo '  count three lines'
check 3 = count_lines 'a' , LF , 'b' , LF , 'c'

echo '=== split_lines ==='
echo '  split empty'
check (0 $ <'') -: split_lines ''
echo '  split single line'
check (,: < 'hello') -: split_lines 'hello'
echo '  split two lines'
check ('aa';'bb') -: split_lines 'aa' , LF , 'bb'
echo '  split two lines trailing LF'
check ('aa';'bb') -: split_lines 'aa' , LF , 'bb' , LF
echo '  split three lines'
check ('aa';'bb';'cc') -: split_lines 'aa' , LF , 'bb' , LF , 'cc'

echo '=== strip_ansi ==='
echo '  plain string unchanged'
check 'hello' -: strip_ansi 'hello'
echo '  sgr sequence removed'
check 'ab' -: strip_ansi 'a' , (27 { a.) , '[38;5;6mb'
echo '  multiple sequences removed'
check 'xy' -: strip_ansi ((27 { a.) , '[1mx') , ((27 { a.) , '[0my')

echo '=== vis_len ==='
echo '  ascii length'
check 5 = vis_len 'hello'
echo '  escapes have zero width'
check 2 = vis_len 'a' , (27 { a.) , '[38;5;6m' , 'b'
echo '  utf8 codepoints counted, not bytes'
box =. 'a' , (226 148 128 { a.) , 'b'
check 5 = #box
check 3 = vis_len box
echo '  utf8 and escapes together'
check 3 = vis_len 'a' , (27 { a.) , '[1m' , (226 148 128 { a.) , 'b'

echo '=== wrap_utf8 ==='
echo '  short line unchanged, single row'
check (,: < 'abc') -: 10 wrap_utf8 'abc'
echo '  empty input one empty row'
check (,: < '') -: 10 wrap_utf8 ''
echo '  ascii chunking'
check ('abcde';'fgh') -: 5 wrap_utf8 'abcdefgh'
echo '  exact multiple no empty tail'
check ('abcde';'fghij') -: 5 wrap_utf8 'abcdefghij'
echo '  join invariant (ascii)'
check 'abcdefgh' -: ; 5 wrap_utf8 'abcdefgh'
echo '  utf8 codepoint never split'
NB. 'x' box(3 bytes) 'yyyyy' at width 2: 'x'+box fits exactly, then 'yy','yy','y'
NB. NB. single chars are scalars in J — ravel expected items to lists.
check (('x' , (226 148 128 { a.)) ; 'yy' ; 'yy' ; (, 'y')) -: 2 wrap_utf8 'x' , (226 148 128 { a.) , 'yyyyy'
echo '  utf8 join invariant'
w =. 'x' , (226 148 128 { a.) , 'y'
check w -: ; 2 wrap_utf8 w
echo '  escape never split, zero width'
NB. 4 visible chars + escape at width 2: escape rides at end of a full row
s =. 'ab' , (27 { a.) , '[1m' , 'cd'
check 4 = vis_len s
check (('ab' , (27 { a.) , '[1m') ; 'cd') -: 2 wrap_utf8 s
echo '  escape at row start keeps color state'
s2 =. (27 { a.) , '[38;5;6m' , 'abc'
check (((27 { a.) , '[38;5;6mab') ; (, 'c')) -: 2 wrap_utf8 s2
check s2 -: ; 2 wrap_utf8 s2
echo '  rows respect width bound'
check *./ 2 >: vis_len&> 2 wrap_utf8 'abcdefghijk'
check *./ 79 >: vis_len&> 79 wrap_utf8 (300 # 'q') , (27 { a.) , '[1m' , (226 148 128 { a.)

report ''
