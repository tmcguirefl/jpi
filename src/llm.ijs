NB. LLM integration (OpenRouter / Anthropic)
NB. llm.ijs
NB. dec_json for parsing responses, enc_json_fixed for encoding.

require 'convert/json'
load 'enc_json_fixed.ijs'
load 'http.ijs'
load 'system_prompt.ijs'
load 'context.ijs'
load 'usage.ijs'

NB. ----------------------------------------------------------------
NB. Tool parameter schemas
READ_PARAMS  =: '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"offset":{"type":"number","description":"Line number to start from (1-indexed)"},"limit":{"type":"number","description":"Max lines to read (default 2000)"}},"required":["path"]}'
RUN_PARAMS   =: '{"type":"object","properties":{"command":{"type":"string","description":"Bash command to execute"},"timeout":{"type":"number","description":"Timeout in seconds (default 30)"}},"required":["command"]}'
EDIT_PARAMS  =: '{"type":"object","properties":{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}},"required":["path","old_text","new_text"]}'
WRITE_PARAMS =: '{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}'
J_PARAMS     =: '{"type":"object","properties":{"code":{"type":"string","description":"J code to evaluate"}},"required":["code"]}'

NB. ----------------------------------------------------------------
NB. Build a single tool JSON string
NB. x = schema key ('parameters' or 'input_schema'), y = name;desc;params
NB. Name and description are JSON-escaped; params is already a JSON string.
mk_tool =: dyad define
  'n d p' =. y
  '{"name":' , (enc_json_fixed n) , ',"description":' , (enc_json_fixed d) , ',"' , x , '":' , p , '}'
)

NB. ----------------------------------------------------------------
NB. Build tools JSON array for current provider
NB. Anthropic uses input_schema and no function wrapper; all other
NB. providers (openrouter, google, tcm, local, ollama, cohere, hyai)
NB. use the {"type":"function","function":...} form with parameters.
get_tools =: monad define
  defs =. (<'read';'Read file contents';READ_PARAMS) , (<'bash';'Execute shell command';RUN_PARAMS) , (<'edit';'Edit file with find/replace';EDIT_PARAMS) , (<'write';'Write content to file';WRITE_PARAMS) , (<'j';'Evaluate J programming language code directly in the agent interpreter session';J_PARAMS)
  r =. ''
  for_d. defs do.
    t =. (schema_key '') mk_tool > d
    if. uses_openai_tools '' do.
      r =. r , ',' , '{"type":"function","function":' , t , '}'
    else.
      r =. r , ',' , t
    end.
  end.
  NB. append extension tools if any
  r =. r , get_ext_tools_json ''
  NB. append MCP server tools if any
  r =. r , get_mcp_tools_json ''
  '[' , (}. r) , ']'
)

NB. ----------------------------------------------------------------
NB. Conversation history: boxed list of JSON message strings
HISTORY =: 0 $ <''

NB. Max tool call iterations before giving up.
NB. No hard limit — the model self-regulates via the system prompt.
NB. Set high enough that it never trips in practice.
MAX_TOOL_LOOPS =: 1e9

NB. Reset conversation
clear_history =: monad define
  HISTORY =: 0 $ <''
  echo 'Conversation cleared.'
)

NB. Build a JSON message string for a role/content pair
mk_msg =: dyad define
  '{"role":' , (enc_json_fixed x) , ',"content":' , (enc_json_fixed y) , '}'
)

NB. ----------------------------------------------------------------
NB. Mid-run steering: a prompt typed while the agent is working.
NB. The TUI installs tui_steer_poll (non-blocking key capture) and
NB. llm_call calls it from its spinner loop while a request is in
NB. flight. A completed line lands in STEER_MSG and is injected as
NB. a user message at the next iteration boundary of the tool loop
NB. (one model-turn latency); anything still pending when an ask
NB. ends is injected at the start of the next ask, so nothing
NB. typed is ever silently dropped.
STEER_MSG =: ''

NB. Thinking/reasoning request parameter for the active provider.
NB. Returns a JSON fragment to splice after "stream":false, or ''
NB. when the provider has no thinking control (fragment is omitted).
NB. Cohere v2: thinking {type, token_budget} — verified against
NB. api.cohere.com/v2/chat; token_budget caps reasoning tokens.
thinking_param =: monad define
  select. PROVIDER
  case. 'cohere' do.
    if. THINK_ON do.
      if. 0 < THINK_BUDGET do.
        ',"thinking":{"type":"enabled","token_budget":' , (": THINK_BUDGET) , '}'
      else.
        ',"thinking":{"type":"enabled"}'
      end.
    else.
      ',"thinking":{"type":"disabled"}'
    end.
  case. do. ''
  end.
)

