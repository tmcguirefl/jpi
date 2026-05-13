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
NB. Build tool JSON string: x = schema key, y = name;desc;params
mk_tool =: dyad define
  'n d p' =. y
  '{"name":"' , n , '","description":"' , d , '","' , x , '":' , p , '}'
)

NB. Build tools JSON array for the current provider
get_tools =: monad define
  defs =. ('read';'Read file contents';READ_PARAMS) ; ('bash';'Execute shell command';RUN_PARAMS) ; ('edit';'Edit file with find/replace';EDIT_PARAMS) ; ('write';'Write content to file';WRITE_PARAMS)
  select. PROVIDER
  case. 'openrouter' do.
    NB. OpenAI format: {type:function, function:{name,desc,parameters}}
    items =. > each 'parameters' mk_tool each defs
    items =. '{"type":"function","function":' , each items ,&.> < '}'
  case. 'anthropic' do.
    NB. Anthropic format: {name,desc,input_schema}
    items =. > each 'input_schema' mk_tool each defs
  end.
  NB. join with commas into a JSON array
  '[' , (_1 }. ; (,&',') each items) , ']'
)

NB. ----------------------------------------------------------------
NB. Escape a string for embedding in JSON
json_esc =: monad define
  y rplc '\';'\\';'"';'\"';LF;'\n';CR;'\r';TAB;'\t'
)

NB. Build the full request payload as a JSON string
NB. y = user message string
build_payload =: monad define
  tools =. get_tools ''
  msg =. '{"role":"user","content":"' , (json_esc y) , '"}'
  '{"model":"' , MODEL , '","max_tokens":4096,"tools":' , tools , ',"messages":[' , msg , ']}'
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
NB. Simple single-turn ask: y = question string
llm_ask =: monad define
  payload =. build_payload y
  resp =. llm_call payload
  if. 0 = #resp do. '' return. end.
  extract_reply resp
)

echo 'llm loaded. Provider: ' , PROVIDER
