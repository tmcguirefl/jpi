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

NB. ----------------------------------------------------------------
NB. Build a single tool JSON string
NB. x = schema key ('parameters' or 'input_schema'), y = name;desc;params
mk_tool =: dyad define
  'n d p' =. y
  '{"name":"' , n , '","description":"' , d , '","' , x , '":' , p , '}'
)

NB. ----------------------------------------------------------------
NB. Build tools JSON array for current provider
get_tools =: monad define
  defs =. (<'read';'Read file contents';READ_PARAMS) , (<'bash';'Execute shell command';RUN_PARAMS) , (<'edit';'Edit file with find/replace';EDIT_PARAMS) , (<'write';'Write content to file';WRITE_PARAMS)
  r =. ''
  select. PROVIDER
  case. 'openrouter' do.
    for_d. defs do.
      t =. 'parameters' mk_tool > d
      r =. r , ',' , '{"type":"function","function":' , t , '}'
    end.
  case. 'anthropic' do.
    for_d. defs do.
      r =. r , ',' , 'input_schema' mk_tool > d
    end.
  end.
  NB. append extension tools if any
  r =. r , get_ext_tools_json ''
  '[' , (}. r) , ']'
)

NB. ----------------------------------------------------------------
NB. Escape a string for embedding in JSON
json_esc =: monad define
  y rplc '\';'\\';'"';'\"';LF;'\n';CR;'\r';TAB;'\t'
)

NB. ----------------------------------------------------------------
NB. Conversation history: boxed list of JSON message strings
HISTORY =: 0 $ <''

NB. Max tool call iterations before giving up
MAX_TOOL_LOOPS =: 10

NB. Reset conversation
clear_history =: monad define
  HISTORY =: 0 $ <''
  echo 'Conversation cleared.'
)

NB. Build a JSON message string for a role/content pair
mk_msg =: dyad define
  '{"role":"' , x , '","content":"' , (json_esc y) , '"}'
)

NB. Build the full request payload from conversation history
NB. y = 0 for non-streaming, 1 for streaming
build_payload =: monad define
  NB. trim history if approaching context window limit
  trim_history ''
  tools =. get_tools ''
  NB. system message first, then conversation history
  sys =. 'system' mk_msg SYSTEM_PROMPT
  all =. (< sys) , HISTORY
  msgs =. _1 }. ; (,&',') each all
  stream =. ''
  if. y do. stream =. ',"stream":true' end.
  '{"model":"' , MODEL , '","max_tokens":4096' , stream , ',"tools":' , tools , ',"messages":[' , msgs , ']}'
)

NB. ----------------------------------------------------------------
NB. Send payload to LLM, return parsed JSON response
llm_call =: monad define
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set.'
    echo 'Set OPENROUTER_API_KEY or ANTHROPIC_API_KEY env var.'
    '' return.
  end.
  t0 =. 6!:1 ''                    NB. start timer
  raw =. API_URL http_post y
  t1 =. 6!:1 ''                    NB. end timer
  elapsed =. t1 - t0
  echo '  [' , (}: ": 0.01 * <. 100 * elapsed) , 's]'
  parsed =. dec_json raw
  NB. track token usage from response
  track_usage parsed
  parsed
)

NB. ================================================================
NB. Streaming support
NB. Polls temp file for SSE lines, extracts tokens, echoes them live

NB. Whether streaming is enabled (can be toggled)
STREAM_ENABLED =: 1

NB. Parse one SSE data line and extract the content delta token
NB. y = a single "data: {...}" line
NB. Returns the token string or '' if none
parse_sse_token =: monad define
  NB. strip "data: " prefix
  if. -. 'data: ' +./@E. y do. '' return. end.
  json_str =. 6 }. y
  if. json_str -: '[DONE]' do. '' return. end.
  try.
    parsed =. dec_json json_str
    choices =. > 'choices' gethash_json parsed
    delta =. > 'delta' gethash_json > {. choices
    content =. 'content' gethash_json delta
    if. _1 -: content do. '' return. end.
    > content
  catch.
    ''
  end.
)

NB. Check if SSE stream contains a tool_calls response
NB. y = full raw SSE text
sse_has_tool_calls =: monad define
  'tool_calls' +./@E. y
)

