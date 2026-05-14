NB. J-PI TUI — j-kvm based terminal interface (no ncurses)
NB. tui2.ijs
NB.
NB. Uses tangentstorm/j-kvm for direct ANSI terminal control.
NB. No ncurses dependency. Direct vt escape code output.

NB. Load the agent first (all echo output goes to normal stdout)
load 'agent.ijs'

NB. Load j-kvm (full package: vt + vid + kvm event loop)
require 'tangentstorm/j-kvm'
coinsert 'kvm'
load 'theme.ijs'

NB. ================================================================
NB. TUI state
TUI_LINES =: 0
TUI_COLS  =: 0
TUI_OUTPUT =: 0 $ <''      NB. all output lines (boxed)
TUI_SCROLL =: _1           NB. _1 = follow (auto-scroll to bottom)
TUI_INPUT  =: ''
TUI_CURSOR =: 0
TUI_HISTORY_IDX =: 0
TUI_INPUT_HISTORY =: 0 $ <''

NB. Layout
STATUS_H =: 1
INPUT_H  =: 1

NB. ================================================================
NB. Theme color helpers
NB. ncurses 0-7 colors map to same 256-color indices
NB. j-kvm fgc/bgc take 256-color index (neg) or 24-bit (pos)

NB. Apply fg/bg from theme element name — writes ANSI codes directly
theme_apply =: monad define
  'fg bg' =. theme_colors y
  fgc_vt_ fg
  bgc_vt_ bg
)

NB. ================================================================
NB. Initialize TUI
tui_init =: monad define
  'TUI_LINES TUI_COLS' =. gethw_vt_''
  raw_vt_ 1
  curs_vt_ 0
  cscr_vt_''
)

NB. ================================================================
NB. Handle terminal resize
tui_resize =: monad define
  'TUI_LINES TUI_COLS' =. gethw_vt_''
  cscr_vt_''
  tui_redraw_all ''
)

NB. ================================================================
NB. Wrap a long line into multiple lines of at most w characters
wrap_line =: dyad define
  if. x >: #y do. ,< y return. end.
  r =. 0 $ <''
  while. x < #y do.
    r =. r , < x {. y
    y =. x }. y
  end.
  r , < y
)

NB. ================================================================
NB. Draw the complete screen from TUI_OUTPUT
tui_redraw_all =: monad define
  cscr_vt_''
  out_h =. TUI_LINES - STATUS_H + INPUT_H
  total =. #TUI_OUTPUT
  
  NB. Determine visible range
  if. (TUI_SCROLL = _1) +. (TUI_SCROLL + out_h) >: total do.
    start =. 0 >. total - out_h
    TUI_SCROLL =: _1
  else.
    start =. 0 >. TUI_SCROLL
  end.
  visible =. out_h {. start }. TUI_OUTPUT
  
  NB. Draw output lines (CR+LF in raw mode — LF alone won't carriage-return)
  reset_vt_''
  for_l. visible do.
    puts_vt_ > l
    puts_vt_ CR,LF
  end.
  
  NB. Draw status bar
  goxy_vt_ 0 , out_h
  theme_apply 'status'
  left =. ' J-PI | ' , MODEL
  branch =. git_branch ''
  right =. ''
  if. 0 < TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS do.
    right =. right , (": TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS) , ' tok'
  end.
  if. 0 < #branch do.
    right =. right , ' | ' , branch
  end.
  right =. right , ' | ' , (": #HISTORY) , ' msgs '
  pad =. (TUI_COLS - (#left) + #right) # ' '
  puts_vt_ left , pad , right
  
  NB. Draw input line
  goxy_vt_ 0 , (out_h + STATUS_H)
  reset_vt_''
  theme_apply 'prompt'
  puts_vt_ '> '
  reset_vt_''
  puts_vt_ TUI_INPUT
  
  NB. Position cursor
  goxy_vt_ (2 + TUI_CURSOR) , (out_h + STATUS_H)
  curs_vt_ 1
)

NB. ================================================================
NB. Add a line to the output buffer and redraw
NB. x = theme element name (default 'normal'), y = text string
tui_print =: verb define
  'normal' tui_print y
:
  wrapped =. (TUI_COLS - 1) wrap_line y
  TUI_OUTPUT =: TUI_OUTPUT , wrapped
  NB. If following mode, snap to bottom
  if. TUI_SCROLL = _1 do. EMPTY return. end.
  TUI_SCROLL =: _1
  EMPTY
)

NB. ================================================================
NB. Route echo output to TUI with color hints
tui_echo =: monad define
  lines =. <;._2 y , LF -. {: y , LF
  for_l. lines do.
    line =. > l
    if. 'Tool call:' +./@E. line do.
      'tool' tui_print line
    elseif. 'ERROR' +./@E. line do.
      'error' tui_print line
    elseif. 'Asking LLM' +./@E. line do.
      'muted' tui_print line
    elseif. '  [' +./@E. line do.
      'muted' tui_print line
    elseif. do.
      tui_print line
    end.
  end.
)

NB. ================================================================
NB. Process a command
tui_process =: monad define
  if. 0 = #y do. return. end.
  TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , < y
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
  if. '/' = {. y do.
    cmd =. }. y
    'prompt' tui_print '/ ' , cmd
    if. cmd -: 'exit' do. return. end.
    agent cmd
  elseif. '!' = {. y do.
    cmd =. }. y
    'prompt' tui_print '! ' , cmd
    agent 'run ' , cmd
  elseif. do.
    'prompt' tui_print '> ' , y
    agent 'ask ' , y
  end.
)

NB. ================================================================
NB. Key handlers — in base locale for kvm's onkey dispatch
NB. y is the key event (boxed integer from rkey)

NB. Enter: LF is Ctrl+J (ascii 10), CR is Ctrl+M (ascii 13)
kc_j =: monad define
  cmd =. TUI_INPUT
  TUI_INPUT =: ''
  TUI_CURSOR =: 0
  if. (cmd -: 'exit') +. cmd -: '/exit' do.
    break_kvm_ =: 1
    return.
  end.
  tui_process cmd
  tui_redraw_all ''
)

kc_m =: kc_j  NB. CR same as LF

NB. Backspace (DEL=127)
k_bsp =: monad define
  if. 0 < TUI_CURSOR do.
    TUI_INPUT =: ((TUI_CURSOR - 1) {. TUI_INPUT) , (TUI_CURSOR }. TUI_INPUT)
    TUI_CURSOR =: TUI_CURSOR - 1
    tui_redraw_all ''
  end.
)