NB. ----------------------------------------------------------------
NB. History replay hardening (strict chat deserializers).
NB.
NB. fix_assistant_content: hyai's strict types reject ANY assistant
NB. message whose content is missing or non-string (HTTP 400
NB. missing field 'content'). safe_assistant_msg covers messages
NB. stored since it was added; older saved sessions and numeric
NB. content (zai tool-call turns carry content 0) still slip in.
NB. Non-assistant messages pass through untouched.
fix_assistant_content =: monad define
  if. -. '{"role":"assistant"' -: (19 <. #y) {. y do. y return. end.
  try.
    o =. dec_json y
    c =. 'content' gethash_json o
    cs =. > c
    if. (_1 -: cs) +. (2 -.@e.~ 3!:0 cs) do.
      keys =. 0 { o
      vals =. 1 { o
      i =. keys i. <'content'
      if. i < # keys do.
        vals =. (< (<'')) i } vals
        o =. keys ,: vals
      else.
        o =. (keys , <'content') ,: (vals , < <'')
      end.
      enc_json_fixed o return.
    end.
    y
  catch. y end.
)

NB. strip_tool_msgs: the no-tools fallback drops the tools field but
NB. must also drop tool ARTIFACTS from history. Replaying assistant
NB. tool_calls with no tools declared gets every call flagged
NB. (cohere HTTP 422 HALLUCINATED_ALL_TOOL_CALLS); the replayed
NB. tool-role messages have no declared tool to bind to either.
NB. Assistant tool-call messages degrade to plain content (''
NB. when the content was missing/non-string); tool results drop.
strip_tool_msgs =: monad define
  out =. 0 $ <''
  for_m. y do.
    s =. > m
    if. '{"role":"tool"' -: (14 <. #s) {. s do. continue. end.
    if. '{"role":"assistant"' -: (19 <. #s) {. s do.
      try.
        o =. dec_json s
        if. _1 -.@-: 'tool_calls' gethash_json o do.
          c =. 'content' gethash_json o
          cs =. > c
          if. (_1 -: cs) +. (2 -.@e.~ 3!:0 cs) do.
            s =. enc_json_fixed ('role';'content') ,: 'assistant' ; <''
          else.
            s =. enc_json_fixed ('role';'content') ,: 'assistant' ; c
          end.
        end.
      catch. end.
    end.
    out =. out , < s
  end.
  out
)

NB. Build the full request payload from conversation history
NB. y = optional flag: 1 = omit tools (for fallback after 422 errors)
build_payload =: monad define
  NB. trim history if approaching context window limit
  trim_history ''
  NB. J's if. evaluates empty arrays as true (AND of empty = 1), so we
  NB. guard with a length check before testing the truth value of y.
  no_tools =. 0
  if. (0 < #y) do. if. y do. no_tools =. 1 end. end.

  NB. Standard OpenAI-compatible format for most providers (including Cohere)
  sys =. 'system' mk_msg get_system_prompt ''
  hist =. HISTORY
  if. no_tools do. hist =. strip_tool_msgs hist end.
  hist =. fix_assistant_content each hist
  all =. (< sys) , hist
  msgs =. _1 }. ; (,&',') each all

  NB. Anthropic requires max_tokens; all other providers omit it
  api_model =. model_for_api MODEL
  tp =. thinking_param ''
  if. uses_openai_tools '' do.
    if. no_tools do.
      payload =. '{"model":"' , api_model , '","stream":false' , tp , ',"messages":[' , msgs , ']}'
    else.
      payload =. '{"model":"' , api_model , '","stream":false' , tp , ',"tools":' , (get_tools '') , ',"messages":[' , msgs , ']}'
    end.
  else.
    if. no_tools do.
      payload =. '{"model":"' , api_model , '","stream":false' , tp , ',"max_tokens":4096,"messages":[' , msgs , ']}'
    else.
      payload =. '{"model":"' , api_model , '","stream":false' , tp , ',"max_tokens":4096,"tools":' , (get_tools '') , ',"messages":[' , msgs , ']}'
    end.
  end.
)

NB. ----------------------------------------------------------------
NB. Spinner frames
SPINNER =: '|';'/';'-';'\'

NB. Draw one spinner frame on the last line of the output area.
NB. y = frame index. Uses direct VT writes (bypasses TUI buffer).
NB. Falls back to no-op if VT verbs aren't available.
tui_spinner_frame =: monad define
  if. -. 3 = 4!:0 <'puts' do. '' return. end.
  try.
    frame =. > y { SPINNER
    oh =. out_h ''
    goxy 0 , oh - 1
    reset''
    puts frame , ' thinking...'
    ceol''
  catch. end.
)

NB. Clear the spinner line.
tui_spinner_clear =: monad define
  if. -. 3 = 4!:0 <'puts' do. '' return. end.
  try.
    oh =. out_h ''
    goxy 0 , oh - 1
    reset''
    ceol''
  catch. end.
)

