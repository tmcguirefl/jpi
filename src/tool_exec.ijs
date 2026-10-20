NB. Tool executor - handles LLM tool-call responses
NB. tool_exec.ijs

load 'safety.ijs'
load 'confirm.ijs'

NB. Tool name lookup. Order matches the gerund in exec_tool.
TOOLS =: 'read';'bash';'edit';'write';'j';'grep';'find';'ls'

NB. Check if a result is an error string (starts with 'ERROR:')
NB. Explicit original:
NB.   is_error =: monad define
NB.     (2 = 3!:0 y) *. 'ERROR:' -: 6 {. y
NB. )
is_error =: (2&= @ (3!:0)) *. ('ERROR:'&-: @ (6&{.))

NB. Extract a required field from parsed JSON.
NB. x = field name, y = parsed JSON object
NB. Returns: boxed value if found, or error string if missing.
require_field =: dyad define
  v =. x gethash_json y
  if. _1 -: v do.
    'ERROR: missing required parameter "' , x , '"'
  else.
    v
  end.
)

NB. Execute a single tool call
NB. y = tool_name ; input_object (parsed JSON, boxed)
exec_tool =: monad define
  'name input' =. y
  log 'tool_exec: ' , name
  NB. Ravel both sides: single-char names like 'j' are scalars in J
  NB. (rank 0), but gethash_json returns vectors (rank 1). -: checks
  NB. rank, so we ravel to normalize both sides to vectors.
  idx =. (, each TOOLS) i. < , name
  if. idx < #TOOLS do.
    NB. built-in tool
    (exec_read`exec_bash`exec_edit`exec_write`exec_j`exec_grep`exec_find`exec_ls) @. idx input
  else.
    NB. try extension tools first, then MCP tools
    if. is_ext_tool name do.
      ext_exec_tool name ; < input
    elseif. 0 < # MCP_TOOLS do.
      NB. Convert input (boxed JSON) to JSON string for MCP call
      args_json =. enc_json_fixed input
      mcp_exec_tool name ; args_json
    elseif. do.
      'ERROR: unknown tool: ' , name
    end.
  end.
)

NB. Optional string field. '' when missing, null, or not text.
field_text =: dyad define
  v =. x gethash_json y
  if. _1 -: v do. '' return. end.
  v =. > v
  if. 2 ~: 3!:0 v do. '' return. end.
  if. 'json_null' -: v do. '' return. end.
  v
)

NB. Image reads travel as text plus a marker. The payload
NB. builder turns that marker into an image block. A large
NB. file stays a text note so the request does not carry it.
image_tool_text =: monad define
  path =. y
  mime =. 'application/octet-stream'
  if. 3 = 4!:0 <'image_mime' do. mime =. image_mime path end.
  b64 =. ''
  if. 3 = 4!:0 <'file_to_base64' do. b64 =. file_to_base64 path end.
  note =. 'Image file: ' , path
  if. 3 = 4!:0 <'image_info' do.
    info =. image_info path
    if. 0 < # info do. note =. note , LF , info end.
  end.
  if. (0 = # b64) +. 120000 < # b64 do.
    note , LF , '(image is not inlined)'
  else.
    note , LF , '[[jpi-image ' , mime , ']]' , LF , b64
  end.
)

exec_read =: monad define
  pv =. 'path' require_field y
  if. is_error pv do. pv return. end.
  path =. > pv
  if. 3 = 4!:0 <'is_image' do.
    if. is_image path do. image_tool_text path return. end.
  end.
  NB. optional offset and limit parameters
  offset =. 'offset' gethash_json y
  limit =. 'limit' gethash_json y
  if. _1 -: offset do. offset =. 1 end.
  if. _1 -: limit do. limit =. 2000 end.
  offset =. > offset
  limit =. > limit
  read_file_auto path ; offset ; limit
)

NB. grep exits 1 when nothing matches. || true keeps 2!:0 from
NB. turning that into a domain error.
exec_grep =: monad define
  pv =. 'pattern' require_field y
  if. is_error pv do. pv return. end.
  pat =. > pv
  path =. 'path' field_text y
  if. 0 = # path do. path =. '.' end.
  if. -. (is_safe pat) *. is_safe path do.
    'ERROR: pattern or path blocked for safety.' return.
  end.
  run_cmd_str 'grep -n -- ' , (squote pat) , ' ' , (squote path) , ' || true'
)

exec_find =: monad define
  path =. 'path' field_text y
  if. 0 = # path do. path =. '.' end.
  name =. 'name' field_text y
  if. -. (is_safe path) *. is_safe name do.
    'ERROR: path or name blocked for safety.' return.
  end.
  cmd =. 'find ' , squote path
  if. 0 < # name do. cmd =. cmd , ' -name ' , squote name end.
  run_cmd_str cmd , ' || true'
)

exec_ls =: monad define
  path =. 'path' field_text y
  if. 0 = # path do. path =. '.' end.
  if. -. is_safe path do.
    'ERROR: path blocked for safety.' return.
  end.
  run_cmd_str 'ls -la ' , (squote path) , ' || true'
)

NB. ================================================================
NB. Dangerous-command gate: a VISIBLE ask, never a silent block.
NB. safety.ijs's BLOCKED patterns trigger a prompt showing the
NB. command and the tripped pattern; y runs it ONCE, anything
NB. else denies. Headless modes (print/rpc/bench: no TUI keyp)
NB. cannot ask and DENY with an explanation - never silently.
NB. The same patterns are checked against j-tool CODE strings
NB. (catches 2!:0 'rm -rf ...' style shell-outs) - heuristic
NB. visibility, not a sandbox: the j tool can still construct
NB. commands the pattern check cannot see.

NB. first BLOCKED pattern in y, '' if none
bash_danger =: monad define
  cmd =. norm_cmd y
  for_b. BLOCKED do.
    if. (> b) +./@E. cmd do. (> b) return. end.
  end.
  ''
)

NB. ask: x = command, y = matched pattern. 1 = run, 0 = deny.
NB. Raw-key read (keyp/rkey): confirm.ijs's 1!:1 ] 1 reads the
NB. script stream, not the terminal, mid-agent-loop.
danger_ask =: dyad define
  if. 3 ~: 4!:0 <'keyp' do. 0 return. end.   NB. headless: deny
  if. 3 = 4!:0 <'tui_print' do.
    'error' tui_print 'DANGEROUS COMMAND (matches: ' , y , ')'
    'prompt' tui_print '$ ' , x
    'prompt' tui_print 'run it? y = once, anything else = deny'
    tui_redraw ''
  end.
  while. 1 do.
    if. keyp 100 do.
      k =. rkey ''
      if. (k = 'y'{a.) +. (k = 'Y'{a.) do. 1 return. end.
      0 return.                  NB. anything else, incl. Enter: deny
    end.
  end.
)

NB. gate: y = command string. '' = allowed; else ERROR text.
danger_gate =: monad define
  pat =. bash_danger y
  if. 0 = # pat do. '' return. end.
  ok =. y danger_ask pat
  if. 3 = 4!:0 <'tui_print' do.
    if. ok do.
      'muted' tui_print '(approved: ' , pat , ')'
    else.
      'muted' tui_print '(denied: ' , pat , ')'
    end.
    tui_redraw ''
  end.
  if. ok do. '' return. end.
  'ERROR: command rejected by user (dangerous pattern: ' , pat , ')'
)

exec_bash =: monad define
  cv =. 'command' require_field y
  if. is_error cv do. cv return. end.
  cmd =. > cv
  NB. visible dangerous-pattern gate (see danger_gate)
  gate =. danger_gate cmd
  if. 0 < # gate do. gate return. end.
  NB. optional timeout parameter
  timeout =. 'timeout' gethash_json y
  if. _1 -: timeout do. timeout =. DEFAULT_TIMEOUT end.
  timeout =. > timeout
  run_cmd_str cmd ; timeout
)

exec_edit =: monad define
  pathv =. 'path' require_field y
  if. is_error pathv do. pathv return. end.
  oldv =. 'old_text' require_field y
  if. is_error oldv do. oldv return. end.
  newv =. 'new_text' require_field y
  if. is_error newv do. newv return. end.
  path =. > pathv
  if. -. confirm_edit path do.
    'Cancelled by user.' return.
  end.
  old =. > oldv
  new =. > newv
  if. edit_file path ; old ; new do.
    'Edit successful.'
  else.
    'ERROR: edit failed (text not found or not unique).'
  end.
)

NB. load-check a written .ijs in the jpiagws workspace and feed
NB. failures into the SHARED escalation ladder (signature bump,
NB. identical-content detection, rungs 1-7) - write-tool
NB. spirals were invisible to the ladder because writing always
NB. "succeeds". Deliberately-broken files: an 'NB. intentional'
NB. marker line skips the counter (the check still reports).
NB. Clean loads REGISTER the definitions in the session - the
NB. model can call them immediately after writing.
write_verify =: dyad define
  path =. x
  content =. y
  ('base';'z') copath 'jpiagws'
  cocurrent 'jpiagws'
  err =. ''
  try.
    0!:0 < path
  catch.
    err =. 13!:12 ''
  end.
  cocurrent 'base'
  if. 0 = # err do.
    'Load check: clean - the definitions are now available in the session.'
    return.
  end.
  NB. deliberate broken file: informative line, never counted
  if. +./ 'nb. intentional' E. tolower , 300 {. content do.
    'Load check (intentional, not counted): ' , err
    return.
  end.
  NB. packaging hint for the observed garble family
  pk =. ''
  if. +./ 'verb define' E. tolower content do.
    pk =. ' PACKAGING: J has no "verb define" - an explicit definition is 3 : 0 ... ) with the body on separate lines.'
  end.
  jfail_text err ; ('load check, file: ' , path) ; ((jerr_hint err) , pk) ; content
)

exec_write =: monad define
  pathv =. 'path' require_field y
  if. is_error pathv do. pathv return. end.
  contentv =. 'content' require_field y
  if. is_error contentv do. contentv return. end.
  path =. > pathv
  if. -. confirm_write path do.
    'Cancelled by user.' return.
  end.
  content =. > contentv
  if. write_file path ; content do.
    r =. 'Write successful.'
    NB. write-verify on-ramp: .ijs files load in the session
    NB. workspace; load failures enter the same ladder as j-tool
    NB. failures (cnt, hints, rungs 6-7). Non-.ijs writes are
    NB. untouched. Intent marker: see write_verify.
    if. '.ijs' -: _4 {. path do.
      r =. r , LF , (path write_verify content)
    end.
    r
  else.
    'ERROR: write failed.'
  end.
)

NB. Private-name hint: exec_j is itself a 3 : definition, so x and
NB. y are ITS private arguments - public assignment (=: ) to a
NB. name with a private value is a domain error (observed: an
NB. agent named its scratch variable y). u and v are only operands
NB. inside 1 :/2 : bodies. y = the failing source line.
NB. --- thrash guards -------------------------------------------------
NB. Escalating help for repeated failures. Bench-observed thrash:
NB. models resubmit the same broken form and recompose whole
NB. phrases from memory (t03: six runs of quote-garble; t15:
NB. 220k-token spirals). Escalation ladder per error SIGNATURE:
NB.   1st:  the section pointer (jx_hint / jerr_hint, as before)
NB.   2nd:  the FULL section text delivered from the manual
NB.   3rd+: a search instruction (grep the manual) plus the
NB.         decomposition advice
NB. Plus identical-submission detection: byte-identical code that
NB. failed before gets an explicit do-not-resubmit note.
NB. State lives in BASE with qualified names: exec_j_ws executes
NB. in the jpiagws workspace, so an unqualified assignment would
NB. land in jpiagws where agent code could clobber the counters.
NB. JCORE_PATH is defined in utils.ijs (env JPI_JCORE); empty means
NB. no manual - the rungs below degrade to the pointer/search only.
JERR_SIGS =: 0 $ <''         NB. signatures seen (parallel lists -
JERR_CNTS =: 0 $ 0           NB. counts; boxed-table column
                             NB. extraction proved unreliable)
JFAIL_SUBS =: 0 $ <''        NB. recent failing code strings

NB. canonical key for an error text
jerr_key =: monad define
  e =. tolower y
  keys =. 'unexecutable fragment';'must be a verb';'valence error';'value error: y';'value error';'index error';'domain error';'length error';'rank error';'spelling error';'open quote';'syntax error'
  for_k. keys do.
    if. +./ (> k) E. e do. > k return. end.
  end.
  40 {. 1 { <;._2 e
)

NB. bump the count for a signature; returns the NEW count
jerr_bump =: monad define
  idx =. JERR_SIGS_base_ i. < y
  if. idx = # JERR_SIGS_base_ do.
    JERR_SIGS_base_ =: JERR_SIGS_base_ , < y
    JERR_CNTS_base_ =: JERR_CNTS_base_ , 1
    1
  else.
    c =. idx { JERR_CNTS_base_
    JERR_CNTS_base_ =: (c + 1) idx } JERR_CNTS_base_
    c + 1
  end.
)

NB. record a failing code string; returns 1 if it had failed before
jfail_add =: monad define
  prior =. (< y) e. JFAIL_SUBS_base_
  JFAIL_SUBS_base_ =: _10 {. JFAIL_SUBS_base_ , < y
  prior
)

NB. section number from a hint text ('J-CORE 3: ...' -> '3')
jcore_num =: monad define
  m =. 'J-CORE ' E. y
  if. -. +./ m do. '' return. end.
  s =. (m i. 1) + # 'J-CORE '
  rest =. s }. y
  d =. (rest e. '0123456789') i. 0
  d {. rest
)

NB. full text of manual section n, bounded
jcore_section =: monad define
  if. (0 = # y) +. 0 = # JCORE_PATH_base_ do. '' return. end.
  txt =. fread JCORE_PATH_base_
  hdr =. '## ' , y , '.'
  m =. hdr E. txt
  if. -. +./ m do. '' return. end.
  s =. m i. 1
  rest =. (s + # hdr) }. txt
  m2 =. (LF , '## ') E. rest
  if. +./ m2 do.
    len =. m2 i. 1
  else.
    len =. # rest
  end.
  1600 {. len {. rest
)

NB. y = err ; ln ; hint ; code -> the full escalating failure message
jfail_text =: monad define
  'err ln hint code' =. y
  sig =. jerr_key err
  cnt =. jerr_bump sig
  dup =. jfail_add code
  m =. 'ERROR: J execution failed: ' , err , LF , 'in line: ' , ln
  if. 0 < # hint do. m =. m , LF , 'J-CORE hint: ' , hint end.
  if. dup do.
    m =. m , LF , LF , 'NOTE: this exact code was already submitted and failed. Do not resubmit it unchanged - run the PIECES of your expression separately to find the broken one.'
  end.
  if. cnt > 1 do.
    sec =. jcore_section jcore_num hint
    if. 0 < # sec do.
      m =. m , LF , LF , 'FULL SECTION from the manual:' , LF , sec
    end.
  end.
  if. cnt > 2 do.
    m =. m , LF , LF , 'PERMISSION TO WRITE EXPLICITLY: replace the failing tacit form with a plain explicit definition: tNN =: 3 : 0 with your steps on separate lines, local nouns (n.) and y as the argument, closing with a lone ). An explicit definition is always safe - a working explicit answer beats a broken tacit one.'
  end.
  if. cnt > 3 do.
    srch =. 'run the PIECES of your expression separately to find the broken one.'
    if. 0 < # JCORE_PATH_base_ do.
      srch =. 'search the manual (' , JCORE_PATH_base_ , ') and ' , srch
    end.
    m =. m , LF , LF , 'This same error has now fired ' , (": cnt) , ' times. If the explicit form also fails: ' , srch
  end.
  NB. fifth rung: the J wiki and forum search tools - ONLY when
  NB. MCP tools are loaded (real jpi sessions have recoll/jmail;
  NB. the bench driver stubs them empty). The manual covers only
  NB. observed failure families; the wiki documents every
  NB. primitive authoritatively (e.g. its Vocabulary/Locales
  NB. page is where the locale rules live).
  if. cnt > 4 do.
    mcp =. 1
    if. _1 = 4!:0 <'MCP_TOOLS' do. mcp =. 0
    elseif. 0 = # MCP_TOOLS do. mcp =. 0
    end.
    if. mcp do.
      m =. m , LF , LF , 'The manual covers only observed failure families. Go beyond it: search the J wiki and the J forum archive with your available search tools (see the MCP tools in your system prompt) - the wiki Vocabulary pages document every primitive authoritatively.'
    end.
  end.
  NB. sixth rung (4th same-signature failure): thrash verdict; seventh
NB. rung (5th): escalated solver. Thresholds lowered from 6/7
NB. (healthy models converge by attempt 3; thrashers hit 25+).
  NB. THRASH appends the
  NB. explicit-retreat nudge; PROGRESS a keep-going line; an
  NB. unavailable engine (no key, network) adds NOTHING and the
  NB. run continues - the rung degrades silently by design.
  v =. ''
  if. (cnt > 3) *. 3 = 4!:0 <'jev_verdict' do.
    v =. jev_verdict 8
    if. 'THRASH' -: v do.
      m =. m , LF , LF , 'THRASH CHECK: ' , JEV_NUDGE
    elseif. 'PROGRESS' -: v do.
      m =. m , LF , LF , 'THRASH CHECK: the checker sees progress in your recent turns - continue, but change ONE thing about this attempt.'
    end.
  end.
  NB. seventh rung: escalated one-shot solver (jev.ijs) - on a
  NB. THRASH verdict, hand the stuck fragment to a stronger
  NB. model (LADDER_MODEL) and return its proposal for the MAIN
  NB. model to verify with the j tool before adopting. The
  NB. session model never switches; once per error signature;
  NB. unset LADDER_MODEL degrades silently.
  if. (cnt > 4) *. ('THRASH' -: v) *. 3 = 4!:0 <'jev_solve' do.
    if. (0 < # LADDER_MODEL) *. -. (< sig) e. JEV_SOLVED do.
      echo 'LADDER: escalated solver engaged (one-shot to ' , LADDER_MODEL , ')'
      proposal =. jev_solve jev_evidence 8
      if. 0 < # proposal do.
        JEV_SOLVED =: JEV_SOLVED , < sig
        m =. m , LF , LF , 'ESCALATED SOLVER PROPOSAL (verify with your j tool before adopting):' , LF , proposal
      end.
    end.
  end.
  m
)

jx_hint =: monad define
  fw =. (y i. ' ') {. y
  if. (<fw) e. ;: 'x y' do.
    'J-CORE 1: x and y are the private arguments of the definition your code runs inside (the j tool itself is a 3 : definition) - public assignment to a private name is a domain error. Rename your variable (n, m, w); u and v are fine here.'
  else.
    ''
  end.
)

NB. Error-signature hints (bench-observed failure families, 34 tasks,
NB. five models, J-CORE sections). exec_j appends the matching one-
NB. liner to a runtime error, pointing at the manual section that
NB. fixes it: the manual reaches the model at the exact moment of
NB. failure, making consultation deterministic instead of the
NB. coin-flip routing seen in one-shot bench runs.
NB. Order matters: specific signatures before generic ones.
jerr_hint =: monad define
  e =. tolower y
  has =. 4 : '+./ x E. y'
  if. 'unexecutable fragment' has e do.
    'J-CORE 3: a bare NOUN before a verb is a dyadic fragment. BOND the constant (0&~: or 2&|) or, if the phrase names y, wrap the whole phrase in 3 : ''...'''
  elseif. 'must be a verb' has e do.
    'J-CORE 5: conjunction operands are single words. Parenthesize compounds: +/ @: (2&|).'
  elseif. 'valence error' has e do.
    'J-CORE 1: 3 : for one argument, 4 : for two; 1 : defines an ADVERB and 2 : a CONJUNCTION, never a verb.'
  elseif. 'value error: y' has e do.
    'J-CORE 1: y exists only inside an explicit 3 : body. A tacit definition cannot mention y: wrap the phrase in 3 : ''...'' or delete the y.'
  elseif. 'value error' has e do.
    'Undefined name: define it first, or check the spelling (J-CORE 0: one dot or colon changes the primitive).'
  elseif. 'index error' has e do.
    'J-CORE 3: `{` takes the INDEX on the left (0 { 7 8 9); `i.` is the mirror with data on the left. An over-large index usually means reversed operands.'
  elseif. 'domain error' has e do.
    'J-CORE 7: boxes must be OPENED (>) before numeric verbs. Also: a delimiter is never the left argument of cut (J-CORE 15).'
  elseif. 'length error' has e do.
    'J-CORE 16: frames must agree. Per-row work is rank 1 (+/ "1); do not build a reshape to broadcast.'
  elseif. 'rank error' has e do.
    'J-CORE 16: +/ threads the FIRST axis (column sums); +/ "1 gives ROW sums. Check which you wrote.'
  elseif. 'open quote' has e do.
    'J-CORE 1: every '' must close; a quote inside a literal is DOUBLED (''''''''), and backslash escaping does not exist.'
  elseif. 'spelling error' has e do.
    'J-CORE 0: name the token from the glyph index before using it - one dot or colon changes the primitive.'
  elseif. 'syntax error' has e do.
    'J-CORE 1: count your quotes (every '' must close; backslash escaping does not exist). J-CORE 6: check noun-verb adjacency.'
  else.
    ''
  end.
)

NB. Agent-workspace isolation: evaluated code runs in the
NB. persistent locale 'jpiagws' instead of the base locale
NB. where the harness lives (HISTORY, MODEL, exec_j itself).
NB. Definitions persist across j calls, but assignments land in
NB. jpiagws ("public assignments are always made in the
NB. starting locale" - J wiki Vocabulary/Locales) - evaluated
NB. code can never clobber harness globals, even when it names
NB. them: the assignment shadows inside jpiagws only.
NB.
NB. LOCALE RULES this relies on (J wiki Vocabulary/Locales and
NB. the Studio Locales lab, oracle-verified):
NB. - copath is dyadic: PATH copath LOCALE sets the search
NB.   path (PATH copath LOCALE, per the Studio Locales lab). A fresh locale
NB.   path is just z - base names would NOT resolve - so the
NB.   wrapper sets jpiagws path to base, idempotently.
NB. - "A definition FROM the path does not set a new current
NB.   locale and executes as if it were in the current locale"
NB.   - exec_j_ws, found via the path, executes IN jpiagws, so
NB.   the agent code evaluated below stays in the workspace.
NB.   (Never call it as exec_j_ws_base_: a locative call
NB.   switches the implied locale to base, silently undoing
NB.   the isolation.)
NB. - the wrapper always restores base, including on errors.

exec_j =: monad define
  ('base';'z') copath 'jpiagws'
  cocurrent 'jpiagws'
  try.
    r =. exec_j_ws y
    cocurrent 'base'
    r
  catch.
    cocurrent 'base'
    'ERROR: J tool failure: ' , 13!:12 ''
  end.
)

exec_j_ws =: monad define
  cv =. 'code' require_field y
  if. is_error cv do. cv return. end.
  code =. > cv
  NB. visible dangerous-pattern gate on the raw code: catches
  NB. 2!:0 'rm -rf ...' style shell-outs (heuristic visibility,
  NB. not a sandbox - constructed commands can still slip past)
  gate =. danger_gate code
  if. 0 < # gate do. gate return. end.
  NB. Multi-line code: ". rejects LF (code unit 10) inside a
  NB. sentence. Split on LF and execute each non-empty line in
  NB. order - state persists across lines in this session.
  lfl =. code = LF
  if. +./ lfl do.
    NB. ;._2: each box ENDS at a marked position with the fol
    NB. dropped. Appending an LF first terminates the final line
    NB. (an unmarked tail would otherwise be dropped); the mask
    NB. must cover the extended string.
    code2 =. code , LF
    lines =. (code2 = LF) <;._2 code2
    lastout =. ''
    for_ln. lines do.
      NB. <;._2 boxes end at the fol (no trailing LF), strip anyway
      ln =. > ln
      ln =. ln -. LF
      ln =. dltb dlb ln
      if. 0 = #ln do. continue. end.
      try.
        NB. every J sentence yields a value (an assignment yields
        NB. the assigned value): the LAST line's value is the
        NB. multi-line result, like a script's final expression
        lastout =. ". ln
      catch.
        err =. 13!:12 ''
        hint =. jx_hint ln
        if. 0 = #hint do. hint =. jerr_hint err end.
        jfail_text err ; ln ; hint ; code
        return.
      end.
    end.
    NB. strings return raw; other nouns formatted; empty -> ok
    if. 2 131072 262144 e.~ 3!:0 lastout do. lastout return. end.
    if. 0 < # , lastout do. ": lastout return. end.
    'ok'
    return.
  end.
  try.
    out =. ". code
    type =. 3!:0 out
    if. type e. 2 131072 262144 do. out return. end.
    ": out
  catch.
    err =. 13!:12 ''
    hint =. jx_hint code
    if. 0 = #hint do. hint =. jerr_hint err end.
    jfail_text err ; code ; hint ; code
  end.
)

echo 'tool_exec loaded.'
