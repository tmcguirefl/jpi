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
build_payload =: monad define
  NB. trim history if approaching context window limit
  trim_history ''
  tools =. get_tools ''
  NB. system message first, then conversation history
  sys =. 'system' mk_msg SYSTEM_PROMPT
  all =. (< sys) , HISTORY
  msgs =. _1 }. ; (,&',') each all
  
  NB. Do not send max_tokens for openrouter, it truncates some models naturally
  if. PROVIDER -: 'openrouter' do.
    '{"model":"' , MODEL , '","tools":' , tools , ',"messages":[' , msgs , ']}'
  else.
    '{"model":"' , MODEL , '","max_tokens":4096,"tools":' , tools , ',"messages":[' , msgs , ']}'
  end.
)

NB. ----------------------------------------------------------------
NB. Spinner frames
SPINNER =: '|';'/';'-';'\'

NB. Show spinner in the status bar while waiting
NB. y = spinner frame index, returns next index
tui_spinner =: monad define
  frame =. > (y { SPINNER)
  if. win_status ~: 0 do.
    wbkgd_ncurses_ win_status , COLOR_PAIR_ncurses_ (theme_cp 'status')
    wclear_ncurses_ win_status
    wmove_ncurses_ win_status , 0 , 0
    waddnstr_ncurses_ win_status ; (' ' , frame , ' thinking...') ; TUI_COLS
    wrefresh_ncurses_ win_status
  end.
  (#SPINNER) | y + 1
)

NB. Restore the status bar after spinner
tui_spinner_clear =: monad define
  tui_draw_status ''
)

NB. Send payload to LLM, return parsed JSON response
NB. Uses async curl + spinner if TUI is active, else blocking
llm_call =: monad define
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set.'
    echo 'Set OPENROUTER_API_KEY or ANTHROPIC_API_KEY env var.'
    '' return.
  end.
  t0 =. 6!:1 ''
  if. 0 ~: 4!:0 <'win_output' do.
    if. win_output ~: 0 do.
      NB. TUI mode: async with spinner
      API_URL http_post_async y
      spin =. 0
      while. -. http_async_done '' do.
        spin =. tui_spinner spin
        6!:3 (0.15)                   NB. sleep 150ms between frames
      end.
      tui_spinner_clear ''
      raw =. http_async_read ''
    else.
      NB. plain mode: blocking
      raw =. API_URL http_post y
    end.
  else.
    NB. plain mode: blocking
    raw =. API_URL http_post y
  end.
  t1 =. 6!:1 ''
  elapsed =. t1 - t0
  echo '  [' , (}: ": 0.01 * <. 100 * elapsed) , 's]'
  parsed =. dec_json raw
  track_usage parsed
  parsed
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
      payload =. build_payload ''
      resp =. llm_call payload
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
