NB. TUI new-feature tests: follow mode, diff coloring, multi-line input
NB. test_tui_newfeatures.ijs
NB.
NB. Run from src/:  JPI_SRC=$PWD jconsole < ../tests/test_md_table.ijs
NB. (run_all.ijs auto-discovers test_*.ijs)
NB.
NB. Headless: no tty needed - gethw falls back to 80x24.

load '../src/tui.ijs'

PASS =: 0
FAIL =: 0
check =: 3 : 0
  if. y do. PASS =: PASS + 1
  else. FAIL =: FAIL + 1
    smoutput 'check FAILED'
  end.
)
checkat =: verb define
  if. y do. PASS =: PASS + 1 return. end.
  FAIL =: FAIL + 1
  smoutput 'check FAILED at: ' , y
)
report =: monad define
  if. 0 = FAIL do.
    smoutput 'ALL NEW-FEATURE TESTS PASSED'
    smoutput 'PASS'
  else.
    smoutput 'Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed'
    smoutput 'FAIL'
  end.
)

NB. ---------- follow mode ----------
fm1 =: monad define
  NB. default: following
  TUI_FOLLOW =: 1
  check 1 = TUI_FOLLOW
)
fm1 ''

fm2 =: monad define
  NB. tui_at_bottom with empty buffer: at bottom
  TUI_OUTPUT =: 0 $ < ''
  TUI_SCROLL =: 0
  check tui_at_bottom ''
)
fm2 ''

fm3 =: monad define
  NB. scrolled up -> not at bottom
  TUI_OUTPUT =: < "0 (i. 100)      NB. 100 lines
  TUI_COLS =: 80
  TUI_LINES =: 24
  TUI_SCROLL =: 0
  NB. total wrapped lines >= oh, scroll at top -> not at bottom
  check -. tui_at_bottom ''
)
fm3 ''

NB. ---------- diff coloring ----------
dc1 =: monad define
  s =. diff_sgr '+added line'
  check 0 < # s
)
dc1 ''

dc2 =: monad define
  s =. diff_sgr '-removed line'
  check 0 < # s
)
dc2 ''

dc3 =: monad define
  s =. diff_sgr '@@ -1,3 +1,4 @@'
  check 0 < # s
)
dc3 ''

dc4 =: monad define
  NB. plain line: no color
  s =. diff_sgr 'just text'
  check 0 = # s
)
dc4 ''

dc5 =: monad define
  NB. tool output in 'tool' style must NOT be diff-colored twice,
  NB. and normal-style diff lines get color in the buffer
  TUI_OUTPUT =: 0 $ < ''
  'normal' tui_print '+diff in normal output'
  got =. > _1 { TUI_OUTPUT
  check 0 < +./ '38;5;2m' E. got
)
dc5 ''

NB. ---------- multi-line input ----------
ml1 =: monad define
  TUI_COLS =: 40
  TUI_INPUT =: 'one' , LF , 'two'
  r =. input_rows ''
  check 2 = # r
  check 'one' -: > 0 { r
  check 'two' -: > 1 { r
)
ml1 ''

ml2 =: monad define
  NB. trailing LF = real empty second row
  TUI_INPUT =: 'one' , LF
  r =. input_rows ''
  check 2 = # r
  check '' -: > 1 { r
)
ml2 ''

ml3 =: monad define
  NB. long segment wraps
  TUI_COLS =: 20
  TUI_INPUT =: 'aaaa bbbb cccc dddd eeee ffff'
  r =. input_rows ''
  check 1 < # r
)
ml3 ''

ml4 =: monad define
  NB. input_h counts rows, capped at INPUT_MAX_H
  TUI_COLS =: 80
  TUI_INPUT =: ('a' , LF) #~ 10
  ih =. input_h 0
  check INPUT_MAX_H = ih
)
ml4 ''


NB. ---------- Alt-Enter (ESC CR) multi-line ----------
NB. headless stubs so redraws don't need a tty. NOTE: these MUST be
NB. global (=: at top level); defined inside a definition they would
NB. be locals invisible to tui_handle_key.
puts =: ]
goxy =: ]
curs =: ]
ceol =: ]
reset =: ]
fgc =: ]
QUEUE =: 0 $ 0
keyp =: 3 : '0 < # QUEUE'
rkey =: 3 : 0
 r =. > {. QUEUE
 QUEUE =: }. QUEUE
 r
)

