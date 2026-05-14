NB. J-PI TUI — ncurses-based terminal interface
NB. tui.ijs

NB. Load the agent first (all echo output goes to normal stdout)
load 'agent.ijs'

NB. Load ncurses after agent so echo is not clobbered during init
require 'api/ncurses'
load 'theme.ijs'

NB. ================================================================
NB. ncurses boolean helpers (c type takes a single character string)
NC_TRUE  =: '1'
NC_FALSE =: '0'

NB. TUI state
TUI_LINES =: 0
TUI_COLS  =: 0
TUI_OUTPUT =: 0 $ <''      NB. all output lines
TUI_SCROLL =: _1               NB. _1 means follow (auto-scroll to bottom)
TUI_INPUT  =: ''
TUI_CURSOR =: 0
TUI_HISTORY_IDX =: 0
TUI_INPUT_HISTORY =: 0 $ <''

NB. Window handles
win_output =: 0
win_status =: 0
win_input  =: 0

NB. Color pairs are now driven by theme.ijs
NB. Use theme_cp 'name' to get the pair number

NB. ================================================================
NB. Initialize ncurses and create windows
tui_init =: monad define
  stdscr =: initscr_ncurses_ ''
  if. 0 = stdscr do. 1!:2&2 'ERROR: ncurses init failed' return. end.
  cbreak_ncurses_ ''
  noecho_ncurses_ ''
  keypad_ncurses_ stdscr ; NC_TRUE
  start_color_ncurses_ ''
  NB. apply theme colors
  apply_theme ''
  tui_resize ''
)

NB. ================================================================
NB. Handle terminal resize
tui_resize =: monad define
  NB. delete old windows
  if. win_output ~: 0 do. delwin_ncurses_ win_output end.
  if. win_status ~: 0 do. delwin_ncurses_ win_status end.
  if. win_input ~: 0 do. delwin_ncurses_ win_input end.
  NB. clear the entire screen to remove stale content
  wclear_ncurses_ stdscr
  wrefresh_ncurses_ stdscr
  NB. get new terminal size
  TUI_LINES =: ". _1 }. 2!:0 'tput lines'
  TUI_COLS  =: ". _1 }. 2!:0 'tput cols'
  out_h =. TUI_LINES - 2
  NB. recreate windows at new size
  win_output =: newwin_ncurses_ out_h , TUI_COLS , 0 , 0
  win_status =: newwin_ncurses_ 1 , TUI_COLS , out_h , 0
  win_input  =: newwin_ncurses_ 1 , TUI_COLS , (out_h + 1) , 0
  scrollok_ncurses_ win_output ; NC_TRUE
  keypad_ncurses_ win_input ; NC_TRUE
  NB. redraw output history into new window
  for_l. TUI_OUTPUT do.
    waddnstr_ncurses_ win_output ; (> l) ; TUI_COLS - 1
    waddch_ncurses_ win_output , 10
  end.
  wrefresh_ncurses_ win_output
)

NB. ================================================================
NB. Redraw the output window from TUI_OUTPUT at current scroll position
tui_redraw_output =: monad define
  wclear_ncurses_ win_output
  wmove_ncurses_ win_output , 0 , 0
  out_h =. TUI_LINES - 2
  total =. #TUI_OUTPUT
  NB. if following (_1) or scrolled past end, show the tail
  if. (TUI_SCROLL = _1) +. (TUI_SCROLL + out_h) >: total do.
    start =. 0 >. total - out_h
    TUI_SCROLL =: _1
  else.
    start =. 0 >. TUI_SCROLL
  end.
  NB. draw visible lines
  visible =. out_h {. start }. TUI_OUTPUT
  for_l. visible do.
    waddnstr_ncurses_ win_output ; (> l) ; TUI_COLS - 1
    waddch_ncurses_ win_output , 10
  end.
  wrefresh_ncurses_ win_output
)

NB. ================================================================
NB. Add a line to the output buffer and redraw
NB. x = color pair (default theme_cp 'normal'), y = text string
tui_print =: verb define
  theme_cp 'normal' tui_print y
