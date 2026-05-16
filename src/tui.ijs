NB. ============================================================
NB. J-PI TUI2 — Pure vt.ijs escape-code TUI (from scratch)
NB. Uses tangentstorm/j-kvm/vt definitions exclusively.
NB. ============================================================

require '/Users/tomdevel/jdev/j-kvm/vt.ijs'   NB. pure vt escape codes

coinsert 'vt'                     NB. bring all vt verbs into current scope

NB. load the rest of the agent (theme, agent, etc.)
NB. ensure we are in src/ so that agent.ijs and its loads can find siblings
srcdir =. '/Users/tomdevel/jdev/jpi/src'   NB. absolute path (reliable)
old =. 1!:43 ''
1!:44 srcdir
load 'agent.ijs'
load 'theme.ijs'
load 'md.ijs'
1!:44 old

NB. dummy symbol so llm.ijs conditionals never see it as undefined
win_output =: 0
LF =: 10{a.

NB. ============================================================
NB. Global TUI state
TUI_LINES =: 0
TUI_COLS  =: 0
TUI_OUTPUT =: 0 $ <''
TUI_SCROLL =: 0   NB. start at top
TUI_INPUT  =: ''
TUI_CURSOR =: 0
TUI_HISTORY_IDX =: 0
TUI_INPUT_HISTORY =: 0 $ <''
HISTORY_FILE =: (2!:5 'HOME') , '/.jpi_history'
HISTORY_MAX =: 500

NB. Load history from file
hist_load =: monad define
  try.
    raw =. 1!:1 < HISTORY_FILE
    if. 0 < #raw do.
      if. LF ~: {: raw do. raw =. raw , LF end.
      TUI_INPUT_HISTORY =: <;._2 raw
    end.
  catch. end.
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
)

NB. Save history to file (keep last HISTORY_MAX entries)
hist_save =: monad define
  h =. (- HISTORY_MAX <. #TUI_INPUT_HISTORY) {. TUI_INPUT_HISTORY
  txt =. ; h ,each <LF
  txt 1!:2 < HISTORY_FILE
)
TUI_RUNNING =: 1
MOUSE_ON =: 0      NB. mouse wheel tracking state
SCROLL_LINES =: 3  NB. lines per wheel tick

NB. Toggle mouse wheel capture on/off
mouse_toggle =: monad define
  MOUSE_ON =: -. MOUSE_ON
  if. MOUSE_ON do.
    puts CSI,'?1000h'
    puts CSI,'?1006h'
  else.
    puts CSI,'?1000l'
    puts CSI,'?1006l'
  end.
  tui_draw_bottom ''
)

NB. Bottom area: separator, input (1+ lines), separator, footer1, footer2
NB. Fixed chrome = 4 (sep + sep + footer1 + footer2)
BOTTOM_CHROME =: 4

NB. How many screen rows the current input occupies
input_h =: 3 : 0
  w =. TUI_COLS
  if. 0 = #TUI_INPUT do. 1 return. end.
  >. (#TUI_INPUT) % w          NB. ceiling: text / width
)

out_h =: 3 : 'TUI_LINES - (BOTTOM_CHROME + input_h 0)'

NB. ============================================================
NB. Helper: wrap long line to width x
wrap_line =: dyad define
  if. x >: #y do. ,< y return. end.
  r =. 0 $ <''
  while. x < #y do.
    r =. r , < x {. y
    y =. x }. y
  end.
  r , < y
)

NB. ============================================================
NB. Theme color application
tui_theme =: monad define
  'fg bg' =. theme_colors y
  fgc fg
  bgc bg
)

