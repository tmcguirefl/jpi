NB. LLM integration (OpenRouter / Anthropic)
NB. llm.ijs

require 'convert/json'
load 'http.ijs'

NB. ----------------------------------------------------------------
NB. JSON schema strings for tool parameters
READ_SCHEMA  =: '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"limit":{"type":"number","description":"Max lines"}},"required":["path"]}'
RUN_SCHEMA   =: '{"type":"object","properties":{"command":{"type":"string","description":"Command to run"}},"required":["command"]}'
EDIT_SCHEMA  =: '{"type":"object","properties":{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}},"required":["path","old_text","new_text"]}'
WRITE_SCHEMA =: '{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}'

NB. ----------------------------------------------------------------
NB. Tool definitions for OpenRouter (OpenAI format)
NB. Each tool is a 2-row boxed table: row 0 = keys, row 1 = values
TOOLS_OPENROUTER =: monad define
  NB. function objects: name;description;parameters as 2-row tables
  read_f  =. ('name';'description';'parameters') ,: 'read';'Read file contents';(dec_json READ_SCHEMA)
  run_f   =. ('name';'description';'parameters') ,: 'bash';'Execute shell command';(dec_json RUN_SCHEMA)
  edit_f  =. ('name';'description';'parameters') ,: 'edit';'Edit file with find/replace';(dec_json EDIT_SCHEMA)
  write_f =. ('name';'description';'parameters') ,: 'write';'Write content to file';(dec_json WRITE_SCHEMA)
  NB. wrap each in {type:function, function:...}
  wrap =. monad : '(''type'';''function'') ,: ''function''; y'
  (wrap read_f) ; (wrap run_f) ; (wrap edit_f) ; (wrap write_f)
)

NB. Tool definitions for Anthropic format
TOOLS_ANTHROPIC =: monad define
  read_t  =. ('name';'description';'input_schema') ,: 'read';'Read file contents';(dec_json READ_SCHEMA)
  run_t   =. ('name';'description';'input_schema') ,: 'bash';'Execute shell command';(dec_json RUN_SCHEMA)
  edit_t  =. ('name';'description';'input_schema') ,: 'edit';'Edit file with find/replace';(dec_json EDIT_SCHEMA)
  write_t =. ('name';'description';'input_schema') ,: 'write';'Write content to file';(dec_json WRITE_SCHEMA)
  read_t ; run_t ; edit_t ; write_t
)

NB. ----------------------------------------------------------------
NB. Build payload based on provider
build_payload =: monad define
  NB. y = boxed list of message objects (2-row tables)
  select. PROVIDER
  case. 'openrouter' do. tools =. enc_json TOOLS_OPENROUTER ''
  case. 'anthropic'  do. tools =. enc_json TOOLS_ANTHROPIC ''
  end.
  msgs =. enc_json y
  '{"model":"' , MODEL , '","max_tokens":4096,"tools":' , tools , ',"messages":' , msgs , '}'
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
NB. Simple single-turn ask
llm_ask =: monad define
  NB. build a user message as 2-row table and send
  msg =. ('role';'content') ,: 'user'; y
  payload =. build_payload ,< msg
  resp =. llm_call payload
  if. 0 = #resp do. '' return. end.
  extract_reply resp
)

echo 'llm loaded. Provider: ' , PROVIDER
