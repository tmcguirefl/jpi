NB. LLM integration (OpenRouter / Anthropic)
NB. llm.ijs

load 'json_utils.ijs'
load 'http.ijs'

NB. ----------------------------------------------------------------
NB. Tool definitions for OpenRouter (OpenAI format)
TOOLS_OPENROUTER =: monad define
  mk =. monad : 'jmerge (jkv ''type'';''function'') ; (jkv ''function''; y)'
  read_f =. jmerge (jkv 'name';'read') ; (jkv 'description';'Read file contents') ; (jkv 'parameters' ; dec_json '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"limit":{"type":"number","description":"Max lines"}},"required":["path"]}')
  run_f =. jmerge (jkv 'name';'bash') ; (jkv 'description';'Execute shell command') ; (jkv 'parameters' ; dec_json '{"type":"object","properties":{"command":{"type":"string","description":"Command to run"}},"required":["command"]}')
  edit_f =. jmerge (jkv 'name';'edit') ; (jkv 'description';'Edit file with find/replace') ; (jkv 'parameters' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}},"required":["path","old_text","new_text"]}')
  write_f =. jmerge (jkv 'name';'write') ; (jkv 'description';'Write content to file') ; (jkv 'parameters' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}')
  (mk read_f) ; (mk run_f) ; (mk edit_f) ; (mk write_f)
)

NB. Tool definitions for Anthropic format
TOOLS_ANTHROPIC =: monad define
  read_t =. jmerge (jkv 'name';'read') ; (jkv 'description';'Read file contents') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"limit":{"type":"number","description":"Max lines"}},"required":["path"]}')
  run_t =. jmerge (jkv 'name';'bash') ; (jkv 'description';'Execute shell command') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"command":{"type":"string","description":"Command to run"}},"required":["command"]}')
  edit_t =. jmerge (jkv 'name';'edit') ; (jkv 'description';'Edit file with find/replace') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}},"required":["path","old_text","new_text"]}')
  write_t =. jmerge (jkv 'name';'write') ; (jkv 'description';'Write content to file') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}')
  read_t ; run_t ; edit_t ; write_t
)

NB. ----------------------------------------------------------------
NB. Build payload based on provider
build_payload =: monad define
  NB. y = boxed list of message objects
  msgs =. enc_json y
  select. PROVIDER
  case. 'openrouter' do.
    tools =. enc_json TOOLS_OPENROUTER ''
    payload =. '{"model":"' , MODEL , '"'
    payload =. payload , ',"max_tokens":4096'
    payload =. payload , ',"tools":' , tools
    payload =. payload , ',"messages":' , msgs
    payload =. payload , '}'
  case. 'anthropic' do.
    tools =. enc_json TOOLS_ANTHROPIC ''
    payload =. '{"model":"' , MODEL , '"'
    payload =. payload , ',"max_tokens":4096'
    payload =. payload , ',"tools":' , tools
    payload =. payload , ',"messages":' , msgs
    payload =. payload , '}'
  end.
)

NB. ----------------------------------------------------------------
NB. Send prompt, return parsed response
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
NB. Extract text content from response (provider-aware)
extract_reply =: monad define
  NB. y = parsed JSON response
  select. PROVIDER
  case. 'openrouter' do.
    NB. OpenAI format: choices[0].message.content
    choices =. > 'choices' gethash_json y
    msg =. > {. choices
    > 'content' gethash_json > 'message' gethash_json msg
  case. 'anthropic' do.
    NB. Anthropic format: content[0].text
    content =. > 'content' gethash_json y
    first =. > {. content
    > 'text' gethash_json first
  end.
)

NB. ----------------------------------------------------------------
NB. Simple single-turn ask
llm_ask =: monad define
  msg =. jmerge (jkv 'role';'user') ; (jkv 'content'; y)
  payload =. build_payload ,< msg
  resp =. llm_call payload
  if. 0 = #resp do. '' return. end.
  extract_reply resp
)

echo 'llm loaded. Provider: ' , PROVIDER
