NB. TUI render-path tests: unwrapped storage + render-time wrap
NB. test_tui_render.ijs
NB.
NB. Run from src/:  JPI_SRC=$PWD jconsole < ../tests/test_tui_render.ijs
NB. (run_all.ijs exports JPI_SRC for subprocesses)
NB.
NB. Headless: no tty needed — gethw falls back to 80x24.

load '../src/tui.ijs'

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

W =. 79  NB. headless fallback width (TUI_COLS-1 at 80 cols)

echo '=== storage: unwrapped ==='
TUI_OUTPUT =: 0 $ <''
tui_print 200 # 'x'
check 1 = # TUI_OUTPUT
check 200 = vis_len > 0 { TUI_OUTPUT

echo '=== storage: multi-line ==='
TUI_OUTPUT =: 0 $ <''
tui_print 'one' , LF , 'two'
check 2 = # TUI_OUTPUT
check 'one' -: > 0 { TUI_OUTPUT
check 'two' -: > 1 { TUI_OUTPUT

echo '=== styles embedded at store time ==='
TUI_OUTPUT =: 0 $ <''
'error' tui_print 'boom'
check 'boom' -: strip_ansi > 0 { TUI_OUTPUT
check (CSI , '38;5;1m') -: (9 {. > 0 { TUI_OUTPUT)

echo '=== render: wrap at current width ==='
TUI_OUTPUT =: 0 $ <''
tui_print 100 # 'x'
rows =. tui_wrapped ''
check 2 = # rows
check *./ W >: vis_len&> rows
check (100 # 'x') -: ; rows

echo '=== render: utf8 line survives wrap ==='
TUI_OUTPUT =: 0 $ <''
box =. 'a' , (226 148 128 { a.) , 'b'
tui_print box
check box -: ; tui_wrapped ''
check 3 = vis_len > 0 { TUI_OUTPUT

echo '=== render: buffer cap ==='
NB. temporarily lower the cap to keep the test cheap
NB. (for. is definition-body-only, so the loop lives in a verb)
fill_lines =: monad define
  for_i. i. y do.
    tui_print 'line ' , (": i)
  end.
)
TUI_MAX_LINES =: 50
TUI_OUTPUT =: 0 $ <''
fill_lines 60
check 50 = # TUI_OUTPUT
check 'line 59' -: > _1 { TUI_OUTPUT
TUI_MAX_LINES =: 2000

echo '=== scroll: bottom clamp ==='
TUI_OUTPUT =: 0 $ <''
tui_print 1000 # 'z'
NB. ~13 wrapped rows, output pane ~19 rows headless: no scroll yet
check 0 = TUI_SCROLL

report ''