NB. Send payload to LLM, return parsed JSON response
NB. Uses async curl + spinner if TUI is active, else blocking
NB. Same-body retry budget for transient vendor 4xx/5xx flakes.
NB. (Verified 2026-10-19: hyai/zai intermittently rejects large
NB. bodies with a misleading "missing field content" error whose
NB. column wanders; identical bodies pass on retry. The count is
NB. global so nested retries share the budget.)
HTTP_RETRIES =: 0
HTTP_TRIES_MAX =: 2

llm_call =: monad define
  
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set for provider: ' , PROVIDER
    echo 'Add your provider key (e.g. OPENROUTER_API_KEY=sk-...) to ~/.jpi_providers'
    '' return.
  end.
  t0 =. 6!:1 ''

  NB. Non-streaming POST: returns complete JSON with tool_calls structured.
  NB. http_post returns 'ERROR: ...' on curl failure (bad connection, non-2xx).
  is_tui =. 3 = 4!:0 <'tui_print'
  if. is_tui do.
    NB. Redraw so user sees current output (e.g. "Asking LLM...")
    tui_redraw ''
    NB. Start async request and animate spinner while waiting
    API_URL http_post_async y
    spin =. 0
    timeout =. 120  NB. seconds before giving up
    while. -. http_async_done '' do.
      tui_spinner_frame spin
      NB. steering capture: keys typed during the API wait
      if. 3 = 4!:0 <'tui_steer_poll' do. tui_steer_poll '' end.
      6!:3 ] 0.15
      spin =. (#SPINNER) | spin + 1
      if. timeout < (6!:1 '') - t0 do. break. end.
    end.
    tui_spinner_clear ''
    raw =. http_async_result ''
  else.
    raw =. API_URL http_post y
  end.

  t1 =. 6!:1 ''
  elapsed =. t1 - t0
  echo '  [' , (}: ": 0.01 * <. 100 * elapsed) , 's]'

  NB. Check for transport-level error from http_post
  if. 'ERROR: ' -: 7 {. raw do.
    NB. Transient vendor flake defense: 4xx/5xx rejections (not
    NB. timeouts - those took the full timeout budget already)
    NB. get same-body retries before any fallback fires.
    is_4xx_5xx =. ('ERROR: HTTP 4' -: 13 {. raw) +. ('ERROR: HTTP 5' -: 13 {. raw)
    if. (HTTP_RETRIES < HTTP_TRIES_MAX) *. is_4xx_5xx do.
      HTTP_RETRIES =: HTTP_RETRIES + 1
      echo '  transient vendor error; retrying same request (' , (": HTTP_RETRIES) , '/' , (": HTTP_TRIES_MAX) , ')'
      6!:3 ] 0.5
      r =. llm_call y
      HTTP_RETRIES =: 0
      r return.
    end.
    HTTP_RETRIES =: 0
    echo raw
    '' return.
  end.

  NB. Parse the response
  try.
    parsed =. dec_json raw
  catch.
    echo 'ERROR: Failed to parse response: ' , 13!:12 ''
    echo 'Raw response: ' , raw
    '' return.
  end.
  
  NB. Workaround for some Google API errors returning an array `[{error:...}]`
  if. 1 = $$ parsed do. parsed =. > {. parsed end.
  if. has_error parsed do.
    show_error parsed
  end.
  track_usage parsed
  parsed
)

NB. ----------------------------------------------------------------
NB. Check if response has API error
NB. Explicit original:
NB.   has_error =: monad define
NB.     _1 -.@-: 'error' gethash_json y
NB. )
has_error =: -.@(_1&-:)@('error'&gethash_json)

NB. Show API error message
show_error =: monad define
  err =. > 'error' gethash_json y
  msg =. > 'message' gethash_json err
  echo 'API error: ' , msg
)

NB. ----------------------------------------------------------------
NB. OpenRouter (OpenAI format) response parsing

NB. Get the assistant message object from response
NB. gethash_json returns _1 (integer) for a missing key; > _1 = _1 (not an
NB. error); #_1 = 1 (not 0). So the not-found check must be _1 -: msg,
NB. not 0 = #msg.
get_or_message =: monad define
  select. PROVIDER
  case. 'cohere' do.
    NB. Cohere v2 can return either native format or OpenAI-compatible format
    msg =. ''
    try.
      msg =. > 'message' gethash_json y
    catch.
      msg =. ''
    end.
    if. (_1 -: msg) +. 0 = #msg do.
      NB. Not native format, try OpenAI-compatible format
      try.
        choices =. > 'choices' gethash_json y
        if. (_1 -.@-: choices) *. 0 < #choices do.
          msg =. > 'message' gethash_json > {. choices
        else.
          msg =. y
        end.
      catch.
        msg =. y
      end.
    end.
    msg
  case. do.
    try.
      choices =. > 'choices' gethash_json y
      if. (_1 -.@-: choices) *. 0 < #choices do.
        > 'message' gethash_json > {. choices
      else.
        y
      end.
    catch.
      y
    end.
  end.
)

NB. Get finish_reason from response
get_or_finish =: monad define
  select. PROVIDER
  case. 'cohere' do.
    NB. Cohere v2 can return either native format or OpenAI-compatible format
    finish =. ''
    try.
      finish =. > 'finish_reason' gethash_json y
    catch.
    end.
    if. (_1 -: finish) +. 0 = #finish do.
      NB. Not in root, try in choices
      try.
        choices =. > 'choices' gethash_json y
        if. (_1 -.@-: choices) *. 0 < #choices do.
          finish =. > 'finish_reason' gethash_json > {. choices
        end.
      catch.
      end.
    end.
    finish
  case. do.
    try.
      choices =. > 'choices' gethash_json y
      if. (_1 -.@-: choices) *. 0 < #choices do.
        r =. > 'finish_reason' gethash_json > {. choices
        if. _1 -: r do. '' else. r end.
      else.
        ''
      end.
    catch.
      ''
    end.
  end.
)

NB. Check if response contains tool calls
is_tool_call =: monad define
  finish =. get_or_finish y
  select. PROVIDER
  case. 'cohere' do.
    NB. Cohere v2: check if finish_reason indicates tool calls or if tool_calls exist
    NB. Cohere uses 'TOOL_CALLS' or may have tool_calls present regardless of finish_reason
    msg =. get_or_message y
    has_tool_calls =. _1 -.@-: 'tool_calls' gethash_json msg
    (finish -: 'tool_calls') +. has_tool_calls
  case. do.
    finish -: 'tool_calls'
  end.
)

NB. Extract text content from assistant message
get_or_content =: monad define
  msg =. get_or_message y
  select. PROVIDER
  case. 'cohere' do.
    NB. Cohere v2 message.content can be an array or a string
    content =. ''
    try.
      content =. > 'content' gethash_json msg
    catch.
      '' return.
    end.
    if. _1 -: content do.
      '' return.
    elseif. 32 = 3!:0 content do.
      NB. content is a boxed array of objects (e.g. thinking + text).
      NB. Iterate to find the element with a 'text' key.
      text =. ''
      for_c. content do.
        try.
          t =. > 'text' gethash_json > c
          if. (_1 -.@-: t) *. 0 < #t do.
            text =. t
            break.
          end.
        catch.
        end.
      end.
      text
    elseif. 2 = 3!:0 content do.
      NB. content is a direct string
      content
    else.
      ''
    end.
  case. do.
    try.
      r =. > 'content' gethash_json msg
      if. _1 -: r do. '' return. end.
      if. 32 = 3!:0 r do.
        NB. block-array content (e.g. Mistral zai reasoning
        NB. models: thinking + text blocks). Find the text
        NB. block, skipping thinking blocks.
        text =. ''
        for_c. r do.
          try.
            t =. > 'text' gethash_json > c
            if. (_1 -.@-: t) *. 0 < #t do. text =. t break. end.
          catch.
          end.
        end.
        text
      else.
        r
      end.
    catch.
      ''
    end.
  end.
)

NB. Get tool_calls array from assistant message
get_or_tool_calls =: monad define
  msg =. get_or_message y
  select. PROVIDER
  case. 'cohere' do.
    NB. Cohere v2 can have tool_calls in message or at root level
    tool_calls =. ''
    try.
      tool_calls =. > 'tool_calls' gethash_json msg
    catch.
    end.
    if. (_1 -: tool_calls) +. 0 = #tool_calls do.
      NB. Try root level
      try.
        tool_calls =. > 'tool_calls' gethash_json y
      catch.
      end.
    end.
    tool_calls
  case. do.
    try.
      > 'tool_calls' gethash_json msg
    catch.
      0 $ <''
    end.
  end.
)

