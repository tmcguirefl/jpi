NB. jev.ijs - decision-model thrash verdict (escalation rung 6)
NB. jev.ijs
NB.
NB. LADDER RUNG 6 of the j tool's escalation ladder (tool_exec
NB. jfail_text): after 5+ failures of the same error signature,
NB. the recent conversation turns are shown to a decision-model
NB. engine with a strict one-word verdict: PROGRESS or THRASH.
NB. THRASH appends the explicit-retreat nudge to the failing
NB. tool's error message; PROGRESS adds a keep-going line;
NB. unavailable adds nothing. The rung NEVER blocks the run.
NB.
NB. GRACEFUL DEGRADATION: any failure - no API key for the
NB. engine, network, parsing - returns '' and the ladder simply
NB. omits the verdict text. The feature is inert for anyone
NB. without a configured engine provider, and costs nothing on
NB. healthy runs (the ladder only reaches rung 6 after the
NB. signature counter has already seen repeated failure).
NB.
NB. ENGINE: JEV_MODEL, env-overridable. Default is a cheap fast
NB. model from the provider most users have configured; the
NB. optimized form is TypeSafe's decision model
NB. (typesafe/jev-1.14 via OpenRouter) - any model id works.

NB. JEV_MODEL =: env JEV_MODEL, else the default engine
JEV_MODEL =: 'mistral/mistral-small-latest'
3 : 0 ''
  v =. > 2!:5 'JEV_MODEL'
  if. (2 = 3!:0 v) *. 0 < # v do. JEV_MODEL =: v end.
)

JEV_CALLS =: 0      NB. verdict calls made (stats)
JEV_THRASH =: 0     NB. THRASH verdicts (stats)
JEV_LAST =: ''      NB. most recent verdict ('' = unavailable)

NB. the anti-thrash nudge (the explicit retreat that won one-shot)
JEV_NUDGE =: 'The thrash checker judges this repetition, not progress. Stop resubmitting similar attempts: either change strategy fundamentally, or write a plain explicit definition (3 : 0 ... ) with your steps on separate lines. An explicit definition is always safe - a working explicit answer beats a broken tacit one.'

