NB. Test: tui_run code step by step with debug after EVERY line
load 'tui2.ijs'

U =: unxlib 'c'
out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)
ESC =: 27{a.
CSI =: ESC,'['

debug =: monad define
  out (CSI,'38;5;2m'),y,(CSI,'0m'),CR,LF
)

test =: monad define
  debug 'A: about to call tui_init'
  tui_init ''
  debug 'B: tui_init done'

  echo =: tui_echo
  debug 'C: echo redirected'

  'prompt' tui_print 'J-PI Agent (TUI mode)'
  debug 'D: first print done'

  'muted' tui_print 'Type a question directly, or:'
  'muted' tui_print '  !cmd  shell    /cmd  agent    Ctrl+C exit'
  tui_print ''
  debug 'E: all prints done'

  debug 'F: about to call tui_redraw'
  try.
    tui_redraw ''
    debug 'G: tui_redraw succeeded'
  catch.
    debug 'G: tui_redraw FAILED: ',(13!:12'')
    tui_cleanup ''
    raw_vt_ 0
    return.
  end.

  debug 'H: entering loop'
  TUI_RUNNING =: 1
  while. TUI_RUNNING do.
    debug 'I: about to call tui_in'
    k =. tui_in ''
    debug 'J: got key ',(": k)
    tui_handle_key k
  end.

  tui_cleanup ''
)

test ''