NB. Extract id, function name, and parsed arguments from one tool call
parse_or_tool_call =: monad define
  tc_id =. > 'id' gethash_json y
  func =. > 'function' gethash_json y
  NB. Guard: if 'function' key is missing, gethash_json returns _1.
  NB. Passing _1 to gethash_json again triggers assertion failure
  NB. (2=$$y) because _1 is not a rank-2 table.
  if. _1 -: func do. tc_id ; 'unknown' ; '' ; < 0 2 $ '' return. end.
  name =. > 'name' gethash_json func
  args_str =. > 'arguments' gethash_json func
  args =. dec_json args_str
  NB. box args with < to prevent flattening (args is a 2-row table)
  tc_id ; name ; args_str ; < args
)

NB. Build a tool result message
NB. y = tool_call_id ; result_string
mk_tool_result =: monad define
  'tc_id result' =. y
  '{"role":"tool","tool_call_id":' , (enc_json_fixed tc_id) , ',"content":' , (enc_json_fixed result) , '}'
)

NB. ----------------------------------------------------------------
NB. Process tool calls: execute each, return boxed list of result messages
NB. y = parsed API response
process_tool_calls =: monad define
  calls =. get_or_tool_calls y
  results =. 0 $ <''
  for_c. calls do.
    try.
      'tc_id name args_str args' =. parse_or_tool_call > c
      NB. Show tool name and arguments for visibility
      if. 0 < #args_str do.
        echo 'Tool call: ' , name , ' ' , args_str
      else.
        echo 'Tool call: ' , name
      end.
      NB. box args with < to prevent ; from flattening the 2-row table
      result =. exec_tool name ; < args
      NB. Show first 500 chars of result, ellipsis if truncated
      preview =. 500 {. result
      if. 500 < #result do. preview =. preview , '...' end.
      echo 'Tool result: ' , preview
    catch.
      err_msg =. 13!:12 ''
      if. 0 = #tc_id do. tc_id =. 'unknown' end.
      result =. 'ERROR: tool execution failed during parsing or validation: ' , err_msg
      echo result
    end.
    results =. results , < mk_tool_result tc_id ; result
  end.
  results
)