:
  TUI_OUTPUT =: TUI_OUTPUT , < y
  NB. if following, just append to window (fast path)
  if. TUI_SCROLL = _1 do.
    wattr_on_ncurses_ win_output , (COLOR_PAIR_ncurses_ x) , 0
    waddnstr_ncurses_ win_output ; y ; TUI_COLS - 1
    waddch_ncurses_ win_output , 10
    wattr_off_ncurses_ win_output , (COLOR_PAIR_ncurses_ x) , 0
    wrefresh_ncurses_ win_output
  else.
    NB. user scrolled up — snap back to bottom
    TUI_SCROLL =: _1
    tui_redraw_output ''
  end.
)

NB. ================================================================
NB. Draw the status bar
tui_draw_status =: monad define
  wbkgd_ncurses_ win_status , COLOR_PAIR_ncurses_ theme_cp 'status'
  wclear_ncurses_ win_status
  wmove_ncurses_ win_status , 0 , 0
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
  wmove_ncurses_ win_input , 0 , 0
  wattr_on_ncurses_ win_input , (COLOR_PAIR_ncurses_ theme_cp 'prompt') , 0
  waddnstr_ncurses_ win_input ; '> ' ; 2
  wattr_off_ncurses_ win_input , (COLOR_PAIR_ncurses_ theme_cp 'prompt') , 0
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
      theme_cp 'tool' tui_print line
    elseif. 'ERROR' +./@E. line do.
      theme_cp 'error' tui_print line
    elseif. 'Asking LLM' +./@E. line do.
      theme_cp 'muted' tui_print line
    elseif. '  [' +./@E. line do.
      theme_cp 'muted' tui_print line
    elseif. do.
      tui_print line
    end.
  end.
  tui_draw_status ''
)

NB. ================================================================
NB. Process input
NB. /command  -> agent command (strip the /)
NB. !command  -> shell command (strip the !)
NB. anything else -> treated as an LLM question (auto-prepends ask)
tui_process =: monad define
  if. 0 = #y do. return. end.
  TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , < y
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
  if. '/' = {. y do.
    NB. slash command
    cmd =. }. y
    theme_cp 'prompt' tui_print '/ ' , cmd
    if. cmd -: 'exit' do. return. end.
    agent cmd
  elseif. '!' = {. y do.
    NB. bang shell command
    cmd =. }. y
    theme_cp 'prompt' tui_print '! ' , cmd
    agent 'run ' , cmd
  elseif. do.
    NB. direct question to LLM
    theme_cp 'prompt' tui_print '> ' , y
    agent 'ask ' , y
  end.
  tui_draw_status ''
)

NB. ================================================================
NB. Main TUI loop
tui_run =: monad define
  tui_init ''
  NB. redirect echo to TUI output window now that ncurses is running
  echo =: tui_echo
  theme_cp 'prompt' tui_print 'J-PI Agent (TUI mode)'
  theme_cp 'muted' tui_print 'Type a question directly, or:'
  theme_cp 'muted' tui_print '  !cmd  run a shell command    /cmd  agent commands'
  theme_cp 'muted' tui_print '  /read /edit /write /git /grep /find /model /theme /usage /save /load /clear /exit'
  tui_print ''
  tui_draw_status ''
  tui_draw_input ''
  while. 1 do.
    key =. wgetch_ncurses_ win_input
    select. key
    case. 10 do.
      NB. Enter
      cmd =. TUI_INPUT
      TUI_INPUT =: ''
      TUI_CURSOR =: 0
      tui_draw_input ''
      if. (cmd -: 'exit') +. cmd -: '/exit' do. break. end.
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
    case. KEY_PPAGE_ncurses_ do.
      NB. Page Up — scroll back
      out_h =. TUI_LINES - 2
      if. TUI_SCROLL = _1 do.
        NB. start scrolling from near the bottom
        TUI_SCROLL =: 0 >. (#TUI_OUTPUT) - out_h
      end.
      TUI_SCROLL =: 0 >. TUI_SCROLL - (out_h - 1)
      tui_redraw_output ''
    case. KEY_NPAGE_ncurses_ do.
      NB. Page Down — scroll forward
      out_h =. TUI_LINES - 2
      if. TUI_SCROLL ~: _1 do.
        TUI_SCROLL =: TUI_SCROLL + (out_h - 1)
        NB. if scrolled past end, snap to follow mode
        if. (TUI_SCROLL + out_h) >: #TUI_OUTPUT do.
          TUI_SCROLL =: _1
        end.
        tui_redraw_output ''
      end.
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
