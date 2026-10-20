NB. JSON null content is empty text, and a direct Anthropic
NB. Messages response is normalized into the OpenAI shape the
NB. tool loop already reads. The old SSE streamer is gone.
NB. Run from src/:  jconsole < ../tests/test_stream_null.ijs
old =. 1!:43 ''
1!:44 '/Users/tomdevel/jdev/jpi/src'
load 'config.ijs'
load 'llm.ijs'
1!:44 old

NB. llm.ijs alone does not load extensions, mcp, or skills.
get_ext_tools_json =: monad define
  ''
)
get_mcp_tools_json =: monad define
  ''
)
get_system_prompt =: monad define
  'You are a test.'
)

main =: monad define
  echo 'null content is empty, not the text json_null'
  raw =. '{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":null}}]}'
  parsed =. dec_json raw
  assert '' -: get_or_content parsed
  assert -. is_tool_call parsed

  raw =. '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"write","arguments":"{\"path\":\"mva.ijs\"}"}}]}}]}'
  parsed =. dec_json raw
  assert '' -: get_or_content parsed
  assert is_tool_call parsed
  'tc_id name args_str args' =. parse_or_tool_call > {. get_or_tool_calls parsed
  assert 'call_1' -: tc_id
  assert 'write' -: name
  assert 'mva.ijs' -: > 'path' gethash_json args
  echo 'null content passed'

  echo 'anthropic tool_use becomes an OpenAI tool call'
  input =. (, < 'command') ,: < 'echo ok'
  blk_text =. ('type' ; 'text') ,: 'text' ; < 'hi'
  blk_tool =. ('type' ; 'id' ; 'name' ; 'input') ,: 'tool_use' ; 't1' ; 'bash' ; < input
  NB. ; on two tables row-stacks them. A JSON array is a boxed list.
  content =. (< blk_text) , < blk_tool
  resp =. ('id' ; 'type' ; 'role' ; 'content' ; 'stop_reason') ,: 'm1' ; 'message' ; 'assistant' ; (< content) ; < 'tool_use'
  norm =. normalize_anthropic resp
  assert is_tool_call norm
  assert 'hi' -: get_or_content norm
  'tc_id name args_str args' =. parse_or_tool_call > {. get_or_tool_calls norm
  assert 't1' -: tc_id
  assert 'bash' -: name
  assert 'echo ok' -: > 'command' gethash_json args
  echo 'normalize passed'

  echo 'anthropic payload lifts system and uses input_schema'
  PROVIDER =: 'anthropic'
  MODEL =: 'claude-sonnet-4'
  HISTORY =: , < 'user' mk_msg 'hi'
  fn =. ('name' ; 'arguments') ,: 'bash' ; < '{"command":"echo ok"}'
  tc =. ('id' ; 'type' ; 'function') ,: 't1' ; 'function' ; < fn
  asst =. ('role' ; 'content' ; 'tool_calls') ,: 'assistant' ; (< '') ; < , < tc
  HISTORY =: HISTORY , < enc_json_fixed asst
  HISTORY =: HISTORY , < mk_tool_result 't1' ; 'done'
  payload =. build_payload 0
  assert '"system":' +./@E. payload
  assert '"input_schema"' +./@E. payload
  assert '"max_tokens":4096' +./@E. payload
  assert -. '"role":"system"' +./@E. payload
  assert '"tool_use"' +./@E. payload
  assert '"tool_result"' +./@E. payload
  assert -. '"role":"tool"' +./@E. payload
  echo 'payload passed'

  echo 'end_turn with text has no tool call'
  blk =. ('type' ; 'text') ,: 'text' ; < 'just text'
  resp =. ('role' ; 'content' ; 'stop_reason') ,: 'assistant' ; (< , < blk) ; < 'end_turn'
  norm =. normalize_anthropic resp
  assert -. is_tool_call norm
  assert 'just text' -: get_or_content norm
  echo 'end_turn passed'
  ''
)

main ''
echo 'All null and anthropic tests passed.'
exit 0
