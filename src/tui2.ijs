NB. J-PI TUI — j-kvm based terminal interface (no ncurses)
NB. tui2.ijs
NB.
NB. Uses tangentstorm/j-kvm/vt for gethw + raw mode.
NB. All ANSI output via fd 1 (stdout).
NB. All keyboard input via fd 0 (stdin) — blocking read, 0% CPU idle.

NB. Load the agent first
load 'agent.ijs'

NB. Load j-kvm vt
require 'tangentstorm/j-kvm/vt'
load 'theme.ijs'

NB. ================================================================
NB. Low-level I/O — fd 1 writes, fd 0 reads

U =: unxlib 'c'

NB. Write string to fd 1 (stdout)
tui_out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)

NB. Read one byte from fd 0 (stdin) — BLOCKS until key available
tui_in =: monad define
  buf =. (,0){a.
  res =. (U,' read l i *c l')&cd (0 ; buf ; 1)
  a. i. 0 { 2 {:: res
)

NB. ================================================================
NB. ANSI escape helpers

ESC =: 27{a.
CSI =: ESC,'['

tui_goxy =: monad define
  'col row' =. y
  tui_out CSI , (": row+1) , ';' , (": col+1) , 'f'
)

tui_ceol =: monad define
  tui_out CSI , '0K'
)

tui_cscr =: monad define
  tui_out (CSI,'2J')
  tui_out (CSI,'H')
)

tui_reset =: monad define
  tui_out (CSI,'0m')
)

tui_fgc =: monad define
  tui_out CSI , '38;5;' , (": -y) , 'm'
)

tui_bgc =: monad define
  tui_out CSI , '48;5;' , (": -y) , 'm'
)

tui_curs =: monad define
  tui_out CSI , '?25' , (y{'lh')
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
NB. Theme helpers
theme_apply =: monad define
  'fg bg' =. theme_colors y
  tui_fgc fg
  tui_bgc bg
)

NB. ================================================================
NB. Initialize
tui_init =: monad define
  'TUI_LINES TUI_COLS' =. gethw_vt_''
  raw_vt_ 1
  tui_cscr ''
  tui_curs 0
)

NB. ================================================================
NB. Cleanup
tui_cleanup =: monad define
  tui_curs 1
  raw_vt_ 0
  tui_reset ''
  tui_out CR,LF
)

NB. ================================================================
NB. Wrap long lines
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
  
  if. (TUI_SCROLL = _1) +. (TUI_SCROLL + out_h) >: total do.
    start =. 0 >. total - out_h
    TUI_SCROLL =: _1
  else.
    start =. 0 >. TUI_SCROLL
  end.
  visible =. out_h {. start }. TUI_OUTPUT
  
  tui_cscr ''
  tui_reset ''
  
  NB. Draw each output line at its row
  for_i. i. #visible do.
    tui_goxy 0 , i
    tui_out > i { visible
  end.
  
  NB. Clear remaining rows
  for_i. (#visible) + i. out_h - #visible do.
    tui_goxy 0 , i
    tui_ceol ''
  end.
  
  NB. Status bar
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
  tui_out left , pad , right
  tui_reset ''
  
  NB. Input line
  tui_goxy 0 , (out_h + STATUS_H)
  theme_apply 'prompt'
  tui_out '> '
  tui_reset ''
  tui_out TUI_INPUT
  tui_ceol ''
  
  tui_goxy (2 + TUI_CURSOR) , (out_h + STATUS_H)
  tui_curs 1
)

NB. ================================================================
NB. Add line to output buffer
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
NB. Key handler — y is the ascii code
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
    NB. Use non-blocking poll for the rest of the sequence
    if. keyp_vt_ 0 do.
      k2 =. tui_in ''
      if. 91 = k2 do.  NB. '['
        if. keyp_vt_ 0 do.
          k3 =. tui_in ''
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
            if. keyp_vt_ 0 do.
              tilde =. tui_in ''
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
            if. keyp_vt_ 0 do.
              tilde =. tui_in ''
              tui_handle_key 21
            end.
          case. 54 do.  NB. Page Down: ESC[6~
            if. keyp_vt_ 0 do.
              tilde =. tui_in ''
              tui_handle_key 4
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
NB. Main TUI loop — blocking read, 0% CPU when idle
tui_run =: monad define
  tui_init ''
  echo =: tui_echo
  
  'prompt' tui_print 'J-PI Agent (TUI mode)'
  'muted' tui_print 'Type a question directly, or:'
  'muted' tui_print '  !cmd  shell    /cmd  agent    Ctrl+C exit'
  tui_print ''
  tui_redraw ''
  
  while. TUI_RUNNING do.
    k =. tui_in ''          NB. blocks here — 0% CPU while waiting
    tui_handle_key k
  end.
  
  tui_cleanup ''
)

echo 'tui2 loaded.'
