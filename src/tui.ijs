NB. J-PI TUI — ncurses-based terminal interface
NB. tui.ijs

NB. Load the agent first (all echo output goes to normal stdout)
load 'agent.ijs'

NB. Load ncurses after agent so echo is not clobbered during init
require 'api/ncurses'

NB. ================================================================
NB. TUI state
TUI_LINES =: 0
TUI_COLS  =: 0
TUI_OUTPUT =: 0 $ <''
TUI_INPUT  =: ''
TUI_CURSOR =: 0
TUI_HISTORY_IDX =: 0
TUI_INPUT_HISTORY =: 0 $ <''

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
  stdscr =: initscr_ncurses_ ''
  if. 0 = stdscr do. 1!:2&2 'ERROR: ncurses init failed' return. end.
  cbreak_ncurses_ ''
  noecho_ncurses_ ''
  keypad_ncurses_ stdscr , 1
  start_color_ncurses_ ''
  NB. color pairs: fg, bg
  init_pair_ncurses_ CP_NORMAL , COLOR_WHITE_ncurses_ , COLOR_BLACK_ncurses_
  init_pair_ncurses_ CP_STATUS , COLOR_BLACK_ncurses_ , COLOR_CYAN_ncurses_
  init_pair_ncurses_ CP_TOOL , COLOR_GREEN_ncurses_ , COLOR_BLACK_ncurses_
  init_pair_ncurses_ CP_ERROR , COLOR_RED_ncurses_ , COLOR_BLACK_ncurses_
  init_pair_ncurses_ CP_PROMPT , COLOR_CYAN_ncurses_ , COLOR_BLACK_ncurses_
  init_pair_ncurses_ CP_MUTED , COLOR_YELLOW_ncurses_ , COLOR_BLACK_ncurses_
  tui_resize ''
)

NB. ================================================================
NB. Handle terminal resize
tui_resize =: monad define
  if. win_output ~: 0 do. delwin_ncurses_ win_output end.
  if. win_status ~: 0 do. delwin_ncurses_ win_status end.
  if. win_input ~: 0 do. delwin_ncurses_ win_input end.
  TUI_LINES =: ". _1 }. 2!:0 'tput lines'
  TUI_COLS  =: ". _1 }. 2!:0 'tput cols'
  out_h =. TUI_LINES - 2
  win_output =: newwin_ncurses_ out_h , TUI_COLS , 0 , 0
  win_status =: newwin_ncurses_ 1 , TUI_COLS , out_h , 0
  win_input  =: newwin_ncurses_ 1 , TUI_COLS , (out_h + 1) , 0
  scrollok_ncurses_ win_output , 1
  keypad_ncurses_ win_input , 1
)

NB. ================================================================
NB. Add a line to the output window
NB. x = color pair (default CP_NORMAL), y = text string
tui_print =: verb define
  CP_NORMAL tui_print y
:
  TUI_OUTPUT =: TUI_OUTPUT , < y
  wattr_on_ncurses_ win_output , (COLOR_PAIR_ncurses_ x) , 0
  waddnstr_ncurses_ win_output ; y ; TUI_COLS - 1
  waddch_ncurses_ win_output , 10
  wattr_off_ncurses_ win_output , (COLOR_PAIR_ncurses_ x) , 0
  wrefresh_ncurses_ win_output
)

NB. ================================================================
NB. Draw the status bar
tui_draw_status =: monad define
  wbkgd_ncurses_ win_status , COLOR_PAIR_ncurses_ CP_STATUS
  wclear_ncurses_ win_status
  wmove_ncurses_ win_status , 0 0
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
  waddnstr_ncurses_ win_status ; (left , pad , right) ; TUI_COLS
  wrefresh_ncurses_ win_status
)

NB. ================================================================
NB. Draw the input line
tui_draw_input =: monad define
  wclear_ncurses_ win_input
  wmove_ncurses_ win_input , 0 0
  wattr_on_ncurses_ win_input , (COLOR_PAIR_ncurses_ CP_PROMPT) , 0
  waddnstr_ncurses_ win_input ; '> ' ; 2
  wattr_off_ncurses_ win_input , (COLOR_PAIR_ncurses_ CP_PROMPT) , 0
  waddnstr_ncurses_ win_input ; TUI_INPUT ; TUI_COLS - 3
  wmove_ncurses_ win_input , 0 , 2 + TUI_CURSOR
  wrefresh_ncurses_ win_input
)

NB. ================================================================
NB. Route output to the TUI output window with color hints
tui_echo =: monad define
  lines =. <;._2 y , LF -. {: y , LF
  for_l. lines do.
    line =. > l
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
NB. Process a command
tui_process =: monad define
  if. 0 = #y do. return. end.
  TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , < y
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
  CP_PROMPT tui_print '> ' , y
  if. y -: 'exit' do. return. end.
  agent y
  tui_draw_status ''
)

NB. ================================================================
NB. Main TUI loop
tui_run =: monad define
  tui_init ''
  NB. welcome
  CP_PROMPT tui_print 'J-PI Agent (TUI mode)'
  CP_MUTED tui_print 'Commands: ask, read, run, edit, write, git, grep, find, model, usage, save, load, clear, exit'
  tui_print ''
  tui_draw_status ''
  tui_draw_input ''
  NB. main loop
  while. 1 do.
    key =. wgetch_ncurses_ win_input
    select. key
    case. 10 do.
      NB. Enter
      cmd =. TUI_INPUT
      TUI_INPUT =: ''
      TUI_CURSOR =: 0
      tui_draw_input ''
      if. cmd -: 'exit' do. break. end.
      tui_process cmd
      tui_draw_input ''
    case. 127 ; KEY_BACKSPACE_ncurses_ do.
      if. 0 < TUI_CURSOR do.
        TUI_INPUT =: ((TUI_CURSOR - 1) {. TUI_INPUT) , (TUI_CURSOR }. TUI_INPUT)
        TUI_CURSOR =: TUI_CURSOR - 1
        tui_draw_input ''
      end.
    case. KEY_LEFT_ncurses_ do.
      if. 0 < TUI_CURSOR do.
        TUI_CURSOR =: TUI_CURSOR - 1
        tui_draw_input ''
      end.
    case. KEY_RIGHT_ncurses_ do.
      if. TUI_CURSOR < #TUI_INPUT do.
        TUI_CURSOR =: TUI_CURSOR + 1
        tui_draw_input ''
      end.
    case. KEY_UP_ncurses_ do.
      if. 0 < TUI_HISTORY_IDX do.
        TUI_HISTORY_IDX =: TUI_HISTORY_IDX - 1
        TUI_INPUT =: > TUI_HISTORY_IDX { TUI_INPUT_HISTORY
        TUI_CURSOR =: #TUI_INPUT
        tui_draw_input ''
      end.
    case. KEY_DOWN_ncurses_ do.
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
    case. KEY_RESIZE_ncurses_ do.
      tui_resize ''
      tui_draw_status ''
      tui_draw_input ''
    case. do.
      NB. printable character
      if. (key >: 32) *. key < 127 do.
        ch =. {. key { a.
        TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ch , (TUI_CURSOR }. TUI_INPUT)
        TUI_CURSOR =: TUI_CURSOR + 1
        tui_draw_input ''
      end.
    end.
  end.
  endwin_ncurses_ ''
)
