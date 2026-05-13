NB. J-PI TUI — ncurses-based terminal interface
NB. tui.ijs

require 'api/ncurses'
coinsert 'ncurses'

NB. Load the agent
load 'agent.ijs'

NB. ================================================================
NB. TUI state
TUI_LINES =: 0             NB. terminal height
TUI_COLS  =: 0             NB. terminal width
TUI_SCROLL =: 0            NB. scroll offset in output
TUI_OUTPUT =: 0 $ <''      NB. boxed list of output lines
TUI_INPUT  =: ''            NB. current input string
TUI_CURSOR =: 0             NB. cursor position in input
TUI_HISTORY_IDX =: 0        NB. input history index
TUI_INPUT_HISTORY =: 0 $ <'' NB. previous inputs

NB. Window handles
win_output =: 0
win_status =: 0
win_input  =: 0

NB. Color pair constants
CP_NORMAL   =: 1
CP_STATUS   =: 2
CP_TOOL     =: 3
CP_ERROR    =: 4
CP_PROMPT   =: 5
CP_MUTED    =: 6

NB. ================================================================
NB. Initialize ncurses and create windows
tui_init =: monad define
  stdscr =: initscr ''
  if. 0 = stdscr do. echo 'ERROR: ncurses init failed' return. end.
  cbreak ''
  noecho ''
  keypad stdscr , 1                NB. enable arrow keys etc.
  start_color ''
  NB. color pairs: fg, bg
  init_pair CP_NORMAL , COLOR_WHITE , COLOR_BLACK
  init_pair CP_STATUS , COLOR_BLACK , COLOR_CYAN
  init_pair CP_TOOL , COLOR_GREEN , COLOR_BLACK
  init_pair CP_ERROR , COLOR_RED , COLOR_BLACK
  init_pair CP_PROMPT , COLOR_CYAN , COLOR_BLACK
  init_pair CP_MUTED , COLOR_YELLOW , COLOR_BLACK
  NB. get terminal size
  tui_resize ''
)

NB. ================================================================
NB. Handle terminal resize — recreate windows
tui_resize =: monad define
  NB. delete old windows if they exist
  if. win_output ~: 0 do. delwin win_output end.
  if. win_status ~: 0 do. delwin win_status end.
  if. win_input ~: 0 do. delwin win_input end.
  NB. get current size from stdscr
  NB. use tput since getmaxy/getmaxx are macros
  TUI_LINES =: ". _1 }. 2!:0 'tput lines'
  TUI_COLS  =: ". _1 }. 2!:0 'tput cols'
  NB. layout: output gets most space, status bar 1 line, input 1 line
  out_h =. TUI_LINES - 2
  NB. create windows: newwin height width row col
  win_output =: newwin out_h , TUI_COLS , 0 , 0
  win_status =: newwin 1 , TUI_COLS , out_h , 0
  win_input  =: newwin 1 , TUI_COLS , (out_h + 1) , 0
  NB. enable scrolling in output window
  scrollok win_output , 1
  NB. enable keypad for input window
  keypad win_input , 1
)

NB. ================================================================
NB. Add a line to the output buffer and display it
NB. x = color pair (default CP_NORMAL), y = text string
tui_print =: verb define
  CP_NORMAL tui_print y
:
  TUI_OUTPUT =: TUI_OUTPUT , < y
  NB. add to output window
  wattr_on win_output , (COLOR_PAIR x) , 0
  waddnstr win_output ; y ; TUI_COLS - 1
  waddch win_output , 10    NB. newline
  wattr_off win_output , (COLOR_PAIR x) , 0
  wrefresh win_output
)

