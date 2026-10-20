NB. Stream parser: JSON null content is not text, and tool-call
NB. fragments are reassembled into the message the tool loop parses.
NB. This J rejects one-line if. do. end. so checks are assert (a verb).
old =. 1!:43 ''
1!:44 '/Users/tomdevel/jdev/jpi/src'
load 'llm.ijs'
1!:44 old

esc =: monad define
  y rplc '\';'\\';'"';'\"'
)

feed =: monad define
  stream_handle_line 'data: ' , y
)

echo 'null content is dropped, real text is kept'
stream_reset ''
feed '{"choices":[{"delta":{"content":null}}]}'
feed '{"choices":[{"delta":{"content":"Hello"}}]}'
feed '{"choices":[{"delta":{"content":null}}]}'
feed '{"choices":[{"delta":{"content":" there"}}]}'
feed '{"choices":[{"delta":{},"finish_reason":"stop"}]}'
parsed =. dec_json stream_assemble ''
assert 'Hello there' -: LLM_FULL_RESPONSE
assert 'Hello there' -: get_or_content parsed
assert -. is_tool_call parsed
assert -. +./ 'json_null' E. LLM_FULL_RESPONSE
echo 'text stream passed'

echo 'null content with a split tool call is a write'
stream_reset ''
part1 =. '{"pa'
part2 =. 'th":"mva.ijs"}'
head =. '{"choices":[{"delta":{"content":null,"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"write","arguments":"'
feed head , (esc part1) , '"}}]},"finish_reason":null}]}'
feed '{"choices":[{"delta":{"content":null,"tool_calls":[{"index":0,"function":{"arguments":"' , (esc part2) , '"}}]}}]}'
feed '{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'
feed '[DONE]'
parsed =. dec_json stream_assemble ''
assert 0 = # LLM_FULL_RESPONSE
assert '' -: get_or_content parsed
assert is_tool_call parsed
calls =. get_or_tool_calls parsed
assert 1 = # calls
'tc_id name args' =. parse_or_tool_call > {. calls
assert 'call_1' -: tc_id
assert 'write' -: name
assert 'mva.ijs' -: > 'path' gethash_json args
assert -. +./ 'json_null' E. stream_assemble ''
echo 'tool stream passed'

echo 'All stream null tests passed.'
exit 0