NB. ----------------------------------------------------------------
NB. History replay sanitization: strict schemas (Mistral) reject
NB. extra message fields with HTTP 422 extra_forbidden when an
NB. assistant message is replayed. Newer reasoning models attach
NB. non-schema fields (zai messages carry a top-level 'index' and
NB. per-tool-call 'index'). Rebuild tool-call messages from
NB. schema-safe fields only. Parsed JSON objects are 2-row tables
NB. (row 0 keys, row 1 values) per enc_json_fixed/dec_json.

NB. x = boxed list of kept keys, y = parsed JSON object (2-row table)
obj_keep_keys =: dyad define
  keys =. 0 { y
  vals =. 1 { y
  outk =. 0 $ <''
  outv =. 0 $ <''
  for_i. i. # keys do.
    if. (< > i { keys) e. x do.
      outk =. outk , < > i { keys
      outv =. outv , < i { vals
    end.
  end.
  outk ,: outv
)

NB. Rebuild an assistant tool-call message keeping only
NB. role/content/tool_calls at message level and id/type/function
NB. inside each tool call.
safe_assistant_msg =: monad define
  m =. get_or_message y
  tcs =. get_or_tool_calls y
  tclean =. 0 $ <''
  if. _1 -.@-: tcs do.
    for_tc. tcs do.
      tclean =. tclean , < ('id';'type';'function') obj_keep_keys > tc
    end.
  end.
  c =. 'content' gethash_json m
  NB. Content must ALWAYS be present: zai tool-call turns carry a
  NB. numeric content (0), which strict schemas reject when
  NB. replayed - but strict deserialization (hyai/zai GLM) ALSO
  NB. rejects a MISSING content field (invalid_request_error:
  NB. missing field 'content'). Emit an empty string in that case.
  keys =. 'role';'content';'tool_calls'
  if. (_1 -: > c) +. (2 -.@e.~ 3!:0 > c) do.
    vals =. 'assistant' ; (< '') ; < tclean
  else.
    vals =. 'assistant' ; c ; < tclean
  end.
  keys ,: vals
)

NB. ----------------------------------------------------------------
NB. Remove <thinking>...</thinking> spans from a reply. The
NB. system prompt asks models to use these tags; models with
NB. native thinking (Cohere North, Mistral zai) may ALSO emit
NB. them as literal content, which pollutes history (the model
NB. then reads its own meta-reasoning as content on later turns)
NB. and downstream consumers of the reply. Native thinking blocks
NB. are already separated by get_or_content; this handles the
NB. instructed-tag form. Unclosed spans are dropped to the end.
strip_thinking =: monad define
  s =. y
  while. 1 do.
    m =. '<thinking>' E. s
    if. -. +./ m do. break. end.
    a =. m i. 1
    m2 =. '</thinking>' E. s
    if. -. +./ m2 do.
      s =. a {. s
    else.
      b =. (m2 i. 1) + # '</thinking>'
      s =. (a {. s) , b }. s
    end.
  end.
  dltb dlb s
)

NB. Multi-turn ask with tool use loop
NB. y = question string
llm_ask =: monad define
  NB. carried-over steering: typed during the previous ask's final
  NB. API call (no iteration followed) - inject before the new prompt
  if. 0 < # STEER_MSG do.
    HISTORY =: HISTORY , < 'user' mk_msg STEER_MSG
    echo 'STEER (carried over): ' , STEER_MSG
    STEER_MSG =: ''
  end.
  NB. add user message to history
  HISTORY =: HISTORY , < 'user' mk_msg y
  NB. loop: send history, handle tool calls, repeat until text reply
  loops =. 0
  retried_no_tools =. 0
  while. loops < MAX_TOOL_LOOPS do.
    loops =. loops + 1
    NB. steering: a line typed mid-run (tui_steer_poll during the
    NB. previous API wait) injects as a user message here, at the
    NB. NEXT iteration boundary - the model sees it with the tool
    NB. results that follow.
    if. (loops > 1) *. 0 < # STEER_MSG do.
      HISTORY =: HISTORY , < 'user' mk_msg STEER_MSG
      echo 'STEER: ' , STEER_MSG
      STEER_MSG =: ''
    end.
    try.
      payload =. build_payload retried_no_tools
      resp =. llm_call payload
      if. 0 = #resp do.
        NB. If this is the first failure and we haven't retried yet,
        NB. retry without tools (handles Cohere HALLUCINATED_ALL_TOOL_CALLS 422)
        if. 0 = retried_no_tools do.
          retried_no_tools =. 1
          echo 'Retrying without tools (LLM may have rejected tool definitions)...'
          continue.
        end.
        echo 'ERROR: empty response from LLM'
        '' return.
      end.
      if. has_error resp do. show_error resp [ '' return. end.
      NB. check if LLM wants to call tools
      if. is_tool_call resp do.
        NB. add assistant message (with tool_calls) to history,
        NB. rebuilt from schema-safe fields (zai reasoning models
        NB. attach extra 'index' fields strict schemas reject)
        HISTORY =: HISTORY , < enc_json_fixed safe_assistant_msg resp
        NB. execute tools and add results to history
        results =. process_tool_calls resp
        HISTORY =: HISTORY , results
      else.
        NB. normal text reply — extract, strip instructed
        NB. <thinking> spans, add to history, return
        reply =. strip_thinking get_or_content resp
        if. 0 < #reply do.
          HISTORY =: HISTORY , < 'assistant' mk_msg reply
        end.
        reply return.
      end.
    catch.
      echo 'ERROR in tool loop: ' , 13!:12 ''
      '' return.
    end.
  end.
  echo 'ERROR: too many tool call iterations (' , (":MAX_TOOL_LOOPS) , ')'
  ''
)

echo 'llm loaded. Provider: ' , PROVIDER
