NB. String and array utilities
NB. utils.ijs

NB. J-CORE manual path (oracle-pinned grammar reference, optional).
NB. Set the JPI_JCORE environment variable to its location. Unset
NB. means no manual, and manual-dependent features degrade cleanly:
NB. the system prompt omits the reference sentence and the j-tool
NB. escalation ladder skips its full-section rung. The launcher
NB. sources local/env.sh (untracked) to export machine-local values.
NB. JCORE_PATH =: env JPI_JCORE, or '' when unset
resolve_jcore =: monad define
  p =. > 2!:5 'JPI_JCORE'
  if. (2 = 3!:0 p) *. 0 < # p do. p else. '' end.
)
JCORE_PATH =: resolve_jcore ''

NB. ================================================================
NB. Project-local trust gate (used by plugins.ijs and extensions.ijs)
NB.
NB. A project directory can carry executable jpi code: plugin
NB. packages (mcp.json entries SPAWN SERVER PROCESSES; skills alter
NB. agent behavior) and raw .ijs extensions (EXECUTED at startup).
NB. Auto-loading those from an untrusted directory runs someone
NB. else's code on your machine with no prompt.
NB.
NB. Gate semantics: the first time jpi meets a directory whose
NB. project walk (cwd up to, but not including, $HOME or .git)
NB. contains plugins, skills, prompts, or AGENTS.md, it asks once
NB. at the controlling terminal. 'y' is recorded in ~/.jpi/trusted
NB. (one absolute path per line). Any other answer is recorded in
NB. ~/.jpi/declined and is not asked again. $HOME itself does not
NB. count: ~/.jpi is user configuration and is loaded without this
NB. gate. Headless runs never prompt. jpi's own shipped plugins
NB. dirs are never gated.

require 'files'

TRUSTED_FILE =: ''
DECLINED_FILE =: ''
BUILTIN_PLUGIN_DIRS =: 0 $ <''
3 : 0 ''
  h =. > 2!:5 'HOME'
  if. 2 = 3!:0 h do.
    TRUSTED_FILE =: h , '/.jpi/trusted'
    DECLINED_FILE =: h , '/.jpi/declined'
    if. -. fexist h , '/.jpi' do.
      try. 1!:5 < h , '/.jpi' catch. end.
    end.
  end.
  js =. > 2!:5 'JPI_SRC'
  if. 2 = 3!:0 js do.
    NB. jpi's own plugin locations: $JPI_SRC/plugins and the
    NB. repo root's plugins/ (what the cwd-relative discovery finds
    NB. when launched from the repo root or from src/)
    pare =. (js i: '/') {. js
    BUILTIN_PLUGIN_DIRS =: (< js , '/plugins') , < pare , '/plugins'
  end.
)

NB. absolute path of a cwd-relative plugins directory
NB. y = './plugins' or '../plugins' (falls through unchanged)
abs_plugins =: monad define
  cwd =. 1!:43 ''
  if. 0 = # cwd do. '' return. end.
  if. './' -: 2 {. y do. cwd , '/plugins'
  elseif. '../' -: 3 {. y do. ((cwd i: '/') {. cwd) , '/plugins'
  elseif. do. y
  end.
)

NB. is the plugins dir jpi's own (shipped)? never gated
NB. BOX the path before e.: a bare literal vector would test
NB. membership per CHARACTER, not per string.
is_builtin_plugins =: monad define
  p =. abs_plugins y
  if. 0 = # p do. 1 return. end.
  (< p) e. BUILTIN_PLUGIN_DIRS
)

NB. Paths refused this process. A "no" is not written to disk, and
NB. without this list every later loader would ask again.
TRUST_NO =: 0 $ <''

NB. fread lines are flagged literals. e. and -: compare storage,
NB. so a path saved last launch would miss and the prompt would
NB. repeat. Equal length and atom-wise = compares the characters.
trust_line =: dyad define
  q =. , x
  t =. , y
  if. (0 = # q) +. (# q) ~: # t do. 0 return. end.
  hit =. 0
  try. hit =. *./ q = t catch. hit =. 0 end.
  hit
)

NB. x = absolute path, y = file of one path per line.
trust_file_has =: dyad define
  if. (0 = # y) +. -. fexist y do. 0 return. end.
  txt =. fread y
  if. (2 ~: 3!:0 txt) +. 0 = # txt do. 0 return. end.
  if. LF ~: {: txt do. txt =. txt , LF end.
  hit =. 0
  for_l. deb&.> <;._2 txt do.
    if. x trust_line > l do. hit =. 1 end.
  end.
  hit
)

NB. already answered 'y' before?
is_trusted =: monad define
  y trust_file_has TRUSTED_FILE
)

NB. already answered anything but 'y'?
is_declined =: monad define
  y trust_file_has DECLINED_FILE
)

