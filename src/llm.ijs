NB. LLM integration (Claude API)
NB. llm.ijs

load 'json_utils.ijs'
load 'http.ijs'

NB. ----------------------------------------------------------------
NB. Configuration
API_KEY =: ''                              NB. set before use
API_URL =: 'https://api.anthropic.com/v1/messages'
MODEL   =: 'claude-sonnet-4-20250514'

NB. ----------------------------------------------------------------
NB. Tool definitions as J data
TOOL_DEFS =: monad define
  read_t =. jmerge (jkv 'name';'read') ; (jkv 'description';'Read file contents') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string","description":"File path"},"limit":{"type":"number","description":"Max lines"}},"required":["path"]}')
  run_t =. jmerge (jkv 'name';'bash') ; (jkv 'description';'Execute shell command') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"command":{"type":"string","description":"Command to run"}},"required":["command"]}')
  edit_t =. jmerge (jkv 'name';'edit') ; (jkv 'description';'Edit file with find/replace') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}},"required":["path","old_text","new_text"]}')
  write_t =. jmerge (jkv 'name';'write') ; (jkv 'description';'Write content to file') ; (jkv 'input_schema' ; dec_json '{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}')
  read_t ; run_t ; edit_t ; write_t
)

NB. ----------------------------------------------------------------
NB. Build a message payload
build_payload =: monad define
  NB. y = boxed list of message pairs (role;content)
  msgs =. enc_json y
  tools =. enc_json TOOL_DEFS ''
  payload =. '{"model":"' , MODEL , '"'
  payload =. payload , ',"max_tokens":4096'
  payload =. payload , ',"tools":' , tools
  payload =. payload , ',"messages":' , msgs
  payload =. payload , '}'
)

NB. ----------------------------------------------------------------
NB. Send a prompt to the LLM, return parsed response
llm_call =: monad define
  NB. y = json payload string
  if. 0 = #API_KEY do.
    echo 'ERROR: API_KEY not set. Use: API_KEY =: ''sk-...'''
    '' return.
  end.
  raw =. API_URL http_post y
  dec_json raw
)

NB. ----------------------------------------------------------------
NB. Simple single-turn ask (convenience)
llm_ask =: monad define
  msg =. jmerge (jkv 'role';'user') ; (jkv 'content'; y)
  payload =. build_payload ,< msg
  llm_call payload
)

echo 'llm loaded.'
