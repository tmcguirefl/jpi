NB. J-PI TUI — j-kvm based terminal interface (no ncurses)
NB. tui2.ijs
NB.
NB. Uses tangentstorm/j-kvm/vt for terminal size and raw mode only.
NB. All ANSI output goes to fd 1 (stdout) — puts_vt_ writes to fd 0 (broken on macOS).
NB. All keyboard input reads from fd 0 (stdin) — rkey_vt_ reads from fd 1 (broken on macOS).

NB. Load the agent first
load 'agent.ijs'

NB. Load j-kvm vt (only for gethw and raw mode setup)
require 'tangentstorm/j-kvm/vt'
load 'theme.ijs'

NB. ================================================================
NB. Low-level I/O — direct libc calls to correct fd

NB. We need the libc handle — replicate what vt.ijs does
TUI_LIBC =: unxlib 'c'

NB. Write string y to fd 1 (stdout)
tui_write =: monad define
  0 0 $ (TUI_LIBC,' write n i &c l')&cd (1 ; , y ; #y)
)

NB. Read one byte from fd 0 (stdin), return ascii code
tui_rkey =: monad define
  buf =. (,0){a.
  res =. (TUI_LIBC,' read l i *c l')&cd (0 ; buf ; 1)
  a. i. 0 { 2 {:: res
)

NB. Non-blocking key check with timeout (ms)
NB. Returns 1 if key available, 0 if not
NB. Uses poll() on fd 0
tui_keyp =: monad define
  NB. set stdin non-blocking
  (TUI_LIBC,' fcntl i i i i')&cd (0 ; 4 ; 4)  NB. F_SETFL=4, O_NONBLOCK=4 on Darwin
  NB. poll stdin with timeout
  pollfd =. , (0 , 1) , 0  NB. fd=0, events=POLLIN=1, revents=0
  r =. (TUI_LIBC,' poll i *l i i')&cd (pollfd ; 1 ; y)
  NB. restore blocking
  (TUI_LIBC,' fcntl i i i i')&cd (0 ; 4 ; 0)
  NB. check if POLLIN set in revents
  0 ~: _48 (33 b.) 1 {:: r
)

NB. ================================================================
NB. ANSI escape code builders

NB. Core constants
ESC =: 27{a.
CSI =: ESC,'['

NB. Control sequences
NB. goxy: move cursor to (col, row) — 0-indexed
tui_goxy =: monad define
  'col row' =. y
  tui_write CSI , (": row+1) , ';' , (": col+1) , 'f'
)

NB. ceol: clear to end of line
tui_ceol =: monad define
  tui_write CSI , '0K'
)

NB. cscr: clear screen
tui_cscr =: monad define
  tui_write CSI , '2J' , CSI , 'H'
)

NB. reset: reset all attributes
tui_reset =: monad define
  tui_write CSI , '0m'
)

NB. fgc: set 256-color foreground (neg=256-color, pos=24-bit)
tui_fgc =: monad define
  if. y < 0 do.
    tui_write CSI , '38;5;' , (": -y) , 'm'
  else.
    'r g b' =. (3#256) #: y
    tui_write CSI , '38;2;' , (": r) , ';' , (": g) , ';' , (": b) , 'm'
  end.
)

NB. bgc: set 256-color background (neg=256-color, pos=24-bit)
tui_bgc =: monad define
  if. y < 0 do.
    tui_write CSI , '48;5;' , (": -y) , 'm'
  else.
    'r g b' =. (3#256) #: y
    tui_write CSI , '48;2;' , (": r) , ';' , (": g) , ';' , (": b) , 'm'
  end.
)

NB. curs: show(1)/hide(0) cursor
tui_curs =: monad define
  tui_write CSI , '?25' , (y{'lh') ,~ ]
)

NB. ================================================================
NB. TUI state
TUI_LINES =: 0
TUI_COLS  =: 0
TUI_OUTPUT =: 0 $ <''
TUI_SCROLL =: _1
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
NB. ncurses 0-7 map to 256-color 0-7, but j-kvm needs negative for 256-color
theme_apply =: monad define
  'fg bg' =. theme_colors y
  tui_fgc -fg
  tui_bgc -bg
)

NB. ================================================================
NB. Initialize TUI
tui_init =: monad define
  'TUI_LINES TUI_COLS' =. gethw_vt_''
  raw_vt_ 1
  tui_cscr ''
  tui_curs 0
)

NB. ================================================================
NB. Restore terminal on exit
tui_cleanup =: monad define
  tui_curs 1
  raw_vt_ 0
  tui_reset ''
  tui_write CR,LF
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
  
  tui_cscr ''
  
  NB. Draw each output line at its exact row
  tui_reset ''
  for_i. i. #visible do.
    tui_goxy 0 , i
    tui_write > i { visible
  end.
  
  NB. Clear remaining output rows
  for_i. (#visible) + i. out_h - #visible do.
    tui_goxy 0 , i
    tui_ceol ''
  end.
  
  NB. Draw status bar at row out_h
  tui_goxy 0 , out_h
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
  tui_write left , pad , right
  tui_reset ''
  
  NB. Draw input line at row (out_h + STATUS_H)
  tui_goxy 0 , (out_h + STATUS_H)
  theme_apply 'prompt'
  tui_write '> '
  tui_reset ''
  tui_write TUI_INPUT
  tui_ceol ''
  
  NB. Position cursor
  tui_goxy (2 + TUI_CURSOR) , (out_h + STATUS_H)
  tui_curs 1
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
NB. Key handler — y is the ascii code from tui_rkey
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
  
  NB. Backspace: DEL=127 or BS=8
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
  
  NB. Escape sequences: ESC=27
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
              tilde =. tui_rkey ''
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
              tilde =. tui_rkey ''
              tui_handle_key 21  NB. same as Ctrl+U
            end.
          case. 54 do.  NB. Page Down: ESC[6~
            if. tui_keyp 0 do.
              tilde =. tui_rkey ''
              tui_handle_key 4   NB. same as Ctrl+D
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
NB. Main TUI loop
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
    if. tui_keyp 100 do.
      tui_handle_key tui_rkey ''
    end.
  end.
  
  tui_cleanup ''
)

echo 'tui2 loaded.'
