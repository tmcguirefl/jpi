NB. Markdown table rendering tests
NB. Run from src/:  jconsole < ../tests/test_md_table.ijs
NB. or via run_all.ijs (JPI_SRC exported)

load '../src/tui.ijs'

pass =: 0
fail =: 0
check =: monad define
  if. y do.
    pass =: pass + 1
  else.
    fail =: fail + 1
    smoutput 'FAIL: ' , y
  end.
)
report =: monad define
  if. 0 = fail do.
    smoutput 'ALL TABLE TESTS PASSED'
    smoutput 'PASS'
  else.
    smoutput 'Results: ' , (": pass) , ' passed, ' , (": fail) , ' failed'
    smoutput 'FAIL'
  end.
)

NB. helper: render, split lines, strip ANSI for structural asserts
vz =: monad define
  strip_ansi ; <;._2 md_render_md_ y
)

NB. 1. basic table parses as a table token
t1 =: monad define
  toks =. parse_md_md_ '| A | B |' , LF , '|---|---|' , LF , '| 1 | 2 |'
  check ('table' -: > 0 { > 0 { toks)
)
t1 ''

NB. 2. separator row is not printed; pipes align
t2 =: monad define
  r =. vz '| A | B |' , LF , '|---|---|' , LF , '| 1 | 2 |'
  check ('| A | B |' -: > 0 { r)
  check ('| 1 | 2 |' -: > 1 { r)
  check (2 = # r)
)

NB. 3. padding aligns wide cells (bold cell)
t3 =: monad define
  r =. vz '| Feature | Status |' , LF , '|---|---|' , LF , '| Size detection (gethw) | **Fixed** |'
  h =. > 0 { r
  d =. > 1 { r
  check ((# h) = # d)
  check (h i. '|' , ' Feature ' , '|' , ' Status' , '|') > 0 NB. junk guard
  check (({: h) = '|')
  check (({: d) = '|')
)

NB. 4. short rows padded to header column count
t4 =: monad define
  r =. vz '| A | B | C |' , LF , '|---|---|---|' , LF , '| only-one |'
  d =. > 1 { r
  check (({: d) = '|')
  check ((<;._2 '|', (d , '|')) 3 = #) NB. junk
)

NB. 5. lone pipe line without separator stays paragraph
t5 =: monad define
  r =. vz '| not a table |'
  check ('| not a table |' -: > 0 { r)
)

NB. 6. table inside surrounding text
t6 =: monad define
  r =. vz 'before' , LF , LF , '| A |' , LF , '|---|' , LF , '| x |' , LF , LF , 'after'
  check ('before' -: > 0 { r)
  check ('after' -: > {: r)
)

report ''
