NB. J-PI TUI — ANSI escape code based (no ncurses dependency)
NB. tui.ijs

NB. Load the agent first
load 'agent.ijs'

NB. ================================================================
NB. ANSI escape sequences
ESC =: 27 { a.
CSI =: ESC , '['                   NB. Control Sequence Introducer

ansi_clear    =: monad define CSI , '2J' , CSI , 'H'      NB. clear screen + home
ansi_goto     =: dyad define CSI , (": x) , ';' , (": y) , 'H'   NB. x=row y=col (1-based)
ansi_color    =: monad define CSI , y , 'm'                NB. SGR color code
ansi_reset    =: monad define CSI , '0m'                   NB. reset colors

NB. Color helpers
c_normal =: ansi_color '0'
c_bold   =: ansi_color '1'
c_dim    =: ansi_color '2'
c_red    =: ansi_color '31'
c_green  =: ansi_color '32'
c_yellow =: ansi_color '33'
c_cyan   =: ansi_color '36'
c_white  =: ansi_color '37'
c_bg_cyan =: ansi_color '46'
c_bg_black =: ansi_color '40'

NB. ================================================================
NB. Get terminal size
get_term_size =: monad define
  rows =. ". _1 }. 2!:0 'tput lines'
  cols =. ". _1 }. 2!:0 'tput cols'
  rows , cols
)

NB. ================================================================
NB. Write directly to stdout (bypasses J formatting)
out =: 1!:2&2

NB. ================================================================
NB. Draw the status bar at the bottom of screen
draw_status =: monad define
  'rows cols' =. get_term_size ''
  NB. build status content
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
  pad =. (cols - (#left) + #right) # ' '
  NB. draw at second-to-last row, bg cyan
  out (rows - 1) ansi_goto 1
  out c_bg_cyan , c_bold , (cols {. left , pad , right) , c_normal , c_bg_black
)

NB. ================================================================
NB. Draw the prompt line at the bottom of screen
draw_prompt =: monad define
  'rows cols' =. get_term_size ''
  out rows ansi_goto 1
  out c_cyan , '> ' , c_normal , ((cols - 3) {. TUI_INPUT) , (CSI , 'K')   NB. clear to end of line
  NB. position cursor
  out rows ansi_goto (3 + TUI_CURSOR)
)

NB. ================================================================
NB. TUI state
TUI_INPUT  =: ''
TUI_CURSOR =: 0
TUI_INPUT_HISTORY =: 0 $ <''
TUI_HISTORY_IDX =: 0

NB. ================================================================
NB. Override echo to add color hints
echo =: monad define
  if. 'Tool call:' +./@E. y do.
    out c_green , y , c_normal , LF
  elseif. 'ERROR' +./@E. y do.
    out c_red , y , c_normal , LF
  elseif. 'Asking LLM' +./@E. y do.
    out c_dim , y , c_normal , LF
  elseif. '  [' +./@E. y do.
    out c_dim , y , c_normal , LF
  elseif. do.
    out y , LF
  end.
)

NB. ================================================================
NB. Main TUI loop
tui_run =: monad define
  NB. clear screen and show welcome
  out ansi_clear ''
  out c_cyan , c_bold , 'J-PI Agent (TUI mode)' , c_normal , LF
  out c_dim , 'Commands: ask, read, run, edit, write, git, grep, find, model, usage, save, load, clear, exit' , c_normal , LF
  out LF
  draw_status ''
  draw_prompt ''
  NB. main input loop using stdin
  while. 1 do.
    draw_status ''
    draw_prompt ''
    NB. read a line from stdin
    cmd =. 1!:1 ] 1
    if. 0 = #cmd do. continue. end.
    NB. add to input history
    TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , < cmd
    NB. show the command
    out c_cyan , '> ' , c_normal , cmd , LF
    if. cmd -: 'exit' do. break. end.
    agent cmd
  end.
  out LF , 'J-PI Agent stopped.' , LF
)