NB. Streaming LLM call — displays tokens as they arrive
NB. y = json payload (with stream:true)
NB. Returns the full accumulated text, or the raw SSE text if tool_calls detected
llm_call_stream =: monad define
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set.'
    '' return.
  end.
  t0 =. 6!:1 ''
  NB. start background curl
  API_URL http_post_stream_start y
  NB. poll for output
  prev_len =. 0
  full_text =. ''
  while. 1 do.
    6!:3 (0.1)                       NB. sleep 100ms
    raw =. http_stream_read ''
    new =. prev_len }. raw
    prev_len =. #raw
    if. 0 < #new do.
      NB. parse SSE lines in the new chunk
      lines =. <;._2 new , LF -. {: new , LF
      for_l. lines do.
        line =. > l
        if. 'data: ' +./@E. line do.
          token =. parse_sse_token line
          if. 0 < #token do.
            NB. echo token without newline (build up the response inline)
            1!:2&2 token
            full_text =. full_text , token
          end.
        end.
      end.
    end.
    NB. check if curl finished
    if. -. http_stream_alive '' do.
      NB. read any final bytes
      raw =. http_stream_read ''
      new =. prev_len }. raw
      if. 0 < #new do.
        lines =. <;._2 new , LF -. {: new , LF
        for_l. lines do.
          line =. > l
          if. 'data: ' +./@E. line do.
            token =. parse_sse_token line
            if. 0 < #token do.
              1!:2&2 token
              full_text =. full_text , token
            end.
          end.
        end.
      end.
      break.
    end.
  end.
  1!:2&2 LF                          NB. newline after streamed output
  t1 =. 6!:1 ''
  echo '  [' , (}: ": 0.01 * <. 100 * t1 - t0) , 's]'
  NB. check if it was a tool call response
  raw =. http_stream_read ''
  if. sse_has_tool_calls raw do.
    NB. fall back: re-call without streaming to get proper JSON
    'tool_call' return.
  end.
  full_text
)

NB. ----------------------------------------------------------------
NB. Check if response has API error
has_error =: monad define
  _1 -.@-: 'error' gethash_json y
)

NB. Show API error message
show_error =: monad define
  err =. > 'error' gethash_json y
  msg =. > 'message' gethash_json err
  echo 'API error: ' , msg
)

NB. ----------------------------------------------------------------
NB. OpenRouter (OpenAI format) response parsing

NB. Get the assistant message object from response
get_or_message =: monad define
  choices =. > 'choices' gethash_json y
  > 'message' gethash_json > {. choices
)

NB. Get finish_reason from response
get_or_finish =: monad define
  choices =. > 'choices' gethash_json y
  > 'finish_reason' gethash_json > {. choices
)

NB. Check if response contains tool calls
is_tool_call =: monad define
  finish =. get_or_finish y
  finish -: 'tool_calls'
)

NB. Extract text content from assistant message
get_or_content =: monad define
  msg =. get_or_message y
  > 'content' gethash_json msg
)

NB. Get tool_calls array from assistant message
get_or_tool_calls =: monad define
  msg =. get_or_message y
  > 'tool_calls' gethash_json msg
)

NB. Extract id, function name, and parsed arguments from one tool call
parse_or_tool_call =: monad define
  tc_id =. > 'id' gethash_json y
  func =. > 'function' gethash_json y
  name =. > 'name' gethash_json func
  args_str =. > 'arguments' gethash_json func
  args =. dec_json args_str
  NB. box args with < to prevent flattening (args is a 2-row table)
  tc_id ; name ; < args
)

NB. Build a tool result message
NB. y = tool_call_id ; result_string
mk_tool_result =: monad define
  'tc_id result' =. y
  '{"role":"tool","tool_call_id":"' , tc_id , '","content":"' , (json_esc result) , '"}'
)

NB. ----------------------------------------------------------------
NB. Process tool calls: execute each, return boxed list of result messages
NB. y = parsed API response
process_tool_calls =: monad define
  calls =. get_or_tool_calls y
  results =. 0 $ <''
  for_c. calls do.
    try.
      'tc_id name args' =. parse_or_tool_call > c
      echo 'Tool call: ' , name
      NB. box args with < to prevent ; from flattening the 2-row table
      result =. exec_tool name ; < args
      echo 'Tool result: ' , 80 {. result
    catch.
      tc_id =. 'unknown'
      result =. 'ERROR: tool execution failed: ' , 13!:12 ''
      echo result
    end.
    results =. results , < mk_tool_result tc_id ; result
  end.
  results
)

NB. ----------------------------------------------------------------
NB. Multi-turn ask with tool use loop
NB. y = question string
llm_ask =: monad define
  NB. add user message to history
  HISTORY =: HISTORY , < 'user' mk_msg y
  NB. loop: send history, handle tool calls, repeat until text reply
  loops =. 0
  while. loops < MAX_TOOL_LOOPS do.
    loops =. loops + 1
    try.
      NB. first attempt: try streaming if enabled
      if. STREAM_ENABLED *. loops = 1 do.
        payload =. build_payload 1    NB. stream=true
        reply =. llm_call_stream payload
        NB. if tool_call detected, fall back to non-streaming
        if. reply -: 'tool_call' do.
          payload =. build_payload 0
          resp =. llm_call payload
        else.
          NB. streaming produced a text reply
          if. 0 < #reply do.
            HISTORY =: HISTORY , < 'assistant' mk_msg reply
          end.
          reply return.
        end.
      else.
        NB. non-streaming (tool call iterations or streaming disabled)
        payload =. build_payload 0
        resp =. llm_call payload
      end.
      if. 0 = #resp do.
        echo 'ERROR: empty response from LLM'
        '' return.
      end.
      if. has_error resp do. show_error resp [ '' return. end.
      NB. check if LLM wants to call tools
      if. is_tool_call resp do.
        NB. add assistant message (with tool_calls) to history
        HISTORY =: HISTORY , < enc_json_fixed get_or_message resp
        NB. execute tools and add results to history
        results =. process_tool_calls resp
        HISTORY =: HISTORY , results
      else.
        NB. normal text reply — extract, add to history, return
        reply =. get_or_content resp
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
