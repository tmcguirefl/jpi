NB. ============================================================
NB. J-PI TUI2 — Pure vt.ijs escape-code TUI (from scratch)
NB. Uses tangentstorm/j-kvm/vt definitions exclusively.
NB. ============================================================

srcdir =. 2!:5 'JPI_SRC'

load srcdir , '/vendor/vt.ijs'   NB. vendored vt.ijs (macOS fixes included)

coinsert 'vt'                     NB. bring all vt verbs into current scope

NB. load the rest of the agent (theme, agent, etc.)
NB. ensure we are in src/ so that agent.ijs and its loads can find siblings
old =. 1!:43 ''
LAUNCH_CWD =: old
1!:44 srcdir
load 'agent.ijs'
load 'theme.ijs'
load 'md.ijs'
1!:44 old
finish_project_scan ''

NB. session.ijs init_session + load_session fired at LOAD time,
NB. while cwd was still srcdir - so the session was named 'src'
NB. and every folder resumed the src conversation. Re-init now
NB. that the launch folder's cwd is restored.
init_session ''
load_session ''

NB. dummy symbol so llm.ijs conditionals never see it as undefined
win_output =: 0
LF =: 10{a.

NB. ============================================================
NB. Global TUI state
NB. Size comes from the terminal NOW (was 0 0, which left out_h
NB. negative before the first redraw: any verb reading TUI_LINES
NB. before tui_redraw - tui_at_bottom, out_h in tests - got
NB. garbage). gethw never throws (ioctl -> stty -> 24 80).
NB. j9.8: control words are definition-body-only, so the guard
NB. lives in a tiny definition.
tui_hw0 =: 3 : 0
  hw =. gethw ''
  if. (2 ~: (# hw)) +. (0 e. hw) do. 24 80 else. hw end.
)
TUI_hw0 =. tui_hw0 ''
TUI_LINES =: 0 { TUI_hw0
TUI_COLS  =: 1 { TUI_hw0
TUI_OUTPUT =: 0 $ <''
TUI_SCROLL =: 0   NB. start at top
TUI_INPUT  =: ''
NB. Image blocks from a paste or /image. ask_verb appends this
NB. to the user message and clears it.
TUI_ATTACH =: ''
TUI_CURSOR =: 0
TUI_HISTORY_IDX =: 0
TUI_INPUT_HISTORY =: 0 $ <''
HISTORY_FILE =: (2!:5 'HOME') , '/.jpi_history'
HISTORY_MAX =: 500
TUI_PREV_OH =: _  NB. previous output height; tracks oh changes for full redraw

NB. Load history from file
hist_load =: monad define
  try.
    if. fexist HISTORY_FILE do.
      raw =. fread HISTORY_FILE
      if. 0 < #raw do.
        if. LF ~: {: raw do. raw =. raw , LF end.
        TUI_INPUT_HISTORY =: <;._2 raw
      end.
    end.
  catch. end.
  TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
)

NB. Save history to file (keep last HISTORY_MAX entries)
hist_save =: monad define
  h =. (- HISTORY_MAX <. #TUI_INPUT_HISTORY) {. TUI_INPUT_HISTORY
  txt =. ; h ,each <LF
  txt fwrite HISTORY_FILE
)
TUI_RUNNING =: 1
MOUSE_ON =: 1      NB. mouse wheel tracking on by default (Ctrl-W toggles to enable text selection)
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
NB. Layout is FIXED: menus draw as overlays on output rows, so the
NB. bottom chrome never moves while typing.
BOTTOM_CHROME =: 5

NB. Max rows the input area may occupy; longer input scrolls a window
INPUT_MAX_H =: 4

NB. Logical input rows: split TUI_INPUT on LF, then wrap each
NB. segment to w columns (wrap_utf8 is cell-accurate). Returns a
NB. boxed list of display rows; cursor row/col derive from the
NB. position of the cursor along this row sequence. This is what
NB. multi-line input (Alt-Enter or Ctrl-J) needs: LF starts a new display row.
input_rows =: monad define
  w =. TUI_COLS
  if. 0 = #TUI_INPUT do. ,< '' return. end.
  NB. split on LF into segments (each later wrapped to w-1 cells).
  NB. 'first',LF,'second' -> 2 rows. A trailing LF in the input is a
  NB. REAL empty row (user pressed Ctrl-J at the end), so it is
  NB. kept: we append LF only for the cut, and drop the appended
  NB. artifact only when the input itself did not end in LF.
  s0 =. TUI_INPUT
  NB. <;._2 on s0,LF yields exactly the LF-separated segments:
  NB. 'a',LF,'b' -> 2 rows; trailing LF -> final empty row is REAL
  NB. (user pressed Ctrl-J at end of input), so nothing is dropped.
  segs =. <;._2 s0 , LF
  r =. 0 $ < ''
  for_s. segs do.
    seg =. > s
    if. 0 = # seg do.
      r =. r , < ''
    else.
      r =. r , ((w - 1) &wrap_utf8) seg
    end.
  end.
  r
)

NB. How many screen rows the current input occupies
input_h =: 3 : 0
  r =. input_rows ''
  1 >. INPUT_MAX_H <. # r
)

out_h =: 3 : 'TUI_LINES - (BOTTOM_CHROME + input_h 0)'

NB. ============================================================
NB. Theme color application
tui_theme =: monad define
  'fg bg' =. theme_colors y
  fgc fg
  bgc bg
)

NB. ============================================================
NB. Lightweight redraw of bottom chrome (avoids flicker)
NB. Layout (dynamic):
NB.   row oh           = separator
NB.   row oh+1 .. +ih  = input line(s)   (ih = input_h 0)
NB.   row oh+ih+1      = separator
NB.   row oh+ih+2      = footer 1  (path + branch)
NB.   row oh+ih+3      = footer 2  (tokens, msgs, scroll, input)
NB.   row oh+ih+4      = footer 3  (session + model, always shown)
tui_draw_bottom =: monad define
  curs 0                      NB. hide cursor during redraw
  NB. Re-read terminal size on EVERY redraw. The old code cached
  NB. TUI_LINES/TUI_COLS and only refreshed on full redraws, so a
  NB. terminal resize (or a gethw failure at startup, when callers
  NB. substituted the 24 80 default) froze the layout mid-size and
  NB. the bottom chrome painted separator bars into the output
  NB. pane on every keystroke. gethw is now a microsecond ioctl
  NB. (see vendor/vt.ijs), so this costs nothing per keystroke.
  NB. Re-read terminal size on EVERY redraw. The old code cached
  NB. TUI_LINES/TUI_COLS and only refreshed on full redraws, so a
  NB. terminal resize (or a gethw failure at startup, when callers
  NB. substituted the 24 80 default) froze the layout mid-size and
  NB. the bottom chrome painted separator bars into the output
  NB. pane on every keystroke. gethw is now a microsecond ioctl
  NB. (see vendor/vt.ijs), so this costs nothing per keystroke.
  hw =. gethw''
  TUI_LINES =: 0{ hw
  TUI_COLS =: 1{ hw
  if. (0 = TUI_LINES) +. (0 = TUI_COLS) do.
    TUI_LINES =: 24
    TUI_COLS =: 80
  end.
  
  w =. TUI_COLS
  ih =. input_h 0
  oh =. out_h''

  NB. ── row oh: top separator ──
  goxy 0, oh
  fgc 8
  puts w repstr_md_ BOX_H_md_
  reset''
  ceol''

  NB. ── row oh+1 .. oh+ih: input lines (window follows cursor) ──
  NB. Multi-line input (Alt-Enter / Ctrl-J): input_rows splits TUI_INPUT on LF
  NB. and wraps each segment; the window shows the last ih rows but
  NB. shifts up so the cursor's row is always visible.
  irows =. input_rows ''
  NB. find display row containing the cursor: walk segments,
  NB. counting each row's characters plus its LF separator
  crow =. (# irows) - 1
  acc =. 0
  for_i. i. # irows do.
    rl =. # > i { irows
    NB. row i covers chars [acc, acc+rl); cursor on/before end -> row i
    if. TUI_CURSOR <: acc + rl do. crow =. i break. end.
    acc =. acc + rl + 1           NB. +1 for the LF between rows
  end.
  base =. 0 >. (# irows) - ih
  if. crow < base do. base =. crow end.
  vis =. base }. irows
  for_r. i. ih do.
    goxy 0, oh + 1 + r
    reset''
    if. r < # vis do.
      puts > r { vis
    end.
    ceol''
  end.
  
  NB. ── autocomplete menu: overlay drawn ABOVE the top separator ──
  NB. (occupies output rows; tui_redraw repaints pane then this overlay)
  opts =. ac_options ''
  h =. 6 <. #opts
  h =. h <. oh
  if. 0 < h do.
    for_i. i. h do.
      goxy 0, (oh - h) + i
      ceol''
      idx =. AC_ST + i
      if. idx = AC_SEL do. tui_theme 'status' else. reset'' end.
      v =. > idx { opts
      if. idx = AC_SEL do. puts ' > /' , v else. puts '   /' , v end.
      reset''
    end.
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
  home =. 2!:5 'HOME'
  if. home -: (#home) {. pwd do. pwd =. '~' , (#home) }. pwd end.
  
  branch =. git_branch ''
  fl1 =. ' ' , pwd
  if. 0 < #branch do. fl1 =. fl1 , ' (' , branch , ')' end.
  if. w < #fl1 do. fl1 =. ((w-3) {. fl1) , '...' end.
  puts fl1
  ceol''
  reset''

  NB. ── row oh+ih+3: footer line 2 — tokens, msgs, scroll, mouse ──
  goxy 0, oh + ih + 3
  fgc 8
  
  fmt_k =. 3 : 'if. y > 999 do. (": <. y % 1000) , ''k'' else. ": y end.'
  
  left =. ' '
  if. 0 < TOTAL_INPUT_TOKENS do.
    left =. left , (utf8_md_ 16b2191) , (fmt_k TOTAL_INPUT_TOKENS) , ' '
  end.
  if. 0 < TOTAL_OUTPUT_TOKENS do.
    left =. left , (utf8_md_ 16b2193) , (fmt_k TOTAL_OUTPUT_TOKENS) , ' '
  end.
  
  NB. add cost
  if. 0 < TOTAL_COST do.
    left =. left , format_cost '' , ' '
  end.
  
  left =. left , (": #HISTORY) , ' msgs '
  
  NB. calculate exact context percent vs ceiling
  ctx_pct =. 0
  if. 0 < #HISTORY do.
    ht =. history_tokens HISTORY
    ctx_pct =. <. 100 * ht % MAX_TOKENS
    if. ctx_pct > 100 do. ctx_pct =. 100 end.
    left =. left , 'Ctx:' , (fmt_k ht) , '/' , (fmt_k MAX_TOKENS) , ' (' , (": ctx_pct) , '%) '
  end.
  
  scroll_pct =. ''
  total =. # tui_wrapped ''
  if. total > oh do.
    pct =. <. 100 * (TUI_SCROLL + oh) % total
    scroll_pct =. ' [Scroll: ' , (": pct) , '%]'
  end.
  left =. left , scroll_pct
  if. -. TUI_FOLLOW do. left =. left , ' [pinned: Ctrl-L]' end.
  NB. keep the hint short: footer2 already risks overflow on narrow screens
  if. MOUSE_ON do. left =. left , ' [wheel]'
  else. left =. left , ' [Alt-Enter=nl]' end.
  NB. Footer 2 previously carried the model/session block on its
  NB. right; it routinely overflowed the line (and before the
  NB. vis_len/take_utf8 fix triggered the scroll-per-keystroke bar
  NB. accumulation). The model info belongs to the chrome, so it
  NB. now has its own row (footer 3) and is ALWAYS visible.
  NB. hard cap at w-1 visible cells (last-column autowrap guard).
  puts (w - 1) take_utf8 left
  ceol''
  reset''

  NB. ── row oh+ih+4: footer line 3 — session + model ──
  goxy 0, oh + ih + 4
  fgc 8
  mdisp =. MODEL
  if. THINK_ON do.
    if. 0 < THINK_BUDGET do.
      mdisp =. mdisp , ' (think ' , (": THINK_BUDGET) , ')'
    else.
      mdisp =. mdisp , ' (think on)'
    end.
  end.
  f3left =. '[' , CURRENT_SESSION , '] '
  f3right =. mdisp , ' '
  pad3 =. 0 >. (w - 1) - ((vis_len f3left) + vis_len f3right)
  NB. same last-column guard: footer 3 is the new bottom row
  puts (w - 1) take_utf8 (f3left , (pad3 # ' ') , f3right)
  ceol''
  reset''

  NB. place cursor on correct input row + column (relative to window base).
  NB. crow was computed above by walking input_rows; the on-screen
  NB. row is crow-base, and the column is the offset within that
  NB. logical row (cursor minus the chars consumed by prior rows).
  rbase =. 0
  for_i. i. crow do.
    rbase =. rbase + (# > i { irows) + 1
  end.
  ccol =. TUI_CURSOR - rbase
  cscreen =. crow - base
  goxy ccol , oh + 1 + cscreen
  curs 1                         NB. show cursor only now, on input line
)

NB. ============================================================
NB. Wrap the (unwrapped) output buffer to the current width.
NB. Returns a flat boxed list of wrapped rows; TUI_SCROLL indexes
NB. into this list, not into TUI_OUTPUT.
tui_wrapped =: monad define
  ; (((TUI_COLS - 1)&wrap_utf8) each) TUI_OUTPUT
)

NB. ============================================================
NB. Scroll to bottom (called after new output is added)
NB. ============================================================
NB. Follow mode. When FOLLOW is 1 (default), new output snaps the
NB. view to the bottom. If the user has scrolled UP to read, new
NB. output no longer yanks the view (it used to call
NB. tui_scroll_bottom unconditionally); the view stays put and the
NB. footer shows [pinned]. Scrolling manually back to the bottom
NB. (or pressing Ctrl-L) resumes follow.
TUI_FOLLOW =: 1

NB. is the view currently at the bottom? (follow position)
tui_at_bottom =: monad define
  oh =. out_h''
  total =. # tui_wrapped ''
  (TUI_SCROLL + oh) >: total
)

NB. snap to bottom only if following (or if forced)
tui_scroll_follow =: monad define
  if. TUI_FOLLOW do.
    tui_scroll_bottom ''
  end.
)

tui_scroll_bottom =: monad define
  NB. gethw never throws (ioctl -> stty -> 24 80; see vendor/vt.ijs)
  hw =. gethw''
  if. (2 ~: (# hw)) +. (0 e. hw) do. hw =. 24 80 end.
  TUI_LINES =: 0{ hw
  TUI_COLS =: 1{ hw
  oh =. out_h''
  TUI_SCROLL =: 0 >. (# tui_wrapped '') - oh
)

TUI_MENU_H =: 0

NB. ============================================================
NB. Full screen redraw — only the output pane is scrolled / redrawn.
NB. Status bar + input line are left alone except for tui_draw_bottom.
tui_redraw =: monad define
  curs 0                      NB. hide cursor during redraw
  NB. gethw never throws (ioctl -> stty -> 24 80; see vendor/vt.ijs)
  hw =. gethw''
  if. (2 ~: (# hw)) +. (0 e. hw) do. hw =. 24 80 end.
  TUI_LINES =: 0{ hw
  TUI_COLS =: 1{ hw
  oh =. out_h''
  TUI_PREV_OH =: oh           NB. track for update_ac_ui stale-bar detection
  rows =. tui_wrapped ''
  total =. # rows
  NB. clamp scroll to valid range
  TUI_SCROLL =: 0 >. (total - oh) <. TUI_SCROLL
  visible =. oh {. TUI_SCROLL }. rows

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
NB. Add text to output buffer + auto-scroll to bottom.
NB. Lines are stored UNWRAPPED (whole logical lines, with style
NB. colors embedded). Wrapping happens at render time
NB. (tui_wrapped) so a resize reflows the buffer correctly, and
NB. ANSI/UTF-8 are never split mid-sequence (wrap_utf8).
NB. Cap on in-TUI buffer: long sessions are read via /less or /nvim.
TUI_MAX_LINES =: 2000

NB. Output line styles -> SGR color (256-color palette, as in md.ijs)
style_sgr =: monad define
  select. y
  case. 'error' do. CSI , '38;5;1m'
  case. 'tool'  do. CSI , '38;5;6m'
  case. 'muted' do. CSI , '38;5;8m'
  case. do. ''
  end.
)

NB. Unified-diff coloring. LLM output often quotes diffs (git diff,
NB. my edit results). Lines starting with '+' get green, '-' red,
NB. '@@' dim. Only applied to 'normal' (markdown) output lines that
NB. aren't already styled, and only when the diff marker is at the
NB. very start of the visible text (ANSI prefixes stripped first).
diff_sgr =: monad define
  bare =. strip_ansi y
  if. (0 < # bare) *. ('+' = {. bare) do. CSI , '38;5;2m' return. end.
  if. (0 < # bare) *. ('-' = {. bare) do. CSI , '38;5;1m' return. end.
  if. (2 < # bare) *. ('@@' -: 2 {. bare) do. CSI , '38;5;8m' return. end.
  ''
)

tui_print =: verb define
  'normal' tui_print y
:
  for_l. split_lines y do.
    line =. > l
    if. (x -: 'normal') *. (0 < # diff_sgr line) do.
      line =. (diff_sgr line) , line , (CSI , '0m')
    else.
      if. 0 < # style_sgr x do.
        line =. (style_sgr x) , line , (CSI , '0m')
      end.
    end.
    TUI_OUTPUT =: TUI_OUTPUT , < line
  end.
  NB. keep the buffer bounded
  if. TUI_MAX_LINES < #TUI_OUTPUT do.
    TUI_OUTPUT =: (- TUI_MAX_LINES) {. TUI_OUTPUT
  end.
  tui_scroll_follow ''
)

NB. ============================================================
NB. Echo routing — markdown-render normal LLM output, plain for system lines
tui_echo =: monad define
  NB. check for system/tool lines first
  if. 'Tool call:' +./@E. y do. 'tool'  tui_print y return. end.
  if. 'ERROR'      +./@E. y do. 'error' tui_print y return. end.
  if. 'Asking LLM' +./@E. y do. 'muted' tui_print y return. end.
  if. 'Compacting' +./@E. y do. 'muted' tui_print y return. end.
  if. 'Context '   +./@E. y do. 'muted' tui_print y return. end.
  if. '  ['        +./@E. y do. 'muted' tui_print y return. end.
  NB. normal output: render markdown then split into lines for buffer
  rendered =. md_render_md_ y
  if. LF ~: {: rendered do. rendered =. rendered , LF end.
  lines =. <;._2 rendered
  for_l. lines do.
    tui_print >l
  end.
)

NB. Live tokens. STREAM_VIS is the raw text of the current reply.
NB. STREAM_BASE is the first TUI_OUTPUT line that belongs to it.
STREAM_VIS =: ''
STREAM_BASE =: 0

tui_stream_add =: monad define
  if. 0 = # y do. '' return. end.
  if. 0 = # STREAM_VIS do. STREAM_BASE =: # TUI_OUTPUT end.
  STREAM_VIS =: STREAM_VIS , y
  shown =. STREAM_VIS
  if. LF ~: {: shown do. shown =. shown , LF end.
  lines =. <;._2 shown
  if. STREAM_BASE > # TUI_OUTPUT do. STREAM_BASE =: # TUI_OUTPUT end.
  TUI_OUTPUT =: (STREAM_BASE {. TUI_OUTPUT) , lines
  tui_scroll_follow ''
  tui_redraw ''
  ''
)

NB. Replace the plain token lines with the markdown rendering.
tui_stream_end =: monad define
  if. 0 < # STREAM_VIS do.
    rendered =. STREAM_VIS
    if. 3 = 4!:0 <'md_render_md_' do. rendered =. md_render_md_ STREAM_VIS end.
    if. (0 = # rendered) +. LF ~: {: rendered do. rendered =. rendered , LF end.
    lines =. <;._2 rendered
    if. STREAM_BASE > # TUI_OUTPUT do. STREAM_BASE =: # TUI_OUTPUT end.
    TUI_OUTPUT =: (STREAM_BASE {. TUI_OUTPUT) , lines
    STREAM_VIS =: ''
  end.
  tui_redraw ''
  ''
)

NB. ============================================================
NB. Open TUI output in an external pager (auto-detects best available).
NB. Temporarily leaves raw mode + disables mouse so the external
NB. program owns the terminal. Restores TUI state on exit.
NB. Suffixed with the per-process PID so concurrent jpi instances
NB. don't clobber each other's pager/editor temp files.
tui_tmp_suffix =: monad define
  try.
    '_' , _1 }. 2!:0 'echo $PPID'
  catch.
    '_' , ": ? 1e6
  end.
)
TUI_TMP_SUFFIX  =: tui_tmp_suffix ''
TUI_PAGER_FILE  =: jpath '~temp/jpi_pager' , TUI_TMP_SUFFIX , '.txt'
TUI_EDIT_CTX    =: jpath '~temp/jpi_edit_ctx' , TUI_TMP_SUFFIX , '.txt'
TUI_EDIT_PROMPT =: jpath '~temp/jpi_edit_prompt' , TUI_TMP_SUFFIX , '.txt'

NB. Detect best available pager at load time.
NB. Priority: $PAGER env var (if set to something useful), then less
NB. (ANSI color support via -R), then nvim -R, then more.
NB. $PAGER=cat is treated as unset — it's not an interactive pager.
tui_detect_pager =: monad define
  p =. > 2!:5 'PAGER'
  if. (0 < #p) *. -. (<p) e. 'cat';'more' do. p return. end.
  r =. 2!:0 'which less 2>/dev/null'
  if. 0 < # r -. ' ' , LF do. 'less' return. end.
  r =. 2!:0 'which nvim 2>/dev/null'
  if. 0 < # r -. ' ' , LF do. 'nvim' return. end.
  'more'
)
TUI_PAGER =: tui_detect_pager ''

NB. Strip ANSI escape codes from a string (for nvim/more paths)
NB. strip_ansi lives in utils.ijs now.

tui_pager =: monad define
  NB. y = line count (0 or empty = all)
  lines =. TUI_OUTPUT
  if. (0 < #y) *. (0 < 0 ". y) do.
    lines =. (- (0 ". y) <. #lines) {. lines
  end.
  text =. ; lines ,each <LF
  text fwrite TUI_PAGER_FILE
  NB. leave raw mode, disable mouse, reset terminal for the pager
  if. MOUSE_ON do. puts CSI,'?1000l' [ puts CSI,'?1006l' end.
  raw 0
  reset''
  puts CR,LF
  NB. spawn less via 2!:1 (spawn): inherits stdin/stdout/stderr directly,
  NB. giving the pager full terminal access. 2!:0 would capture stdout
  NB. via pipe and break interactive programs.
  try.
    2!:1 'less -R ' , TUI_PAGER_FILE
  catch. end.
  NB. restore TUI terminal state
  raw 1
  if. MOUSE_ON do. puts CSI,'?1000h' [ puts CSI,'?1006h' end.
  tui_redraw ''
)

NB. ============================================================
NB. Open nvim with a split: context buffer (top, read-only) +
NB. prompt buffer (bottom, editable). :w to save the prompt, :q to
NB. quit and send it to the LLM. If you :q without :w, nothing is sent.
tui_edit =: monad define
  NB. write context (TUI_OUTPUT, ANSI stripped) to file
  text =. strip_ansi ; TUI_OUTPUT ,each <LF
  text fwrite TUI_EDIT_CTX
  NB. start with empty prompt file
  '' fwrite TUI_EDIT_PROMPT
  NB. leave raw mode, disable mouse, reset terminal
  if. MOUSE_ON do. puts CSI,'?1000l' [ puts CSI,'?1006l' end.
  raw 0
  reset''
  puts CR,LF
  NB. nvim layout: prompt file is the main buffer, context split above
  NB. as read-only. Explicit :w to save the prompt — no autowrite magic.
  try.
    2!:1 'nvim ' , TUI_EDIT_PROMPT , ' -c "above split ' , TUI_EDIT_CTX , '" -c "setlocal ro" -c "wincmd j" -c "resize 8"'
  catch. end.
  NB. read prompt file — if non-empty (user :w'd), send as LLM question
  prompt =. fread TUI_EDIT_PROMPT
  NB. restore TUI terminal state
  raw 1
  if. MOUSE_ON do. puts CSI,'?1000h' [ puts CSI,'?1006h' end.
  tui_redraw ''
  if. 0 < #prompt -. ' ' , LF , CR , TAB do.
    prompt =. prompt -. CR
    'prompt' tui_print '> ' , prompt
    agent 'ask ' , prompt
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
    NB. deb: the autocomplete selector inserts '/cmd ' (trailing
    NB. space, for commands that take arguments) - argless commands
    NB. must still match exactly, so strip the trailing blanks here
    cmd =. deb }.y
    'prompt' tui_print '/ ',cmd
    if. cmd -: 'exit' do. TUI_RUNNING =: 0 return. end.
    NB. local TUI commands (not passed to agent)
    if. 'less' -: cmd do. tui_pager '' return. end.
    if. 'less ' -: (5 {. cmd) do. tui_pager (5 }. cmd) return. end.
    if. 'nvim' -: cmd do. tui_edit '' return. end.
    if. 'retry' -: cmd do. tui_recall_last_prompt '' return. end.
    agent cmd
  elseif. '!' = {.y do.
    NB. ! keeps the command and its output in the conversation.
    NB. !! only prints the output.
    if. '!!' -: 2 {. y do.
      cmd =. deb 2 }. y
      'prompt' tui_print '!! ' , cmd
      agent 'run ' , cmd
    else.
      cmd =. deb }. y
      'prompt' tui_print '! ' , cmd
      if. -. is_safe cmd do.
        echo 'Command blocked for safety.'
        return.
      end.
      out =. run_cmd_str cmd
      echo out
      if. 3 = 4!:0 <'hist_add' do.
        hist_add 'user' mk_msg ('! ' , cmd , LF , out)
      end.
    end.
  else.
    'prompt' tui_print '> ',y
    agent 'ask ',y
  end.
)

NB. ============================================================
NB. Mid-run steering capture (non-blocking; called from llm_call's
NB. spinner loop while an API request is in flight). Typed chars
NB. compose in the NORMAL INPUT LINE (TUI_INPUT, drawn live by
NB. tui_draw_bottom) - the Mistral Vibe flow: the message is
NB. queued visibly in the input box, and Enter steers. Enter
NB. commits the line to STEER_MSG (llm_ask injects it as a user
NB. message at the next iteration boundary); an uncommitted draft
NB. simply remains in the input box for the next prompt.
NB.
NB. Scrolling while an LLM call is in flight is ALSO handled here
NB. (the old version skipped exactly 2 bytes after ESC and then
NB. typed the REST of SGR wheel sequences into the input box,
NB. and dropped Ctrl-U/D/L entirely - which made follow mode look
NB. broken: the user scrolled, nothing scrolled, and output kept
NB. snapping to the bottom because TUI_FOLLOW was never cleared).
NB.
NB. Recognized: wheel events (SGR ESC [ < btn ; x ; y M), Ctrl-U
NB. (page up, pins), Ctrl-D (page down, resumes at bottom), Ctrl-L
NB. (snap to bottom + resume), Enter (steer), Backspace, printable.
NB. Anything else (arrow keys, etc.) is swallowed whole.
NB. Bare Esc returns 1 so the caller can kill the in-flight curl.

tui_steer_poll =: monad define
  NB. 1 when the user hit bare Esc. llm_call kills the curl.
  NB. Return an integer: if. treats an empty result as true.
  esc =. 0
  while. keyp 0 do.
    k =. rkey ''
    NB. Ctrl-U: page up + pin
    if. k = 21 do.
      oh =. out_h ''
      TUI_SCROLL =: 0 >. TUI_SCROLL - (oh - 1)
      TUI_FOLLOW =: 0
      if. -. keyp 0 do. tui_redraw '' end.
      continue.
    end.
    NB. Ctrl-D: page down, resume follow at bottom
    if. k = 4 do.
      oh =. out_h ''
      TUI_SCROLL =: ((# tui_wrapped '') - oh) <. TUI_SCROLL + (oh - 1)
      if. tui_at_bottom '' do. TUI_FOLLOW =: 1 end.
      if. -. keyp 0 do. tui_redraw '' end.
      continue.
    end.
    NB. Ctrl-L: snap to bottom + resume follow
    if. k = 12 do.
      TUI_FOLLOW =: 1
      tui_scroll_bottom ''
      if. -. keyp 0 do. tui_redraw '' end.
      continue.
    end.
    if. k = 27 do.                  NB. Escape sequence
      NB. nothing queued after ESC: bare Esc cancels the request
      if. -. keyp 0 do.
        esc =. 1
        break.
      end.
      k2 =. rkey ''
      if. k2 = 91 do.               NB. [
        if. -. keyp 0 do. continue. end.
        k3 =. rkey ''
        if. k3 = 60 do.             NB. < : SGR mouse event
          NB. consume params through the terminating M/m
          seq =. ''
          while. 1 do.
            c =. a. {~ rkey ''
            if. c e. 'Mm' do. break. end.
            seq =. seq , c
          end.
          parts =. ';' cut seq
          btn =. 0 ". > 0 { parts
          tui_wheel_scroll btn
        elseif. k3 = 50 do.
          tui_paste_marker k3
        end.
        NB. any other ESC [ x (arrows, etc.): rest swallowed with x
      else.
        NB. Alt+Enter queues a follow-up for after this whole task.
        NB. Enter, above, steers at the next tool boundary.
        if. k2 e. 10 13 do.
          if. 0 < # TUI_INPUT do.
            FOLLOW_MSG =: TUI_INPUT
            TUI_INPUT =: ''
            TUI_CURSOR =: 0
            'muted' tui_print '(follow-up queued: ' , FOLLOW_MSG , ')'
            if. -. keyp 0 do. tui_redraw '' end.
          end.
        end.
      end.
      continue.
    end.
    if. k e. 10 13 do.               NB. Enter: steer
      if. 0 < # TUI_INPUT do.
        STEER_MSG =: TUI_INPUT
        TUI_INPUT =: ''
        TUI_CURSOR =: 0
        'muted' tui_print '(steering queued: ' , STEER_MSG , ')'
        if. -. keyp 0 do. tui_redraw '' end.
      end.
    elseif. k = 127 do.             NB. Backspace
      TUI_INPUT =: }: TUI_INPUT
      TUI_CURSOR =: # TUI_INPUT
    elseif. 31 < k do.              NB. printable
      TUI_INPUT =: TUI_INPUT , (a. {~ k)
      TUI_CURSOR =: # TUI_INPUT
    end.
    if. -. keyp 0 do. tui_draw_bottom '' end.
  end.
  esc
)

NB. ============================================================
NB. /retry - recall the last prompt into the input box for editing
NB. (not auto-resend: edit it, then Enter submits it like any
NB. prompt). Scans the typed-input history backwards for the last
NB. entry that is not a /command or !command. Input history is
NB. persistent (~/.jpi_history), so the recall survives restarts.

tui_recall_last_prompt =: monad define
  idx =. # TUI_INPUT_HISTORY
  found =. ''
  while. idx > 0 do.
    idx =. idx - 1
    e =. > idx { TUI_INPUT_HISTORY
    if. ('/' ~: {. e) *. ('!' ~: {. e) do. found =. e break. end.
  end.
  if. 0 = # found do.
    'muted' tui_print '(no previous prompt to retry)'
    tui_redraw ''
    '' return.
  end.
  TUI_INPUT =: found
  TUI_CURSOR =: # TUI_INPUT
  tui_redraw ''
  ''
)

NB. ============================================================
NB. TUI Filter Menu - type-to-filter selection (fzf-like).
NB. For long lists (e.g. the model picker with hundreds of
NB. HostYourAI entries): type a substring to narrow live, TAB
NB. extends the filter to the common prefix of the matches
NB. (bash-completion style), arrows move within the filtered
NB. list, Enter selects, Backspace edits, ESC aborts.
NB. x = prompt string, y = list of choices (boxed strings)
NB. returns the index of the selected item IN THE ORIGINAL
NB. LIST, or _1 if aborted.

NB. y = selection ; window start ; visible rows.
NB. The selection stays on a drawn row. sel - rows + 1 is
NB. sel-(rows+1) in J, which starts the window one row too
NB. high: arrowing past the first screen drops the highlight.
fm_window =: monad define
  'sel st rows' =. y
  if. rows < 1 do. rows =. 1 end.
  if. sel < st do. st =. sel end.
  if. sel >: st + rows do.
    st =. 0 >. sel - (rows - 1)
  end.
  st
)

fm_match =: 4 : '+./ (tolower x) E. tolower y'  NB. x flt-in y

NB. longest common prefix of boxed strings
fm_lcp =: 3 : 0
  if. 0 = # y do. '' return. end.
  if. 1 = # y do. > {. y return. end.
  n =. <./ # &> y
  if. 0 = n do. '' return. end.
  cut =. n {. &.> y             NB. each item cut to n chars (boxed)
  m   =. > cut                  NB. open: n-char matrix, items as rows
  c   =. |: m                   NB. transpose: rows = position columns
  NB. a position differs iff its column-row has more than one
  NB. distinct item. NEVER ~:/"1 here: insert is
  NB. right-associative, so for three identical chars it
  NB. gives a~:(a~:a)=1 - the fold trap from the manual's
  NB. insert section.
  d =. (1 < #@~.)"1 c
  p =. d i. 1                  NB. first differing position = prefix length
  p {. > {. y                  NB. TAKE the prefix ({. take, not { select)
)

tui_filter_menu =: dyad define
  if. 0 = # y do. _1 return. end.
  curs 0
  flt =. ''
  sel =. 0
  st  =. 0
  h =. 10 <. # y
  w =. TUI_COLS

  TUI_MENU_H =: h + 2
  tui_redraw''

  while. 1 do.
    NB. recompute matches on the current filter
    NB. BOND the filter as fm_match's left argument, then
    NB. each: (flt&fm_match) is a monad, so each opens one
    NB. item at a time. NEVER (flt fm_match each) y: each
    NB. pairs x's ITEMS with y's items - and never parens
    NB. around a noun-verb pair (the §3 fragment).
    matches =. I. ; (flt&fm_match each) y
    if. sel >: # matches do. sel =. 0 >. (# matches) - 1 end.
    if. 0 < # matches do.
      if. sel >: # matches do. sel =. (# matches) - 1 end.
    end.
    oh =. out_h ''
    vis =. 1 >. h <. (oh - 2)
    st =. fm_window sel ; st ; vis

    if. -. keyp 0 do.
      menu_y =. oh - vis - 2

      NB. filter line: prompt + [filter] + counts
      goxy 0, menu_y
      ceol''
      tui_theme 'prompt'
      puts ' ' , x , ' [' , flt , ']  (' , (": # matches) , '/' , (": # y) , ')'
      reset''
      goxy 0, menu_y + 1
      ceol''
      fgc 8
      puts ' type=filter  TAB=complete  Enter=select  BS=edit  arrows=move  ESC=abort'
      reset''

      for_i. i. vis do.
        goxy 0, menu_y + 2 + i
        ceol''
        idx =. st + i
        if. (idx >: 0) *. idx < # matches do.
          v =. > idx { matches { y
          if. idx = sel do.
            tui_theme 'status'
            puts ' > ' , (w - 4) {. v
          else.
            reset''
            puts '   ' , (w - 4) {. v
          end.
          reset''
        end.
      end.
    end.

    k =. rkey''
    NB. printable: extend the filter
    if. (k >: 32) *. (k <: 126) do.
      flt =. flt , (a. {~ k)
      sel =. 0
      st =. 0
      continue.
    end.
    NB. backspace
    if. (k = 127) +. (k = 8) do.
      flt =. }: flt
      sel =. 0
      st =. 0
      continue.
    end.
    NB. TAB: extend to the common prefix of current matches
    if. k = 9 do.
      if. 0 < # matches do.
        cp =. fm_lcp matches { y
        if. (# flt) < # cp do.
          flt =. cp
          sel =. 0
          st =. 0
        end.
      end.
      continue.
    end.
    NB. Enter: select
    if. k = 13 do.
      TUI_MENU_H =: 0
      tui_redraw''
      if. 0 < # matches do. (sel { matches) return. end.
      _1 return.
    end.
    NB. ESC: arrow sequences move; bare ESC aborts
    if. k = 27 do.
      if. keyp 0 do.
        k2 =. rkey''
        if. k2 = 91 do.
          if. keyp 0 do.
            k3 =. rkey''
            if. k3 = 65 do. sel =. 0 >. sel - 1
            elseif. k3 = 66 do. sel =. ((# matches) - 1) <. sel + 1
            end.
          end.
        end.
      else.
        TUI_MENU_H =: 0
        tui_redraw''
        _1 return.
      end.
    end.
    NB. Ctrl-C aborts (matches tui_select_menu)
    if. k = 3 do.
      TUI_MENU_H =: 0
      tui_redraw''
      _1 return.
    end.
  end.
)


NB. ============================================================
NB. TUI Select Menu - Modal popup for choice selection
NB. (arrow-key navigation; see tui_filter_menu above for the
NB. type-to-filter variant used on long lists)
tui_select_menu =: dyad define
  NB. x = prompt string, y = list of choices (boxed strings)
  NB. returns the index of selected item, or _1 if aborted
  curs 0
  sel =. 0
  st  =. 0
  h =. 10 <. #y
  w =. TUI_COLS
  
  if. 0 = #y do. _1 return. end.

  NB. Menu draws as an overlay on output rows above the bottom chrome
  TUI_MENU_H =: h + 1
  tui_redraw''

  while. 1 do.
    oh =. out_h ''
    vis =. 1 >. h <. (oh - 1)
    st =. fm_window sel ; st ; vis
    if. -. keyp 0 do.
      menu_y =. oh - vis - 1
      
      goxy 0, menu_y
      ceol''
      tui_theme 'prompt'
      puts ' ' , x
      reset''
      
      for_i. i. vis do.
        goxy 0, menu_y + 1 + i
        ceol''
        idx =. st + i
        if. (idx >: 0) *. idx < # y do.
          if. idx = sel do. tui_theme 'status' else. reset'' end.
          v =. > idx { y
          if. idx = sel do. puts ' > ' , (w-4) {. v else. puts '   ' , (w-4) {. v end.
          reset''
        end.
      end.
    end.
    
    k =. rkey''
    if. k = 13 do.
      TUI_MENU_H =: 0
      tui_redraw''
      sel return.
    end.
    if. k = 3 do.
      TUI_MENU_H =: 0
      tui_redraw''
      _1 return.
    end.
    if. k = 27 do.
      if. keyp 0 do.
        k2 =. rkey''
        if. k2 = 91 do.
          if. keyp 0 do.
            k3 =. rkey''
            if. k3 = 60 do. NB. mouse event
              seq =. ''
              while. 1 do.
                c =. a. {~ rkey''
                if. c e. 'Mm' do. break. end.
                seq =. seq , c
              end.
              parts =. ';' cut seq
              btn =. 0 ". > 0 { parts
              is_wheel_up =. (btn >: 64) *. (0 = btn 17 b. 3)
              is_wheel_down =. (btn >: 64) *. (1 = btn 17 b. 3)
              if. is_wheel_up do. sel =. 0 >. sel - 1
              elseif. is_wheel_down do. sel =. ((#y)-1) <. sel + 1
              end.
            elseif. k3 = 65 do. sel =. 0 >. sel - 1 
            elseif. k3 = 66 do. sel =. ((#y)-1) <. sel + 1 
            end.
          end.
        end.
      else.
        TUI_MENU_H =: 0
        tui_redraw''
        _1 return.
      end.
    end.
    
  end.
)

AC_SEL =: 0
AC_ST =: 0
ac_options =: monad define
  if. 0 = #TUI_INPUT do. 0$<'' return. end.
  if. '/' ~: {. TUI_INPUT do. 0$<'' return. end.
  if. ' ' e. TUI_INPUT do. 0$<'' return. end.
  w =. }. TUI_INPUT
  r =. 0$<''
  NB. include local TUI commands first (pager, nvim, retry, exit)
  for_a. 'less';'nvim';'retry';'exit' do.
    opt =. > a
    if. w -: (#w) {. opt do. r =. r , a end.
  end.
  for_a. ACTIONS do.
    opt =. > a
    if. w -: (#w) {. opt do. r =. r , a end.
  end.
  r
)

update_ac_ui =: monad define
  opts =. ac_options ''
  h =. 6 <. #opts
  prev_h =. TUI_MENU_H
  if. 0 < h do. TUI_MENU_H =: h else. TUI_MENU_H =: 0 end.
  
  if. AC_SEL >: #opts do. AC_SEL =: 0 >. (#opts) - 1 end.
  if. h > 0 do.
    if. AC_SEL < AC_ST do. AC_ST =: AC_SEL end.
    if. AC_SEL >: AC_ST + h do. AC_ST =: AC_SEL - (h - 1) end.
  end.
  
  NB. Full redraw when the menu height changed OR the output area
  NB. height changed (input wrapped/unwrapped).  tui_draw_bottom
  NB. alone cannot clear stale separator bars left in the output
  NB. pane when oh shifts.
  cur_oh =. out_h''
  if. (prev_h ~: TUI_MENU_H) +. (TUI_PREV_OH ~: cur_oh) do.
    TUI_PREV_OH =: cur_oh
    tui_redraw''
  else.
    tui_draw_bottom''
    TUI_PREV_OH =: cur_oh
  end.
)

NB. ============================================================
NB. Insert a newline at the cursor (multi-line input). Shared by
NB. Ctrl-J (byte 10) and Alt-Enter (ESC CR / ESC LF).
tui_insert_nl =: monad define
  TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , LF , (TUI_CURSOR }. TUI_INPUT)
  TUI_CURSOR =: TUI_CURSOR + 1
  update_ac_ui ''
)

NB. ============================================================
NB. Wheel scroll: shared by the main key handler and the mid-run
NB. steering poll. y = SGR mouse button code (64 = wheel up,
NB. 65 = wheel down). Respects follow mode: wheel up pins
NB. (TUI_FOLLOW =: 0), wheel down reaching bottom resumes it.
NB. Redraws only when no more input is queued.
tui_wheel_scroll =: monad define
  btn =. y
  oh =. out_h ''
  NB. scroll regardless of mouse position (only one scrollable region)
  is_wheel_up =. (btn >: 64) *. (0 = btn 17 b. 3)
  is_wheel_down =. (btn >: 64) *. (1 = btn 17 b. 3)
  if. is_wheel_up do.
    TUI_SCROLL =: 0 >. TUI_SCROLL - SCROLL_LINES
    TUI_FOLLOW =: 0         NB. manual scroll: stop following
    if. -. keyp 0 do. tui_redraw'' end.
  elseif. is_wheel_down do.
    TUI_SCROLL =: ((# tui_wrapped '') - oh) <. TUI_SCROLL + SCROLL_LINES
    if. tui_at_bottom '' do. TUI_FOLLOW =: 1 end.
    if. -. keyp 0 do. tui_redraw'' end.
  end.
)

NB. ESC [ 200 ~ ... ESC [ 201 ~  is a bracketed paste. y is the
NB. byte after '['. Returns 1 when that byte started a paste
NB. (the body is consumed either way once the byte is '2').
tui_paste_marker =: monad define
  if. y ~: 50 do. 0 return. end.
  seq =. '2'
  while. keyp 50 do.
    c =. a. {~ rkey ''
    if. '~' = c do. break. end.
    seq =. seq , c
    if. 6 < # seq do. break. end.
  end.
  if. '200' -: seq do.
    tui_read_paste_body ''
  end.
  1
)

NB. Read until ESC [ 201 ~. A 400ms gap ends a broken paste.
tui_read_paste_body =: monad define
  buf =. ''
  while. keyp 400 do.
    k =. rkey ''
    if. k = 27 do.
      if. -. keyp 50 do.
        buf =. buf , 27 { a.
        continue.
      end.
      k2 =. rkey ''
      if. k2 ~: 91 do.
        buf =. buf , (27 { a.) , k2 { a.
        continue.
      end.
      seq =. ''
      while. keyp 50 do.
        c =. a. {~ rkey ''
        if. '~' = c do. break. end.
        seq =. seq , c
        if. 6 < # seq do. break. end.
      end.
      if. '201' -: seq do. break. end.
      buf =. buf , (27 { a.) , '[' , seq
    else.
      buf =. buf , k { a.
    end.
  end.
  tui_apply_paste buf
  ''
)

NB. Insert a paste. An image becomes a short note plus TUI_ATTACH.
tui_apply_paste =: monad define
  ins =. y
  att =. ''
  if. 3 = 4!:0 <'accept_paste' do.
    pair =. accept_paste y
    ins =. > {. pair
    att =. > {: pair
  end.
  if. 0 < # att do.
    if. 0 < # TUI_ATTACH do.
      TUI_ATTACH =: TUI_ATTACH , LF , att
    else.
      TUI_ATTACH =: att
    end.
    if. '[image: ' -: 8 {. ins do.
      p =. 8 }. ins
      if. ']' = {: p do. p =. }: p end.
      if. 3 = 4!:0 <'display_image' do.
        display_image p
      end.
    end.
  end.
  TUI_INPUT =: (TUI_CURSOR {. TUI_INPUT) , ins , TUI_CURSOR }. TUI_INPUT
  TUI_CURSOR =: TUI_CURSOR + # ins
  if. 3 = 4!:0 <'tui_redraw' do. tui_redraw '' end.
  ''
)

NB. ============================================================
NB. Keyboard handler
tui_handle_key =: monad define
  k =. y
  if. k = 10 do.              NB. Ctrl-J: insert newline (multi-line input)
    tui_insert_nl ''
    return.
  end.
  if. k = 13 do.              NB. Enter: send
    opts =. ac_options ''
    if. 0 < #opts do.
      cmd =. '/' , (> AC_SEL { opts) , ' '
      TUI_INPUT =: cmd
      TUI_CURSOR =: #TUI_INPUT
      update_ac_ui ''
      return.
    end.

    cmd =. TUI_INPUT
    TUI_INPUT =: '' [ TUI_CURSOR =: 0
    update_ac_ui ''
    if. (cmd-:'exit')+.cmd-:'/exit' do. TUI_RUNNING=:0 return. end.
    tui_process cmd
    tui_redraw''
    return.
  end.

  if. k e. 127 8 do.          NB. Backspace
    if. TUI_CURSOR>0 do.
      TUI_INPUT =: ((TUI_CURSOR-1){.TUI_INPUT) , (TUI_CURSOR}.TUI_INPUT)
      TUI_CURSOR =: TUI_CURSOR-1
      update_ac_ui ''
    end. return.
  end.

  if. k=3 do. TUI_RUNNING=:0 return. end.   NB. Ctrl-C

  if. k = 9 do.               NB. Tab: complete the path at the cursor
    if. 3 = 4!:0 <'tui_tab_complete' do. tui_tab_complete '' end.
    return.
  end.

  if. k=23 do. mouse_toggle '' return. end.  NB. Ctrl-W toggle mouse wheel

  if. k=12 do.                NB. Ctrl-L: re-enable follow + redraw
    TUI_FOLLOW =: 1
    tui_scroll_bottom ''
    tui_redraw''
    return.
  end.

  if. k=21 do.                NB. Ctrl-U (page up)
    oh=.out_h''
    TUI_SCROLL =: 0 >. TUI_SCROLL - (oh - 1)
    TUI_FOLLOW =: 0           NB. user took control: stop auto-follow
    if. -. keyp 0 do. tui_redraw'' end.
    return.
  end.

  if. k=4 do.                 NB. Ctrl-D (page down)
    oh=.out_h''
    TUI_SCROLL =: ((# tui_wrapped '') - oh) <. TUI_SCROLL + (oh - 1)
    if. tui_at_bottom '' do. TUI_FOLLOW =: 1 end.
    if. -. keyp 0 do. tui_redraw'' end.
    return.
  end.

  if. k=27 do.                NB. Escape sequence
    if. keyp 0 do.
      k2 =. rkey''
      NB. Alt-Enter arrives as ESC CR on xterm-family terminals with
      NB. "meta sends escape" (the common default). ESC LF is the
      NB. Alt-Ctrl-J variant. Both insert a newline - multi-line
      NB. input without losing the Enter-sends binding.
      if. (k2 = 13) +. (k2 = 10) do.
        tui_insert_nl ''
        return.
      end.
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
            NB. scroll logic shared with tui_steer_poll: tui_wheel_scroll
            tui_wheel_scroll btn
            return.
          end.
          if. k3 = 50 do.
            tui_paste_marker k3
            return.
          end.
          select. k3
          case. 65 do.        NB. Up
            opts =. ac_options ''
            if. 0 < #opts do.
              AC_SEL =: 0 >. AC_SEL - 1
              update_ac_ui''
            else.
              if. TUI_HISTORY_IDX>0 do.
                TUI_HISTORY_IDX =: TUI_HISTORY_IDX-1
                TUI_INPUT =: >TUI_HISTORY_IDX{TUI_INPUT_HISTORY
                TUI_CURSOR =: #TUI_INPUT
                update_ac_ui''
              end.
            end.
          case. 66 do.        NB. Down
            opts =. ac_options ''
            if. 0 < #opts do.
              AC_SEL =: ((#opts)-1) <. AC_SEL + 1
              update_ac_ui''
            else.
              if. TUI_HISTORY_IDX < (#TUI_INPUT_HISTORY)-1 do.
                TUI_HISTORY_IDX =: TUI_HISTORY_IDX+1
                TUI_INPUT =: >TUI_HISTORY_IDX{TUI_INPUT_HISTORY
                TUI_CURSOR =: #TUI_INPUT
              else.
                TUI_HISTORY_IDX =: #TUI_INPUT_HISTORY
                TUI_INPUT =: '' [ TUI_CURSOR =: 0
              end.
              update_ac_ui''
            end.
          case. 67 do. if. TUI_CURSOR<#TUI_INPUT do. tui_draw_bottom '' [ TUI_CURSOR =: TUI_CURSOR+1 end.
          case. 68 do. if. TUI_CURSOR>0 do. tui_draw_bottom '' [ TUI_CURSOR =: TUI_CURSOR-1 end.
          case. 51 do.        NB. Delete
            if. keyp 0 do. 
              tilde=.rkey'' 
              if. TUI_CURSOR<#TUI_INPUT do.
                TUI_INPUT =: (TUI_CURSOR{.TUI_INPUT) , ((TUI_CURSOR+1)}.TUI_INPUT)
                tui_redraw''
              end. 
            end.
          case. 72 do. tui_redraw'' [ TUI_CURSOR=:0
          case. 70 do. tui_redraw'' [ TUI_CURSOR=:#TUI_INPUT
          case. 53 do. 
            if. keyp 0 do. tilde=.rkey'' end. 
            tui_handle_key 21
          case. 54 do. 
            if. keyp 0 do. tilde=.rkey'' end. 
            tui_handle_key 4
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
    update_ac_ui ''
    return.
  end.
)

NB. ============================================================
NB. Main loop
tui_run =: monad define
  NB. gethw never throws (ioctl -> stty -> 24 80; see vendor/vt.ijs)
  hw =. gethw''
  if. (2 ~: (# hw)) +. (0 e. hw) do. hw =. 24 80 end.
  TUI_LINES =: 0{ hw
  TUI_COLS =: 1{ hw
  raw 1
  puts CSI,'?2004h'          NB. bracketed paste, so a drop arrives whole
  curs 0
  cscr''
  reset''
  puts ESC,']0;J-PI',7{a.   NB. set static terminal title (OSC 0)
  NB. no mouse capture — allows normal text selection
  NB. use Ctrl-U/Ctrl-D or PageUp/PageDown to scroll

  hist_load ''
  echo =: tui_echo
  if. MOUSE_ON do. 
    puts CSI,'?1000h'
    puts CSI,'?1006h'
  end.
  
  'prompt' tui_print 'J-PI Agent (TUI2 – pure vt)'
  'muted'  tui_print 'Type a question, !cmd, /cmd, Ctrl+C exit. Ctrl+W toggles mouse wheel scrolling (off = select text).'
  'muted'  tui_print '/less [N] opens output in less (scroll, search, copy). /nvim composes a prompt in nvim.'
  tui_print ''

  tui_redraw''

  NB. --resume asks which session to open. --continue already
  NB. selected one in init_session.
  if. (0 = 4!:0 <'JPI_RESUME_PICK') *. JPI_RESUME_PICK do.
    list_sessions ''
    tui_redraw ''
  end.

  while. TUI_RUNNING do.
    k =. rkey''
    try. tui_handle_key k catch.
      try. 'error' tui_print 'Error: ' , 13!:12 '' catch. end.
      try. tui_redraw'' catch. end.
    end.
  end.

  hist_save ''
  puts CSI,'?2004l'
  if. MOUSE_ON do. puts CSI,'?1000l' [ puts CSI,'?1006l' end.
  curs 1
  reset''
  raw 0
  puts CR,LF
  NB. Auto-save the conversation, after terminal restore so the
  NB. save message prints normally. Without this, HISTORY only hit
  NB. disk on /export or /session switch - interactive sessions
  NB. were lost on every exit (the format is JSONL; see session.ijs).
  if. 0 < # HISTORY do. save_session '' end.
  2!:55 (0)          NB. exit jconsole cleanly
)

echo 'tui2 loaded (pure vt escape codes).'