NB. ================================================================
NB. Draw the status bar
tui_draw_status =: monad define
  wbkgd win_status , COLOR_PAIR CP_STATUS
  wclear win_status
  wmove win_status , 0 0
  NB. left side: model
  left =. ' J-PI | ' , MODEL
  NB. right side: tokens + branch
  branch =. git_branch ''
  right =. ''
  if. 0 < TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS do.
    right =. right , (": TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS) , ' tok'
  end.
  if. 0 < #branch do.
    right =. right , ' | ' , branch
  end.
  right =. right , ' | ' , (": #HISTORY) , ' msgs '
  NB. pad middle
  pad =. (TUI_COLS - (#left) + #right) # ' '
  waddnstr win_status ; (left , pad , right) ; TUI_COLS
  wrefresh win_status
)

NB. ================================================================
NB. Draw the input line
tui_draw_input =: monad define
  wclear win_input
  wmove win_input , 0 0
  wattr_on win_input , (COLOR_PAIR CP_PROMPT) , 0
  waddnstr win_input ; '> ' ; 2
  wattr_off win_input , (COLOR_PAIR CP_PROMPT) , 0
  waddnstr win_input ; TUI_INPUT ; TUI_COLS - 3
  NB. position cursor
  wmove win_input , 0 , 2 + TUI_CURSOR
  wrefresh win_input
)

NB. ================================================================
NB. Override echo to route output through TUI
NB. Save original echo and replace
orig_echo =: echo
echo =: monad define
  NB. split by LF and print each line
  lines =. <;._2 y , LF -. {: y , LF
  for_l. lines do.
    line =. > l
    NB. color routing based on content
    if. 'Tool call:' +./@E. line do.
      CP_TOOL tui_print line
    elseif. 'ERROR' +./@E. line do.
      CP_ERROR tui_print line
    elseif. 'Asking LLM' +./@E. line do.
      CP_MUTED tui_print line
    elseif. '  [' +./@E. line do.
      CP_MUTED tui_print line
    elseif. do.
      tui_print line
    end.
  end.
  tui_draw_status ''
)

NB. ================================================================
NB. Process a command entered by the user
tui_process =: monad define
  if. 0 = #y do. return. end.
  NB. add to input history
  TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , < y
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
  NB. show what user typed
  CP_PROMPT tui_print '> ' , y
  NB. dispatch
  if. y -: 'exit' do. return. end.
  agent y
  tui_draw_status ''
)

NB. ================================================================
NB. Main TUI loop — read keys, build input, dispatch commands
tui_run =: monad define
  tui_init ''
  NB. welcome message
  CP_PROMPT tui_print 'J-PI Agent (TUI mode)'
  CP_MUTED tui_print 'Type commands or "ask <question>" for LLM. "exit" to quit.'
  tui_print ''
  tui_draw_status ''
  tui_draw_input ''
  NB. main input loop
  while. 1 do.
    key =. wgetch win_input
    select. key
    case. 10 do.
      NB. Enter — process input
      cmd =. TUI_INPUT
      TUI_INPUT =: ''
      TUI_CURSOR =: 0
      tui_draw_input ''
      if. cmd -: 'exit' do. break. end.
      tui_process cmd
      tui_draw_input ''
    case. 127 ; KEY_BACKSPACE do.
      NB. Backspace
      if. 0 < TUI_CURSOR do.
        TUI_INPUT =: ((TUI_CURSOR - 1) {. TUI_INPUT) , (TUI_CURSOR }. TUI_INPUT)
        TUI_CURSOR =: TUI_CURSOR - 1
        tui_draw_input ''
      end.
    case. KEY_LEFT do.
      if. 0 < TUI_CURSOR do.
        TUI_CURSOR =: TUI_CURSOR - 1
        tui_draw_input ''
      end.
    case. KEY_RIGHT do.
      if. TUI_CURSOR < #TUI_INPUT do.
        TUI_CURSOR =: TUI_CURSOR + 1
        tui_draw_input ''
      end.
    case. KEY_UP do.
      NB. input history — previous
      if. 0 < TUI_HISTORY_IDX do.
        TUI_HISTORY_IDX =: TUI_HISTORY_IDX - 1
        TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
        TUI_CURSOR =: #TUI_INPUT
        tui_draw_input ''
      end.
    case. KEY_DOWN do.
      NB. input history — next
      if. TUI_HISTORY_IDX < (#TUI_INPUT_HISTORY) - 1 do.
        TUI_HISTORY_IDX =: TUI_HISTORY_IDX + 1
        TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
        TUI_CURSOR =: #TUI_INPUT
      else.
        TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
        TUI_INPUT =: ''
        TUI_CURSOR =: 0
      end.
      tui_draw_input ''
    case. KEY_RESIZE do.
      tui_resize ''
      tui_draw_status ''
      tui_draw_input ''
    case. do.
      NB. printable character — insert at cursor
      if. (key >: 32) *. key < 127 do.
        ch =. {. key { a.
        TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ch , (TUI_CURSOR }. TUI_INPUT)
        TUI_CURSOR =: TUI_CURSOR + 1
        tui_draw_input ''
      end.
    end.
  end.
  NB. cleanup
  endwin ''
)