NB. $HOME is the user config directory, not a project root.
NB. jpi creates ~/.jpi, so counting it made every folder look new.
trust_is_home =: monad define
  h =. ''
  try. h =. > 2!:5 'HOME' catch. h =. '' end.
  if. 2 ~: 3!:0 h do. 0 return. end.
  h trust_line y
)

NB. 1 when cwd, or a parent below $HOME and not past .git, has
NB. project files. Does not prompt.
project_trust_needed =: monad define
  d =. 1!:43 ''
  need =. 0
  for_i. i. 8 do.
    if. trust_is_home d do. break. end.
    if. (fexist d , '/plugins') +. (fexist d , '/skills') +. (fexist d , '/.agents') +. (fexist d , '/prompts') +. (fexist d , '/.jpi') +. (fexist d , '/AGENTS.md') +. (fexist d , '/JPILOT.md') +. (fexist d , '/CLAUDE.md') do.
      need =. 1
    end.
    if. fexist d , '/.git' do. break. end.
    parent =. (d i: '/') {. d
    if. (0 = # parent) +. parent -: d do. break. end.
    d =. parent
  end.
  need
)

NB. 1 while scripts are loading from JPI_SRC and the user
NB. launched somewhere else. That directory is the program, not
NB. the project. finish_project_scan runs after the cwd returns.
defer_project_scan =: monad define
  if. 0 ~: 4!:0 <'LAUNCH_CWD' do. 0 return. end.
  js =. ''
  try. js =. > 2!:5 'JPI_SRC' catch. js =. '' end.
  if. (2 ~: 3!:0 js) +. 0 = # js do. 0 return. end.
  if. -. (1!:43 '') -: js do. 0 return. end.
  if. LAUNCH_CWD -: js do. 0 return. end.
  1
)

NB. Plugins, skills, and prompts that were skipped while cwd
NB. was JPI_SRC. Safe to call when nothing was deferred.
finish_project_scan =: monad define
  if. 0 ~: 4!:0 <'PROJECT_SCAN_PENDING' do. '' return. end.
  if. -. PROJECT_SCAN_PENDING do. '' return. end.
  if. 3 = 4!:0 <'discover_all_plugins' do. discover_all_plugins '' end.
  if. 3 = 4!:0 <'discover_all_skills' do. discover_all_skills '' end.
  if. 3 = 4!:0 <'discover_prompts' do. discover_prompts '' end.
  PROJECT_SCAN_PENDING =: 0
  ''
)