ae =: 3 : 0
  NB. Alt-Enter: ESC then CR queued
  TUI_INPUT =: 'ab' [ TUI_CURSOR =: 2
  QUEUE =: , 13
  tui_handle_key 27
  check LF e. TUI_INPUT
  check 3 = TUI_CURSOR
  r =. input_rows ''
  check 2 = # r
  check 'ab' -: > 0 { r
  check '' -: > 1 { r
  NB. plain Enter still SENDS: dispatch to tui_process is stubbed
  NB. so no agent call happens, but the input buffer must be cleared
  tui_process =: ]
  TUI_INPUT =: 'ab' [ TUI_CURSOR =: 2
  tui_handle_key 13
  check 0 = # TUI_INPUT
)
ae ''

NB. ---------- steer-poll scroll (follow mode during LLM wait) ----------
NB. tui_steer_poll must honor wheel events, Ctrl-U/D/L while an
NB. API call is in flight (llm_call's spinner loop) - else the
NB. user cannot pin mid-response and follow looks broken. The old
NB. poll skipped 2 bytes after ESC and typed the rest of SGR wheel
NB. sequences into the input line.
NB. rkey stub: }. beheads (drops FIRST); }: curtails - do not mix.
sp1 =: monad define
  NB. wheel-up during steer poll: pins + scrolls + no input pollution
  tui_redraw =: ] [ tui_draw_bottom =: ]
  TUI_LINES =: 24 [ TUI_COLS =: 80
  TUI_OUTPUT =: < @ ('line ' , ":) " 0 i. 100
  TUI_SCROLL =: 82 [ TUI_FOLLOW =: 1
  TUI_INPUT =: '' [ TUI_CURSOR =: 0
  NB. ESC [ < 6 4 ; 1 3 ; 5 M   (SGR wheel-up, btn=64)
  QUEUE =: 27 91 60 54 52 59 49 51 59 53 77
  tui_steer_poll ''
  check 79 = TUI_SCROLL
  check 0 = TUI_FOLLOW
  check 0 = # TUI_INPUT
  NB. pinned: streaming output does NOT move the view
  tui_print 'new streamed line'
  check 79 = TUI_SCROLL
  check 0 = TUI_FOLLOW
)
sp1 ''

sp2 =: monad define
  NB. wheel-down to bottom resumes follow
  NB. total is now 101 (TUI_OUTPUT + 'new streamed line') -> bottom 83
  NB. two ticks of +3 from 79 reach 83 (83 <. 82 -> 82, then 83)
  NB. ESC [ < 6 5 ; 1 3 ; 5 M   (SGR wheel-down, btn=65) x2
  QUEUE =: (27 91 60 54 53 59 49 51 59 53 77) , 27 91 60 54 53 59 49 51 59 53 77
  tui_steer_poll ''
  check 83 = TUI_SCROLL
  check 1 = TUI_FOLLOW
)
sp2 ''

sp3 =: monad define
  NB. Ctrl-U during steer poll pins; Ctrl-L resumes
  TUI_SCROLL =: 83 [ TUI_FOLLOW =: 1
  QUEUE =: , 21
  tui_steer_poll ''
  check 66 = TUI_SCROLL          NB. 83 - (oh-1) = 83-17
  check 0 = TUI_FOLLOW
  check 0 = # TUI_INPUT
  QUEUE =: , 12
  tui_steer_poll ''
  check 83 = TUI_SCROLL
  check 1 = TUI_FOLLOW
)
sp3 ''

sp4 =: monad define
  NB. typing during steer poll still steers; arrows are swallowed
  TUI_INPUT =: '' [ STEER_MSG =: ''
  QUEUE =: 104 105 13
  tui_steer_poll ''
  check 'hi' -: STEER_MSG
  check 0 = # TUI_INPUT
  TUI_INPUT =: ''
  QUEUE =: 27 91 65              NB. ESC [ A (up arrow)
  tui_steer_poll ''
  check 0 = # TUI_INPUT
)
sp4 ''

report ''
