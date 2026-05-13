NB. LLM integration (OpenRouter / Anthropic)
NB. llm.ijs
NB. Outbound JSON built as strings (avoids enc_json shape issues).
NB. dec_json / gethash_json used only for parsing inbound responses.

require 'convert/json'
load 'http.ijs'

NB. ----------------------------------------------------------------
NB. Tool parameter schemas
READ_PARAMS  =: '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"limit":{"type":"number","description":"Max lines"}},"required":["path"]}'
RUN_PARAMS   =: '{"type":"object","properties":{"command":{"type":"string","description":"Command to run"}},"required":["command"]}'
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
build_payload =: monad define
  tools =. get_tools ''
  msgs =. _1 }. ; (,&',') each HISTORY
  '{"model":"' , MODEL , '","max_tokens":4096,"tools":' , tools , ',"messages":[' , msgs , ']}'
)

NB. ----------------------------------------------------------------
NB. Send payload to LLM, return parsed JSON response
llm_call =: monad define
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set.'
    echo 'Set OPENROUTER_API_KEY or ANTHROPIC_API_KEY env var.'
    '' return.
  end.
  raw =. API_URL http_post y
  dec_json raw
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
  NB. OpenAI uses 'tool_calls' as finish_reason
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
  tc_id ; name ; args
)

NB. Extract the assistant message JSON from raw API response string
NB. Finds "message":{...} in the raw response and extracts the object
extract_raw_message =: monad define
  NB. y = raw JSON response string
  NB. find '"message":' and extract the balanced braces after it
  idx =. I. '"message":' E. y
  if. 0 = #idx do. '{}' return. end.
  start =. ({. idx) + 10              NB. skip past '"message":'
  NB. count balanced braces to find end
  depth =. 0
  pos =. start
  while. pos < #y do.
    ch =. pos { y
    if. ch = '{' do. depth =. depth + 1 end.
    if. ch = '}' do. depth =. depth - 1 end.
    if. (depth = 0) *. (pos > start) do. break. end.
    pos =. pos + 1
  end.
  (pos - start + 1) {. start }. y
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
    'tc_id name args' =. parse_or_tool_call > c
    echo 'Tool call: ' , name
    result =. exec_tool name ; args
    echo 'Tool result: ' , 80 {. result
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
    payload =. build_payload ''
    resp =. llm_call payload
    if. 0 = #resp do. '' return. end.
    if. has_error resp do. show_error resp [ '' return. end.
    NB. check if LLM wants to call tools
    if. is_tool_call resp do.
      NB. add assistant message (with tool_calls) to history
      NB. extract raw message JSON from API response to avoid enc_json
      raw =. fread HTTP_TMPFILE
      asst_msg =. extract_raw_message raw
      HISTORY =: HISTORY , < asst_msg
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
  end.
  echo 'ERROR: too many tool call iterations'
  ''
)

echo 'llm loaded. Provider: ' , PROVIDER