NB. the gate: 1 = load allowed, 0 = skip. Prompts once at the
NB. controlling terminal; headless (read fails, empty answer)
NB. skips. The answer travels via a temp FILE, not captured
NB. stdout: in a pty, 2!:0's capture can nondeterministically
NB. include echo/escape bytes, and a loose match on those could
NB. auto-trust. Strict equality against the file's content.
trust_gate =: monad define
  if. is_trusted y do. 1 return. end.
  if. is_declined y do. 0 return. end.
  if. (< y) e. TRUST_NO do. 0 return. end.
  if. 0 = # TRUSTED_FILE do. 0 return. end.
  ansfile =. '/tmp/jpi_trust_ans_' , 6!:0 'hhmmss'
  cmd =. 'printf "%s" "jpi: first time in ' , y , ': load its project files (plugins, skills, prompts, AGENTS.md)? [y/N] " >/dev/tty 2>/dev/null; read -r ans </dev/tty 2>/dev/null; printf "%s" "$ans" >' , ansfile , ' 2>/dev/null'
  2!:0 cmd
  ans =. ''
  if. fexist ansfile do.
    ans =. fread ansfile
    ferase ansfile
    if. 2 ~: 3!:0 ans do. ans =. '' end.
  end.
  NB. atom-wise compare, NEVER -: on fread output: this J build's
  NB. fread returns a mapped/utf8-flagged literal whose INTERNAL
  NB. representation differs from a plain literal, and -: compares
  NB. storage, not value ('y' -: fread-of-y is 0; 'y' = is 1).
  ans =. deb tolower , ans
  if. (0 < # ans) *. 'y' = {. ans do.
    (y , LF) fappend TRUSTED_FILE
    1
  else.
    TRUST_NO =: TRUST_NO , < y
    if. 0 < # DECLINED_FILE do. (y , LF) fappend DECLINED_FILE end.
    echo 'TRUST: skipping project files in ' , y , ' (saved in ' , DECLINED_FILE , ')'
    0
  end.
)

NB. 1 when project skills, prompts, context files, and plugins may
NB. load. User-global files are not gated. A project with none of
NB. these does not prompt.
project_trusted =: monad define
  NB. Do not ask about the harness tree during script load.
  if. defer_project_scan '' do. 0 return. end.
  cwd =. 1!:43 ''
  if. is_trusted cwd do. 1 return. end.
  if. is_declined cwd do. 0 return. end.
  if. (< cwd) e. TRUST_NO do. 0 return. end.
  if. -. project_trust_needed '' do. 1 return. end.
  trust_gate cwd
)

