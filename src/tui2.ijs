NB. J-PI TUI — j-kvm based terminal interface (no ncurses)
NB. tui2.ijs
NB.
NB. Uses tangentstorm/j-kvm/vt for direct ANSI terminal control.
NB. Own simple event loop — no kvm loop adverb complexity.
NB. No ncurses dependency.

NB. Load the agent first (all echo output goes to normal stdout)
load 'agent.ijs'

NB. Load j-kvm vt (ANSI escape codes + raw input)
require 'tangentstorm/j-kvm/vt'
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
TUI_RUNNING =: 1

NB. Layout
STATUS_H =: 1
INPUT_H  =: 1

NB. ================================================================
NB. Theme color helpers
theme_apply =: monad define
  'fg bg' =. theme_colors y
  fgc_vt_ -fg
  bgc_vt_ -bg
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
NB. Restore terminal on exit (critical!)
tui_cleanup =: monad define
  curs_vt_ 1
  raw_vt_ 0
  reset_vt_''
  puts_vt_ CR,LF
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
NB. Draw a single line at a specific row, clearing it first
NB. x = (col, row), y = text
tui_draw_line =: dyad define
  'col row' =. x
  goxy_vt_ col , row
  ceol_vt_''
  puts_vt_ y
)

NB. ================================================================
NB. Draw the complete screen
tui_redraw =: monad define
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
  
  NB. Draw each output line at its row — use goxy, never rely on cursor advancement
  reset_vt_''
  for_i. i. #visible do.
    (0 , i) tui_draw_line > i { visible
  end.
  
  NB. Clear remaining output rows
  for_i. (#visible) + i. out_h - #visible do.
    (0 , i) tui_draw_line ''
  end.
  
  NB. Draw status bar at row out_h
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
  NB. fill remainder of status row
  remains =. TUI_COLS - #left - #pad - #right
  if. remains > 0 do. puts_vt_ remains # ' ' end.
  
  NB. Draw input line at row (out_h + STATUS_H)
  goxy_vt_ 0 , (out_h + STATUS_H)
  reset_vt_''
  theme_apply 'prompt'
  puts_vt_ '> '
  reset_vt_''
  puts_vt_ TUI_INPUT
  ceol_vt_''                              NB. clear after input text
  
  NB. Position cursor in input line
  goxy_vt_ (2 + TUI_CURSOR) , (out_h + STATUS_H)
  curs_vt_ 1
)

NB. ================================================================
NB. Add a line to the output buffer
NB. x = theme element name (default 'normal'), y = text string
tui_print =: verb define
  'normal' tui_print y
:
  wrapped =. (TUI_COLS - 1) wrap_line y
  TUI_OUTPUT =: TUI_OUTPUT , wrapped
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
NB. Keyboard input — read from fd 0 (stdin) since rkey_vt_ uses fd 1 (broken on macOS)
NB. We also need a non-blocking keyp that works outside the kvm event loop.

NB. libc handles
TUI_LIBC =: unxlib 'c'

NB. Non-blocking check: set stdin non-blocking, poll, restore
TUI_F_SETFL =: 4
TUI_O_NONBLOCK =: 4
TUI_POLLIN =: 1

tui_keyp =: monad define
  NB. y = timeout in ms
  'TUI_LIBC fcntl i i i i'&cd (0 , TUI_F_SETFL , TUI_O_NONBLOCK)
  NB. poll stdin with timeout
  pollfd =. , (0 , TUI_POLLIN) , 0
  r =. ('TUI_LIBC poll i *l i i')&cd (pollfd ; 1 ; y)
  NB. restore blocking
  ('TUI_LIBC fcntl i i i i')&cd (0 , TUI_F_SETFL , 0)
  0 ~: _48 (33 b.) 1 {:: r
)

tui_rkey =: monad define
  NB. Read one byte from fd 0 (stdin)
  buf =. (,0){a.
  res =. ('TUI_LIBC read l i *c l')&cd (0 ; buf ; 1)
  a. i. 0 { 2 {:: res
)
tui_handle_key =: monad define
  k =. y
  
  NB. Enter: LF=10 or CR=13
  if. k e. 10 13 do.
    cmd =. TUI_INPUT
    TUI_INPUT =: ''
    TUI_CURSOR =: 0
    if. (cmd -: 'exit') +. cmd -: '/exit' do.
      TUI_RUNNING =: 0
      return.
    end.
    tui_process cmd
    tui_redraw ''
    return.
  end.
  
  NB. Backspace: DEL=127, BS=8
  if. k e. 127 8 do.
    if. 0 < TUI_CURSOR do.
      TUI_INPUT =: ((TUI_CURSOR - 1) {. TUI_INPUT) , (TUI_CURSOR }. TUI_INPUT)
      TUI_CURSOR =: TUI_CURSOR - 1
      tui_redraw ''
    end.
    return.
  end.
  
  NB. Ctrl+C: ETX=3
  if. 3 = k do.
    TUI_RUNNING =: 0
    return.
  end.
  
  NB. Ctrl+U: page up (21)
  if. 21 = k do.
    out_h =. TUI_LINES - STATUS_H + INPUT_H
    if. TUI_SCROLL = _1 do.
      TUI_SCROLL =: 0 >. (#TUI_OUTPUT) - out_h
    end.
    TUI_SCROLL =: 0 >. TUI_SCROLL - (out_h - 1)
    tui_redraw ''
    return.
  end.
  
  NB. Ctrl+D: page down (4)
  if. 4 = k do.
    out_h =. TUI_LINES - STATUS_H + INPUT_H
    if. TUI_SCROLL ~: _1 do.
      TUI_SCROLL =: TUI_SCROLL + (out_h - 1)
      if. (TUI_SCROLL + out_h) >: #TUI_OUTPUT do.
        TUI_SCROLL =: _1
      end.
      tui_redraw ''
    end.
    return.
  end.
  
  NB. Escape sequences: ESC=27 followed by [ and code
  if. 27 = k do.
    if. tui_keyp 0 do.
      k2 =. tui_rkey ''
      if. 91 = k2 do.  NB. '['
        if. tui_keyp 0 do.
          k3 =. tui_rkey ''
          select. k3
          case. 65 do.  NB. Up arrow
            if. 0 < TUI_HISTORY_IDX do.
              TUI_HISTORY_IDX =: TUI_HISTORY_IDX - 1
              TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
              TUI_CURSOR =: #TUI_INPUT
              tui_redraw ''
            end.
          case. 66 do.  NB. Down arrow
            if. TUI_HISTORY_IDX < (#TUI_INPUT_HISTORY) - 1 do.
              TUI_HISTORY_IDX =: TUI_HISTORY_IDX + 1
              TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
              TUI_CURSOR =: #TUI_INPUT
            else.
              TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
              TUI_INPUT =: ''
              TUI_CURSOR =: 0
            end.
            tui_redraw ''
          case. 67 do.  NB. Right arrow
            if. TUI_CURSOR < #TUI_INPUT do.
              TUI_CURSOR =: TUI_CURSOR + 1
              tui_redraw ''
            end.
          case. 68 do.  NB. Left arrow
            if. 0 < TUI_CURSOR do.
              TUI_CURSOR =: TUI_CURSOR - 1
              tui_redraw ''
            end.
          case. 51 do.  NB. Delete: ESC[3~
            if. tui_keyp 0 do.
              tilde =. tui_rkey ''  NB. consume the '~'
              if. TUI_CURSOR < #TUI_INPUT do.
                TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ((TUI_CURSOR + 1) }. TUI_INPUT)
                tui_redraw ''
              end.
            end.
          case. 72 do.  NB. Home: ESC[H
            TUI_CURSOR =: 0
            tui_redraw ''
          case. 70 do.  NB. End: ESC[F
            TUI_CURSOR =: #TUI_INPUT
            tui_redraw ''
          case. 53 do.  NB. Page Up: ESC[5~
            if. tui_keyp 0 do.
              tilde =. tui_rkey ''  NB. consume '~'
              kc_u ''
            end.
          case. 54 do.  NB. Page Down: ESC[6~
            if. tui_keyp 0 do.
              tilde =. tui_rkey ''  NB. consume '~'
              kc_d ''
            end.
          end.
        end.
      end.
    end.
    return.
  end.
  
  NB. Printable ASCII (32-126)
  if. (k >: 32) *. k < 127 do.
    ch =. k { a.
    TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ch , (TUI_CURSOR }. TUI_INPUT)
    TUI_CURSOR =: TUI_CURSOR + 1
    tui_redraw ''
    return.
  end.
)

NB. ================================================================
NB. Main TUI loop — our own simple event loop
tui_run =: monad define
  tui_init ''
  echo =: tui_echo
  
  'prompt' tui_print 'J-PI Agent (TUI mode)'
  'muted' tui_print 'Type a question directly, or:'
  'muted' tui_print '  !cmd  run a shell command    /cmd  agent commands'
  'muted' tui_print '  Ctrl+U/D scroll  Ctrl+C exit'
  tui_print ''
  tui_redraw ''
  
  while. TUI_RUNNING do.
    if. tui_keyp 100 do.       NB. check for key, 100ms timeout
      tui_handle_key tui_rkey ''
    end.
  end.
  
  tui_cleanup ''
)

echo 'tui2 loaded.'
