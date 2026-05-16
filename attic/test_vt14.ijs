NB. Test: tui_run step by step with debug
load 'tui2.ijs'

U =: unxlib 'c'

out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)

ESC =: 27{a.
CSI =: ESC,'['

test =: monad define
  NB. Manually do what tui_run does, with debug output
  'TUI_LINES TUI_COLS' =: gethw_vt_''
  raw_vt_ 1
  out (CSI,'2J'),(CSI,'H')
  out (CSI,'38;5;7m'),'Step 1: init done',CR,LF
  
  echo =: tui_echo
  out (CSI,'38;5;2m'),'Step 2: echo redirected',CR,LF
  
  'prompt' tui_print 'Step 3: welcome line'
  tui_print ''
  out (CSI,'0m'),'Step 4: about to redraw',CR,LF
  
  try.
    tui_redraw ''
    out (CSI,'38;5;2m'),'Step 5: redraw succeeded',CR,LF
  catch.
    out (CSI,'38;5;1m'),'Step 5: redraw FAILED: ',(13!:12''),CR,LF
  end.
  
  out (CSI,'0m'),'Step 6: entering main loop, press q to quit',CR,LF
  TUI_RUNNING =: 1
  
  while. TUI_RUNNING do.
    out (CSI,'38;5;3m'),'about to call tui_in...',CR,LF
    k =. tui_in ''
    out 'Got key: ',(": k),CR,LF
    tui_handle_key k
  end.
  
  tui_cleanup ''
)

test ''
