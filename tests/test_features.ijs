NB. Tests for the session tree, streaming assembler, prompt
NB. templates, tool dispatch, and native xAI routing.
NB.
NB. Run from src/:
NB.   JPI_SESSION_DIR=/tmp/jpi-feat-sessions JPI_TOOLS='read,grep' \
NB.   jconsole < ../tests/test_features.ijs
NB.
NB. JPI_SESSION_DIR must be under /tmp. The script refuses to
NB. load session.ijs otherwise.

require 'convert/json'
load 'enc_json_fixed.ijs'
load 'config.ijs'

main =: monad define
  echo '=== provider routing ==='
  assert 'xai' -: infer_provider 'xai/grok-4'
  assert 'xai' -: infer_provider 'grok-4.7'
  assert 'openrouter' -: infer_provider 'x-ai/grok-4.7'
  assert 'grok-4.7' -: model_for_api 'xai/grok-4.7'
  assert 'grok-4.7' -: model_for_api 'grok-4.7'
  assert 'x-ai/grok-4.7' -: model_for_api 'x-ai/grok-4.7'
  assert 'XAI_API_KEY' -: provider_key_name 'xai'

  echo '=== providers file ==='
  CONFIG_PROVIDERS_FILE =: '/tmp/jpi_feat_providers'
  ferase CONFIG_PROVIDERS_FILE
  providers_put 'XAI_API_KEY' ; 'abc'
  raw =. ''
  if. fexist CONFIG_PROVIDERS_FILE do.
    raw =. fread CONFIG_PROVIDERS_FILE
  end.
  if. 2 ~: 3!:0 raw do. raw =. '' end.
  raw =. , raw -. CR , LF
  expect =. 'XAI_API_KEY=abc'
  assert (# expect) = # raw
  assert *./ expect = raw
  providers_drop 'XAI_API_KEY'
  raw =. ''
  if. fexist CONFIG_PROVIDERS_FILE do.
    raw =. fread CONFIG_PROVIDERS_FILE
    if. 2 ~: 3!:0 raw do. raw =. '' end.
    raw =. , raw -. CR , LF
  end.
  assert -. +./ 'XAI_API_KEY' E. raw
  ferase CONFIG_PROVIDERS_FILE

  echo '=== prompts ==='
  load 'prompts.ijs'
  one =. (<'hello') expand_template 'Say $1 and ${2:-fallback}.'
  assert *./ 'Say hello and fallback.' = one
  two =. ('hello' ; 'there') expand_template '${1:-fallback} ${2:-no}'
  assert *./ 'hello there' = two

  echo '=== stream ==='
  load 'llm.ijs'
  update_config_state 'xai/grok-4.7'
  assert 'xai' -: PROVIDER
  assert 'https://api.x.ai/v1/chat/completions' -: API_URL
  assert 131072 = context_limit ''
  assert 1 = tool_selected 'read'
  assert 1 = tool_selected 'grep'
  assert 0 = tool_selected 'bash'
  assert 0 = tool_selected 'find'

  stream_reset ''
  stream_consume 'data: {"choices":[{"delta":{"content":null}}]}' , LF
  stream_consume 'data: {"choices":[{"delta":{"content":"Hi"}}]}' , LF
  assert 'Hi' -: STREAM_TEXT
  assert -. +./ 'json_null' E. STREAM_TEXT

  stream_reset ''
  stream_consume 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1","function":{"name":"read","arguments":""}}]}}]}' , LF
  stream_consume 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"path\":\"a.ijs\"}"}}]}}]}' , LF
  assert 'read' -: > (< 0 , 1) { STREAM_TC
  assert +./ 'a.ijs' E. > (< 0 , 2) { STREAM_TC
  built =. stream_result_json ''
  assert +./ 'tool_calls' E. built
  assert -. +./ 'json_null' E. built

  echo '=== image marker ==='
  load 'image.ijs'
  msg =. '{"role":"tool","tool_call_id":"t1","content":"note' , LF , '[[jpi-image image/png]]' , LF , 'QUJD"}'
  out =. expand_image_msg msg
  assert +./ 'image_url' E. out
  assert +./ 'data:image/png;base64,QUJD' E. out
  'role blk' =. anth_blocks msg
  block =. > {. blk
  assert +./ '"type":"image"' E. block
  assert (+./ 'image/png' E. block) +. +./ 'image\/png' E. block

  echo '=== session tree ==='
  sd =. ''
  try. sd =. > 2!:5 'JPI_SESSION_DIR' catch. sd =. '' end.
  assert '/tmp/' -: 5 {. sd
  load 'session.ijs'
  assert sd -: SESSION_DIR
  session_reset_tree ''
  hist_append 'user' mk_msg 'one'
  hist_append 'assistant' mk_msg 'two'
  hist_append 'user' mk_msg 'three'
  assert 3 = # HISTORY
  assert 3 = # SESSION_ROWS
  hist_rewind 1
  assert 1 = # HISTORY
  assert 3 = # SESSION_ROWS
  session_reset_tree ''
  hist_append 'user' mk_msg 'one'
  hist_append 'assistant' mk_msg 'two'
  hist_append 'user' mk_msg 'three'
  2 hist_compact 'SUM'
  assert 2 = # HISTORY
  assert 4 = # SESSION_ROWS
  assert (< 'compaction') e. 2 {"1 SESSION_ROWS
  assert +./ '<summary>' E. > {. HISTORY
  assert +./ 'SUM' E. > {. HISTORY
  assert +./ 'three' E. > {: HISTORY
  CURRENT_SESSION =: 'featcheck'
  SESSION_LABEL =: ''
  session_set_label 'shown'
  load_session ''
  assert *./ 'shown' = SESSION_LABEL
  assert 2 = # HISTORY

  echo '=== grep ls find ==='
  load 'log.ijs'
  load 'run_cmd.ijs'
  load 'tool_exec.ijs'
  fn =. '/tmp/jpi-feat-sessions/needle.txt'
  ('alpha' , LF , 'feature-needle' , LF) fwrite fn
  obj =. 2 2 $ 'pattern' ; 'path' ; 'feature-needle' ; fn
  got =. exec_tool 'grep' ; < obj
  assert +./ 'feature-needle' E. got
  lsobj =. 2 1 $ 'path' ; '/tmp/jpi-feat-sessions'
  listed =. exec_ls lsobj
  assert +./ 'needle.txt' E. listed
  js =. '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":"","tool_calls":[{"id":"c1","type":"function","function":{"name":"ls","arguments":"{\"path\":\"/tmp/jpi-feat-sessions\"}"}}]}}]}'
  results =. process_tool_calls dec_json js
  assert +./ '[took ' E. > {. results
  ferase fn

  echo 'ALL TESTS PASSED'
)

main ''