NB. render the last N history messages as readable evidence:
NB. 'role: content' per line, content truncated to 400 chars.
NB. Tool-call turns without text content are marked.
NB. GUARDED: J's dec_json crashes on some echoed-J content
NB. (tokenizer index error); unparseable entries are skipped,
NB. never propagated - the verdict must never kill the ladder.
jev_evidence =: monad define
  ev =. ''
  for_m. (- y) {. HISTORY do.
    try.
      js =. dec_json > m
      role =. 'role' gethash_json js
      content =. 'content' gethash_json js
      if. (role -.@-: _1) *. (content -.@-: _1) do.
        c =. 400 {. > content
        ev =. ev , (> role) , ': ' , c , LF
      elseif. role -.@-: _1 do.
        ev =. ev , (> role) , ': (tool calls)' , LF
      end.
    catch.
      NB. skip the unparseable entry
    end.
  end.
  ev
)

NB. ask the engine for a verdict on the last y messages.
NB. Returns 'PROGRESS', 'THRASH', or '' (unavailable/unclear).
NB. The engine call switches MODEL/PROVIDER/API_URL/MAX_TOKENS
NB. to the engine and restores them after; plain http_post, no
NB. tools, no spinner, no usage tracking.
jev_verdict =: monad define
  ev =. jev_evidence y
  if. 0 = # ev do. '' return. end.
  sys =. 'You judge whether a coding agent is progressing. The evidence below shows its recent conversation turns. Reply with exactly one word: PROGRESS if the agent is making progress or shows no repetition, THRASH if it is repeating the same failing approach.'
  oMODEL =. MODEL [ oPROVIDER =. PROVIDER [ oURL =. API_URL [ oMAX =. MAX_TOKENS
  try.
    MODEL =: JEV_MODEL
    update_config_state ''
    msgs =. ; (,&',') each (('system' mk_msg sys) ; < 'user' mk_msg ev)
    payload =. '{"model":"' , (model_for_api MODEL) , '","messages":[' , (_1 }. msgs) , ']}'
    raw =. API_URL http_post payload
  catch.
    MODEL =: oMODEL [ PROVIDER =: oPROVIDER [ API_URL =: oURL [ MAX_TOKENS =: oMAX
    '' return.
  end.
  MODEL =: oMODEL [ PROVIDER =: oPROVIDER [ API_URL =: oURL [ MAX_TOKENS =: oMAX
  if. 'ERROR: ' -: 7 {. raw do. '' return. end.
  try.
    parsed =. dec_json raw
    if. has_error parsed do. '' return. end.
    v =. deb tolower get_or_content parsed
    JEV_CALLS =: JEV_CALLS + 1
    if. +./ 'thrash' E. v do.
      JEV_THRASH =: JEV_THRASH + 1
      JEV_LAST =: 'THRASH'
      'THRASH' return.
    end.
    if. +./ 'progress' E. v do.
      JEV_LAST =: 'PROGRESS'
      'PROGRESS' return.
    end.
    JEV_LAST =: ''
    ''
  catch.
    ''
  end.
)

NB. rung 7 config: the escalated solver model (one-shot; the
NB. session model NEVER switches). Unset -> rung degrades
NB. silently, like rung 6 without an engine key.
LADDER_MODEL =: ''
3 : 0 ''
  v =. > 2!:5 'LADDER_MODEL'
  if. (2 = 3!:0 v) *. 0 < # v do. LADDER_MODEL =: v end.
)
JEV_SOLVED =: 0 $ <''    NB. error signatures already solved for

NB. escalated one-shot solve: hand the stuck fragment to a
NB. stronger model (LADDER_MODEL) with the task evidence and the
NB. failed attempts. Returns the proposal text, or '' (unset
NB. model, call failure). The main model is told to VERIFY the
NB. proposal with the j tool before adopting it - the solver
NB. proposes, the interpreter verifies.
jev_solve =: monad define
  if. 0 = # LADDER_MODEL do. '' return. end.
  ev =. y
  if. 0 = # ev do. '' return. end.
  sys =. 'You are an expert J programmer. A coding agent has repeatedly failed at the task below. Write a WORKING solution. Prefer a plain explicit definition (3 : 0 ... ) with steps on separate lines - an explicit definition is always safe; only use tacit forms you are certain of. Reply with only the code, no explanation.'
  oMODEL =. MODEL [ oPROVIDER =. PROVIDER [ oURL =. API_URL [ oMAX =. MAX_TOKENS
  try.
    MODEL =: LADDER_MODEL
    update_config_state ''
    msgs =. ; (,&',') each (('system' mk_msg sys) ; < 'user' mk_msg ev)
    payload =. '{"model":"' , (model_for_api MODEL) , '","messages":[' , (_1 }. msgs) , ']}'
    raw =. API_URL http_post payload
  catch.
    MODEL =: oMODEL [ PROVIDER =: oPROVIDER [ API_URL =: oURL [ MAX_TOKENS =: oMAX
    '' return.
  end.
  MODEL =: oMODEL [ PROVIDER =: oPROVIDER [ API_URL =: oURL [ MAX_TOKENS =: oMAX
  if. 'ERROR: ' -: 7 {. raw do. '' return. end.
  try.
    parsed =. dec_json raw
    if. has_error parsed do. '' return. end.
    jev_unfence strip_thinking get_or_content parsed
  catch.
    ''
  end.
)

NB. strip markdown code fences (```j ... ```) from a solver
NB. proposal - models often fence despite 'only the code'
jev_unfence =: monad define
  if. 0 = # y do. '' return. end.
  t =. y
  if. LF ~: {: t do. t =. t , LF end.
  out =. ''
  fence =. 3 # 96 { a.    NB. ``` built from a. - backtick literals in
  for_l. <;._2 t do.      NB. J source invite gerund/parse trouble
    ln =. > l
    if. fence ~: 3 {. ln do.
      out =. out , ln , LF
    end.
  end.
  out
)

echo 'jev loaded.'
