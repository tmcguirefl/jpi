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
  NB. each def boxed separately with < so they don't flatten
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
  NB. drop leading comma, wrap in array brackets
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

NB. Reset conversation
clear_history =: monad define
  HISTORY =: 0 $ <''
  echo 'Conversation cleared.'
)

NB. Build a JSON message string for a role/content pair
mk_msg =: dyad define
  NB. x = role, y = content
  '{"role":"' , x , '","content":"' , (json_esc y) , '"}'
)

NB. Build the full request payload from conversation history
NB. y is ignored (history is in HISTORY)
build_payload =: monad define
  tools =. get_tools ''
  NB. join all messages in HISTORY with commas
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
NB. Extract text content from parsed response (provider-aware)
extract_reply =: monad define
  NB. check for API error response
  if. _1 -.@-: 'error' gethash_json y do.
    err =. > 'error' gethash_json y
    msg =. > 'message' gethash_json err
    echo 'API error: ' , msg
    '' return.
  end.
  select. PROVIDER
  case. 'openrouter' do.
    NB. OpenAI format: choices[0].message.content
    choices =. > 'choices' gethash_json y
    msg =. > {. choices
    > 'content' gethash_json > 'message' gethash_json msg
  case. 'anthropic' do.
    NB. Anthropic format: content[0].text
    content =. > 'content' gethash_json y
    > 'text' gethash_json > {. content
  end.
)

NB. ----------------------------------------------------------------
NB. Multi-turn ask: y = question string
NB. Appends user message to history, sends full history, appends reply
llm_ask =: monad define
  NB. add user message to history
  HISTORY =: HISTORY , < 'user' mk_msg y
  NB. send full conversation
  payload =. build_payload ''
  resp =. llm_call payload
  if. 0 = #resp do. '' return. end.
  reply =. extract_reply resp
  NB. add assistant reply to history
  if. 0 < #reply do.
    HISTORY =: HISTORY , < 'assistant' mk_msg reply
  end.
  reply
)

echo 'llm loaded. Provider: ' , PROVIDER