NB. ============================================================
NB. Lightweight redraw of bottom 4 lines (avoids flicker)
NB. Layout (dynamic):
NB.   row oh           = separator
NB.   row oh+1 .. +ih  = input line(s)   (ih = input_h 0)
NB.   row oh+ih+1      = separator
NB.   row oh+ih+2      = footer 1  (path + branch)
NB.   row oh+ih+3      = footer 2  (tokens, msgs, model)
tui_draw_bottom =: monad define
  curs 0                      NB. hide cursor during redraw
  oh =. out_h''
  w =. TUI_COLS
  ih =. input_h 0

  NB. ── row oh: top separator ──
  goxy 0, oh
  fgc 8
  puts w repstr_md_ BOX_H_md_
  reset''
  ceol''

  NB. ── row oh+1 .. oh+ih: input lines ──
  for_r. i. ih do.
    goxy 0, oh + 1 + r
    reset''
    chunk =. w {. (r * w) }. TUI_INPUT
    puts chunk
    ceol''
  end.

  NB. ── row oh+ih+1: bottom separator ──
  goxy 0, oh + ih + 1
  fgc 8
  puts w repstr_md_ BOX_H_md_
  reset''
  ceol''

  NB. ── row oh+ih+2: footer line 1 — path + branch ──
  goxy 0, oh + ih + 2
  fgc 8
  pwd =. 1!:43 ''
  branch =. git_branch ''
  fl1 =. ' ' , pwd
  if. 0 < #branch do. fl1 =. fl1 , ' (' , branch , ')' end.
  if. w < #fl1 do. fl1 =. ((w-3) {. fl1) , '...' end.
  puts fl1
  ceol''
  reset''

  NB. ── row oh+ih+3: footer line 2 — tokens, msgs, scroll, model ──
  goxy 0, oh + ih + 3
  fgc 8
  left =. ' '
  if. 0 < TOTAL_INPUT_TOKENS do.
    left =. left , (utf8_md_ 16b2191) , (": TOTAL_INPUT_TOKENS) , ' '
  end.
  if. 0 < TOTAL_OUTPUT_TOKENS do.
    left =. left , (utf8_md_ 16b2193) , (": TOTAL_OUTPUT_TOKENS) , ' '
  end.
  left =. left , (": #HISTORY) , ' msgs'
  scroll_pct =. ''
  total =. #TUI_OUTPUT
  if. total > oh do.
    pct =. <. 100 * (TUI_SCROLL + oh) % total
    scroll_pct =. ' ' , (": pct) , '%%'
  end.
  left =. left , scroll_pct
  if. MOUSE_ON do. left =. left , ' [wheel]' end.
  right =. MODEL , ' '
  pad =. 0 >. w - (#left) + #right
  puts left , (pad # ' ') , right
  ceol''
  reset''

  NB. place cursor on correct input row + column
  crow =. <. TUI_CURSOR % w      NB. which wrapped row
  ccol =. w | TUI_CURSOR         NB. column within that row
  goxy ccol, oh + 1 + crow
  curs 1                         NB. show cursor only now, on input line
)

NB. ============================================================
NB. Scroll to bottom (called after new output is added)
tui_scroll_bottom =: monad define
  oh =. out_h''
  TUI_SCROLL =: 0 >. (#TUI_OUTPUT) - oh
)

NB. ============================================================
NB. Full screen redraw — only the output pane is scrolled / redrawn.
NB. Status bar + input line are left alone except for tui_draw_bottom.
tui_redraw =: monad define
  curs 0                      NB. hide cursor during redraw
  oh =. out_h''
  total =. #TUI_OUTPUT
  NB. clamp scroll to valid range
  TUI_SCROLL =: 0 >. (total - oh) <. TUI_SCROLL
  visible =. oh {. TUI_SCROLL }. TUI_OUTPUT

  reset''
  NB. Only repaint/clear the output area (top oh rows)
  for_i. i.#visible do.
    goxy 0,i
    ceol''
    puts >i{visible
  end.
  NB. clear remaining rows in the output pane
  for_i. (#visible) + i. oh - #visible do.
    goxy 0,i
    ceol''
  end.

  tui_draw_bottom ''
)

NB. ============================================================
NB. Add text to output buffer + auto-scroll to bottom
tui_print =: verb define
  'normal' tui_print y
:
  wrapped =. (TUI_COLS-1) wrap_line y
  TUI_OUTPUT =: TUI_OUTPUT , wrapped
  tui_scroll_bottom ''
)

NB. ============================================================
NB. Echo routing — markdown-render normal LLM output, plain for system lines
tui_echo =: monad define
  NB. check for system/tool lines first
  if. 'Tool call:' +./@E. y do. 'tool'  tui_print y return. end.
  if. 'ERROR'      +./@E. y do. 'error' tui_print y return. end.
  if. 'Asking LLM' +./@E. y do. 'muted' tui_print y return. end.
  if. '  ['        +./@E. y do. 'muted' tui_print y return. end.
  NB. normal output: render markdown then split into lines for buffer
  rendered =. md_render_md_ y
  if. LF ~: {: rendered do. rendered =. rendered , LF end.
  lines =. <;._2 rendered
  for_l. lines do.
    tui_print >l
  end.
)

NB. ============================================================
NB. Process command
tui_process =: monad define
  if. 0=#y do. return. end.
  TUI_INPUT_HISTORY =: TUI_INPUT_HISTORY , <y
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
  hist_save ''
  if. '/' = {.y do.
    cmd =. }.y
    'prompt' tui_print '/ ',cmd
    if. cmd -: 'exit' do. return. end.
    agent cmd
  elseif. '!' = {.y do.
    cmd =. }.y
    'prompt' tui_print '! ',cmd
    agent 'run ',cmd
  else.
    'prompt' tui_print '> ',y
    agent 'ask ',y
  end.
)

NB. ============================================================
NB. Keyboard handler
tui_handle_key =: monad define
  k =. y
  if. k e. 10 13 do.          NB. Enter
    cmd =. TUI_INPUT
    TUI_INPUT =: '' [ TUI_CURSOR =: 0
    if. (cmd-:'exit')+.cmd-:'/exit' do. TUI_RUNNING=:0 return. end.
    tui_process cmd
    tui_redraw''
    return.
  end.

  if. k e. 127 8 do.          NB. Backspace
    if. TUI_CURSOR>0 do.
      TUI_INPUT =: (TUI_CURSOR-1){.TUI_INPUT , TUI_CURSOR}.TUI_INPUT
      TUI_CURSOR =: TUI_CURSOR-1
      tui_draw_bottom ''
    end. return.
  end.

  if. k=3 do. TUI_RUNNING=:0 return. end.   NB. Ctrl-C

  if. k=23 do. mouse_toggle '' return. end.  NB. Ctrl-W toggle mouse wheel

  if. k=21 do.                NB. Ctrl-U (page up)
    oh=.out_h''
    TUI_SCROLL =: 0 >. TUI_SCROLL - (oh - 1)
    tui_redraw'' return.
  end.

  if. k=4 do.                 NB. Ctrl-D (page down)
    oh=.out_h''
    TUI_SCROLL =: ((#TUI_OUTPUT) - oh) <. TUI_SCROLL + (oh - 1)
    tui_redraw'' return.
  end.

  if. k=27 do.                NB. Escape sequence
    if. keyp 0 do.
      k2 =. rkey''
      if. k2=91 do.           NB. [
        if. keyp 0 do.
          k3 =. rkey''
          NB. SGR mouse event: ESC [ <
          if. k3 = 60 do.
            seq =. ''
            while. 1 do.
              c =. a. {~ rkey''
              if. c e. 'Mm' do. break. end.
              seq =. seq , c
            end.
            parts =. ';' cut seq
            btn =. 0 ". > 0 { parts
            my =. 0 ". > 2 { parts  NB. mouse Y (1-based)
            oh =. out_h''
            NB. only scroll if wheel is in output area (row 1..oh)
            if. (btn = 64) *. my <: oh do.
              TUI_SCROLL =: 0 >. TUI_SCROLL - SCROLL_LINES
              tui_redraw''
            elseif. (btn = 65) *. my <: oh do.
              TUI_SCROLL =: ((#TUI_OUTPUT) - oh) <. TUI_SCROLL + SCROLL_LINES
              tui_redraw''
            end.
            return.
          end.
          select. k3
          case. 65 do.        NB. Up
            if. TUI_HISTORY_IDX>0 do.
              TUI_HISTORY_IDX =: TUI_HISTORY_IDX-1
              TUI_INPUT =: >TUI_HISTORY_IDX{TUI_INPUT_HISTORY
              TUI_CURSOR =: #TUI_INPUT
              tui_redraw''
            end.
          case. 66 do.        NB. Down
            if. TUI_HISTORY_IDX < (#TUI_INPUT_HISTORY)-1 do.
              TUI_HISTORY_IDX =: TUI_HISTORY_IDX+1
              TUI_INPUT =: >TUI_HISTORY_IDX{TUI_INPUT_HISTORY
              TUI_CURSOR =: #TUI_INPUT
            else.
              TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
              TUI_INPUT =: '' [ TUI_CURSOR =: 0
            end.
            tui_redraw''
          case. 67 do. if. TUI_CURSOR<#TUI_INPUT do. TUI_CURSOR+:=1 [ tui_draw_bottom '' end.
          case. 68 do. if. TUI_CURSOR>0 do. TUI_CURSOR-:=1 [ tui_draw_bottom '' end.
          case. 51 do.        NB. Delete
            if. keyp 0 do. tilde=.rkey'' [ if. TUI_CURSOR<#TUI_INPUT do.
              TUI_INPUT =: TUI_CURSOR{.TUI_INPUT , (TUI_CURSOR+1)}.TUI_INPUT
              tui_redraw''
            end. end.
          case. 72 do. TUI_CURSOR=:0 [ tui_redraw''
          case. 70 do. TUI_CURSOR=:#TUI_INPUT [ tui_redraw''
          case. 53 do. if. keyp 0 do. tilde=.rkey'' [ tui_handle_key 21 end.
          case. 54 do. if. keyp 0 do. tilde=.rkey'' [ tui_handle_key 4 end.
          end.
        end.
      end.
    end.
    return.
  end.

  if. (k>:32)*.k<127 do.      NB. printable
    ch =. k{a.
    TUI_INPUT =: (TUI_CURSOR{.TUI_INPUT),ch,(TUI_CURSOR}.TUI_INPUT)
    TUI_CURSOR =: TUI_CURSOR+1
    tui_draw_bottom '' return.
  end.
)

NB. ============================================================
NB. Main loop
tui_run =: monad define
  hw =. gethw''
  TUI_LINES =: 0{ hw
  TUI_COLS =: 1{ hw
  raw 1
  curs 0
  cscr''
  reset''
  puts ESC,']0;J-PI',7{a.   NB. set static terminal title (OSC 0)
  NB. no mouse capture — allows normal text selection
  NB. use Ctrl-U/Ctrl-D or PageUp/PageDown to scroll

  hist_load ''
  echo =: tui_echo
  'prompt' tui_print 'J-PI Agent (TUI2 – pure vt)'
  'muted'  tui_print 'Type a question, !cmd, /cmd, Ctrl+C exit, Ctrl+W wheel'
  tui_print ''

  tui_redraw''

  while. TUI_RUNNING do.
    k =. rkey''
    try. tui_handle_key k catch. tui_redraw'' end.
  end.

  hist_save ''
  if. MOUSE_ON do. puts CSI,'?1000l' [ puts CSI,'?1006l' end.
  curs 1
  reset''
  raw 0
  puts CR,LF
  2!:55 (0)          NB. exit jconsole cleanly
)

echo 'tui2 loaded (pure vt escape codes).'