NB. numeric JSON field: y = a gethash_json result. Returns the
NB. number, or _1 when the field is missing, JSON null (dec_json
NB. renders null as the literal 'json_null' - a type-2 string
NB. that slips through type checks and even evaluates as a name
NB. under ".), or non-numeric.
json_num =: monad define
  if. _1 -: y do. _1 return. end.
  v =. > y
  if. 2 = 3!:0 v do.
    if. 'json_null' -: , v do. _1 return. end.
    (". :: _1:) , v return.
  end.
  if. 0 < # , v do. v else. _1 end.
)

NB. y = the pricing cell from a model listing. hyai sends an
NB. object with input_per_million. xAI image models send an
NB. array. gethash_json asserts a rank-2 table, so an array
NB. must not be passed to it. '' when there is no hyai price.
model_price_label =: monad define
  if. _1 -: y do. '' return. end.
  pr =. y
  if. 0 = $$ pr do. pr =. > pr end.
  if. (32 ~: 3!:0 pr) +. 2 ~: $$ pr do. '' return. end.
  pi =. json_num 'input_per_million' gethash_json pr
  po =. json_num 'output_per_million' gethash_json pr
  if. 0 < pi do.
    price =. '  ' , (": pi) , 'EUR/M in'
    if. 0 < po do. price =. price , ' ' , (": po) , 'EUR/M out' end.
    price
  else.
    ''
  end.
)

NB. human_size: format a byte count as a human-readable string
NB. y = numeric byte count
NB. Returns string like '1.5 KB', '3.2 MB', '512 B'
human_size =: monad define
  if. y < 1024 do.
    (": y) , ' B'
  else.
    units =. 'KB';'MB';'GB';'TB'
    val =. y % 1024
    ui =. 0
    while. (val >: 1024) *. (ui < 3) do.
      val =. val % 1024
      ui =. ui + 1
    end.
    NB. Format with 1 decimal place, strip trailing '.0'
    r =. <. 0.5 + 10 * val
    s =. ": <. r % 10
    if. 0 < 10 | r do.
      s =. s , '.' , ": 10 | r
    end.
    s , ' ' , > ui { units
  end.
)

NB. truncate_mid: truncate a string in the middle, inserting '...'
NB. y = string ; max_width  (boxed pair)
NB. If #string <= max_width, returns string unchanged.
NB. Otherwise keeps head and tail with '...' in the middle.
truncate_mid =: monad define
  's w' =. y
  if. w < 4 do. w {. s return. end.
  if. (#s) <: w do. s return. end.
  keep =. w - 3
  half =. <. keep % 2
  head =. half {. s
  tail_n =. keep - half
  tail =. (- tail_n) {. s
  head , '...' , tail
)

NB. truncate_right: truncate a string on the right, appending '...'
NB. y = string ; max_width  (boxed pair)
NB. If #string <= max_width, returns string unchanged.
truncate_right =: monad define
  's w' =. y
  if. w < 4 do. w {. s return. end.
  if. (#s) <: w do. s return. end.
  ((w - 3) {. s) , '...'
)

NB. pad_right: pad a string on the right to a given width
NB. y = string ; width  (boxed pair)
NB. If string is already >= width, returns it unchanged.
pad_right =: monad define
  's w' =. y
  if. (#s) >: w do. s return. end.
  s , (w - #s) # ' '
)

NB. count_lines: count the number of lines in a string
NB. A trailing newline does not produce an extra empty line.
NB. Empty string has 0 lines.
count_lines =: monad define
  if. 0 = #y do. 0 return. end.
  NB. Count LFs; if string doesn't end with LF, add 1 for the last line
  n =. +/ LF = y
  if. LF ~: {: y do. n =. n + 1 end.
  n
)

NB. split_lines: split a string into a boxed list of lines (no trailing LFs)
NB. 'a',LF,'b',LF  ->  'a';'b'
NB. 'a',LF,'b'     ->  'a';'b'
NB. ''             ->  (empty boxed list)
split_lines =: monad define
  if. 0 = #y do. 0 $ <'' return. end.
  NB. Ensure string ends with LF for clean splitting
  if. LF ~: {: y do. y =. y , LF end.
  <;._2 y
)

NB. ----------------------------------------------------------------
NB. ANSI / UTF-8-aware display measurement and wrapping.
NB.
NB. TUI output lines contain ANSI SGR color sequences (from md.ijs
NB. or line styles) and multi-byte UTF-8 (box-drawing, arrows).
NB. Wrapping must count only visible columns and must never split
NB. an escape sequence or a codepoint, or the display corrupts
NB. (color bleed, mojibake).

NB. strip_ansi: remove ANSI SGR escape sequences (ESC [ params m)
strip_ansi =: monad define
  ESC_char =. 27 { a.
  out =. ''
  i =. 0
  n =. #y
  while. i < n do.
    c =. i { y
    if. c = ESC_char do.
      i =. i + 1
      if. (i < n) *. ('[' = i { y) do.
        i =. i + 1
        while. (i < n) *. (i { y) e. '0123456789;' do.
          i =. i + 1
        end.
        if. (i < n) *. ('m' = i { y) do. i =. i + 1 end.
      end.
    else.
      out =. out , c
      i =. i + 1
    end.
  end.
  out
)

NB. vis_len: visible length of a line in display columns.
NB. ANSI escapes have zero width; each UTF-8 codepoint counts as
NB. one column (wide CJK/emoji render wider — minor drift, never
NB. corrupts the terminal).
vis_len =: monad define
  t =. strip_ansi y
  NB. 0x80-0xBF are UTF-8 continuation bytes: count bytes minus those
  (# t) - +/ t e. (128 + i. 64) { a.
)

NB. wrap_utf8: wrap a line to x visible columns.
NB. ANSI SGR sequences take zero width and are never split; UTF-8
NB. codepoints are never split. Joining all rows reproduces the
NB. input exactly (monadic ; over the result). Empty input -> one
NB. empty row.
wrap_utf8 =: dyad define
  if. x < 1 do. ,< y return. end.
  if. 0 = #y do. ,< '' return. end.
  NB. fast path: pure ASCII without escapes — chunk on bytes
  ints =. a. i. y
  if. (-. 27 e. ints) *. *./ ints < 128 do.
    r =. 0 $ <''
    while. x < #y do.
      r =. r , < x {. y
      y =. x }. y
    end.
    r , < y return.
  end.
  NB. general path: segment into units (one codepoint or one escape
  NB. sequence), then greedily fill rows to x visible columns
  ESC_char =. 27 { a.
  conts =. (128 + i. 64) { a.
  r =. 0 $ <''
  cur =. ''
  cw =. 0
  i =. 0
  n =. #y
  while. i < n do.
    c =. i { y
    if. c = ESC_char do.
      NB. consume one escape sequence (zero width)
      j =. i + 1
      if. (j < n) *. ('[' = j { y) do.
        j =. j + 1
        while. (j < n) *. (j { y) e. '0123456789;' do. j =. j + 1 end.
        if. (j < n) *. ('m' = j { y) do. j =. j + 1 end.
      end.
      u =. (j - i) {. (i }. y)
      uw =. 0
    else.
      NB. consume one UTF-8 codepoint, sized by its lead byte
      NB. (stray continuation bytes are treated as one-byte units)
      ci =. a. i. c
      if. ci < 192 do. k =. 1
      elseif. ci < 224 do. k =. 2
      elseif. ci < 240 do. k =. 3
      else. k =. 4 end.
      u =. k {. (i }. y)
      uw =. 1
    end.
    if. (cw + uw) > x do.
      r =. r , < cur
      cur =. u
      cw =. uw
    else.
      cur =. cur , u
      cw =. cw + uw
    end.
    i =. i + #u
  end.
  r =. r , < cur
)

NB. take_utf8: keep the first x VISIBLE columns of y (prefix of
NB. display cells). ANSI escapes pass through free (zero width);
NB. a UTF-8 codepoint is never split. Companion of wrap_utf8.
NB. This is what chrome lines must use before writing them: a
NB. footer longer than the screen width makes the terminal
NB. auto-scroll (see tui_draw_bottom footer 2).
take_utf8 =: dyad define
  if. (x >: vis_len y) do. y return. end.
  NB. only when truncation is needed do the unit walk
  ESC_char =. 27 { a.
  conts =. (128 + i. 64) { a.
  cur =. ''
  cw =. 0
  i =. 0
  n =. #y
  while. i < n do.
    c =. i { y
    if. c = ESC_char do.
      j =. i + 1
      if. (j < n) *. ('[' = j { y) do.
        j =. j + 1
        while. (j < n) *. (j { y) e. '0123456789;' do. j =. j + 1 end.
        if. (j < n) *. ('m' = j { y) do. j =. j + 1 end.
      end.
      u =. (j - i) {. (i }. y)
      uw =. 0
    else.
      ci =. a. i. c
      if. ci < 192 do. k =. 1
      elseif. ci < 224 do. k =. 2
      elseif. ci < 240 do. k =. 3
      else. k =. 4 end.
      u =. k {. (i }. y)
      uw =. 1
    end.
    if. (cw + uw) > x do. cur break. end.
    cur =. cur , u
    cw =. cw + uw
    i =. i + #u
  end.
  cur
)

NB. squote: wrap in single quotes for the shell.
NB. ' inside the text becomes '\'' (close, escaped quote, reopen).
SQ =: ''''
BS =: '\'
squote_repl =: SQ , BS , SQ , SQ
squote =: monad define
  escaped =. y rplc SQ ; squote_repl
  SQ , escaped , SQ
)

NB. Quote each whitespace-separated word as its own shell argument.
NB. Metacharacters stay inside the quotes, so a slash-command tail
NB. cannot close the command and run another one.
quote_words =: monad define
  s =. deb y
  if. 0 = # s do. '' return. end.
  words =. <;._1 ' ' , s
  r =. ''
  for_w. words do.
    r =. r , (squote > w) , ' '
  end.
  }: r
)

echo 'utils loaded.'