NB. Printable ASCII
k_asc =: monad define
  ch =. a.{~ {.> y
  TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ch , (TUI_CURSOR }. TUI_INPUT)
  TUI_CURSOR =: TUI_CURSOR + 1
  tui_redraw_all ''
)

NB. Arrow keys
k_arlf =: monad define
  if. 0 < TUI_CURSOR do.
    TUI_CURSOR =: TUI_CURSOR - 1
    tui_redraw_all ''
  end.
)

k_arrt =: monad define
  if. TUI_CURSOR < #TUI_INPUT do.
    TUI_CURSOR =: TUI_CURSOR + 1
    tui_redraw_all ''
  end.
)

k_arup =: monad define
  if. 0 < TUI_HISTORY_IDX do.
    TUI_HISTORY_IDX =: TUI_HISTORY_IDX - 1
    TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
    TUI_CURSOR =: #TUI_INPUT
    tui_redraw_all ''
  end.
)

k_ardn =: monad define
  if. TUI_HISTORY_IDX < (#TUI_INPUT_HISTORY) - 1 do.
    TUI_HISTORY_IDX =: TUI_HISTORY_IDX + 1
    TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
    TUI_CURSOR =: #TUI_INPUT
  else.
    TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
    TUI_INPUT =: ''
    TUI_CURSOR =: 0
  end.
  tui_redraw_all ''
)

NB. Ctrl+U — page up
kc_u =: monad define
  out_h =. TUI_LINES - STATUS_H + INPUT_H
  if. TUI_SCROLL = _1 do.
    TUI_SCROLL =: 0 >. (#TUI_OUTPUT) - out_h
  end.
  TUI_SCROLL =: 0 >. TUI_SCROLL - (out_h - 1)
  tui_redraw_all ''
)

NB. Ctrl+D — page down
kc_d =: monad define
  out_h =. TUI_LINES - STATUS_H + INPUT_H
  if. TUI_SCROLL ~: _1 do.
    TUI_SCROLL =: TUI_SCROLL + (out_h - 1)
    if. (TUI_SCROLL + out_h) >: #TUI_OUTPUT do.
      TUI_SCROLL =: _1
    end.
    tui_redraw_all ''
  end.
)

NB. Page Up/Down (xterm codes)
k_pgup =: kc_u
k_pgdn =: kc_d

NB. Home/End
k_home =: monad define
  TUI_CURSOR =: 0
  tui_redraw_all ''
)

k_end =: monad define
  TUI_CURSOR =: #TUI_INPUT
  tui_redraw_all ''
)

NB. Delete
k_del =: monad define
  if. TUI_CURSOR < #TUI_INPUT do.
    TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ((TUI_CURSOR + 1) }. TUI_INPUT)
    tui_redraw_all ''
  end.
)

NB. Escape / Ctrl+C — exit
k_esc =: monad define
  break_kvm_ =: 1
)

kc_c =: monad define
  break_kvm_ =: 1
)

NB. ================================================================
NB. Main TUI loop
tui_run =: monad define
  tui_init ''
NB. ================================================================
NB. Kvm event loop hooks (top-level so loop_kvm_ can find them by name)

NB. Tick handler — runs every loop iteration
tui_step =: monad define
  EMPTY
)

NB. Init hook — called by kvm loop on start
kvm_init =: monad define
  EMPTY
)

NB. Cleanup — called by kvm loop on exit
kvm_done =: monad define
  curs_vt_ 1
  raw_vt_ 0
  reset_vt_ ''
  echo ''
)

NB. ================================================================
NB. Main TUI loop
tui_run =: monad define
  tui_init ''
  echo =: tui_echo
  
  'prompt' tui_print 'J-PI Agent (TUI mode)'
  'muted' tui_print 'Type a question directly, or:'
  'muted' tui_print '  !cmd  run a shell command    /cmd  agent commands'
  'muted' tui_print '  /read /edit /write /git /grep /find /model /theme /stream /usage /save /load /clear /exit'
  tui_print ''
  tui_redraw_all ''
  
  tui_step loop_kvm_ 'base'
)

echo 'tui2 loaded.'
