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

  echo '=== key source ==='
  oldp =. CONFIG_PROVIDERS_FILE
  CONFIG_PROVIDERS_FILE =: '/tmp/jpi-key-test'
  filek =. 'file-key-abcdefghijklmnopqrstuvwxyz'
  ('OPENROUTER_API_KEY=' , filek , LF) fwrite CONFIG_PROVIDERS_FILE
  load_model ''
  assert filek -: API_KEY
  ('OPENROUTER_API_KEY=' , filek) fwrite CONFIG_PROVIDERS_FILE
  load_model ''
  assert filek -: API_KEY
  ('OPENROUTER_API_KEY=' , filek , CR , LF) fwrite CONFIG_PROVIDERS_FILE
  load_model ''
  assert filek -: API_KEY
  if. 3 ~: 4!:0 <'build_header_config' do.
    load 'http.ijs'
  end.
  h =. build_header_config ''
  assert +./ ('Authorization: Bearer ' , filek) E. h
  'OPENROUTER_API_KEY=1' fwrite CONFIG_PROVIDERS_FILE
  load_model ''
  ek =. ''
  try. ek =. > 2!:5 'OPENROUTER_API_KEY' catch. ek =. '' end.
  if. (2 = 3!:0 ek) *. 1 < # ek do.
    assert ek -: API_KEY
    h =. build_header_config ''
    assert +./ 'Authorization' E. h
    assert -. +./ 'Bearer 1"' E. h
  else.
    assert 0 = # API_KEY
  end.
  ferase CONFIG_PROVIDERS_FILE
  CONFIG_PROVIDERS_FILE =: oldp
  load_model ''

  echo '=== trust walk ==='
  load 'utils.ijs'
  home =. > 2!:5 'HOME'
  assert 1 = trust_is_home home
  assert 0 = trust_is_home '/tmp'
  oldd =. DECLINED_FILE
  DECLINED_FILE =: '/tmp/jpi-trust-declined'
  try. ferase DECLINED_FILE catch. end.
  assert 0 = is_declined '/tmp/jpi-trust-tree/sub'
  ('/tmp/jpi-trust-tree/sub' , LF) fappend DECLINED_FILE
  assert 1 = is_declined '/tmp/jpi-trust-tree/sub'
  assert 0 = is_declined '/tmp/jpi-trust-tree'
  ferase DECLINED_FILE
  DECLINED_FILE =: oldd
  base =. '/tmp/jpi-trust-tree'
  sub =. base , '/sub'
  try. 1!:5 < base catch. end.
  try. 1!:5 < sub catch. end.
  oldcwd =. 1!:43 ''
  1!:44 sub
  ('x') fwrite sub , '/.git'
  assert 0 = project_trust_needed ''
  ferase sub , '/.git'
  ('hi') fwrite base , '/AGENTS.md'
  ('x') fwrite base , '/.git'
  assert 1 = project_trust_needed ''
  1!:44 oldcwd
  ferase sub , '/.git'
  ferase base , '/AGENTS.md'
  ferase base , '/.git'
  try. 1!:55 < sub catch. end.
  try. 1!:55 < base catch. end.

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
  oldcwd =. 1!:43 ''
  1!:44 '/tmp'
  built =. ''
  try. built =. stream_result_json '' catch. built =. 13!:12 '' end.
  1!:44 oldcwd
  assert +./ 'tool_calls' E. built
  assert -. +./ 'file name error' E. built
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

  echo '=== bad tool arguments ==='
  NB. A cut-off arguments string must come back as a tool result.
  NB. It must not run, and it must not kill the loop. The command
  NB. below would remove keep.txt if the fragment were executed.
  keep =. '/tmp/jpi-feat-sessions/keep.txt'
  'stay' fwrite keep
  bad =. '{"command":"rm /tmp/jpi-feat-sessions/keep.txt'
  js =. '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":"","tool_calls":[{"id":"call_del","type":"function","function":{"name":"bash","arguments":' , (enc_json_fixed bad) , '}}]}}]}'
  parsed =. dec_json js
  'tc_id name args_str args' =. parse_or_tool_call > {. get_or_tool_calls parsed
  assert 'call_del' -: tc_id
  assert _1 -: args
  results =. process_tool_calls parsed
  got =. > {. results
  assert +./ 'call_del' E. got
  assert +./ 'not valid JSON' E. got
  assert fexist keep
  ferase keep
  obj =. '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":"","tool_calls":[{"id":"call_obj","type":"function","function":{"name":"ls","arguments":{"path":"/tmp/jpi-feat-sessions"}}}]}}]}'
  results =. process_tool_calls dec_json obj
  got =. > {. results
  assert +./ 'call_obj' E. got
  assert +./ '[took ' E. got

  echo '=== menu window ==='
  raw =. fread 'tui.ijs'
  if. LF ~: {: raw do. raw =. raw , LF end.
  lines =. <;._2 raw
  start =. 0
  for_i. i. # lines do.
    if. 'fm_window =:' -: 12 {. > i { lines do. start =. i break. end.
  end.
  assert start > 0
  body =. ''
  for_i. start + i. 20 do.
    line =. > i { lines
    body =. body , line , LF
    if. (1 = # line) *. ')' = {. line do. break. end.
  end.
  0!:0 body
  assert 0 = fm_window 9 ; 0 ; 10
  assert 1 = fm_window 10 ; 0 ; 10
  assert 0 = fm_window 0 ; 1 ; 10
  assert 1 = fm_window 6 ; 0 ; 6
  assert 90 = fm_window 99 ; 80 ; 10
  NB. The old expression parks the window off the selection.
  assert _1 = 10 - 10 + 1

  echo '=== model pricing ==='
  load 'utils.ijs'
  arr =. dec_json '{"id":"grok-imagine-image","pricing":[{"quality":"standard","price":2}]}'
  assert 0 = # model_price_label 'pricing' gethash_json arr
  obj =. dec_json '{"id":"k","pricing":{"input_per_million":1.5,"output_per_million":2}}'
  lab =. model_price_label 'pricing' gethash_json obj
  assert +./ 'EUR/M in' E. lab
  assert +./ 'EUR/M out' E. lab
  assert 0 = # model_price_label _1

  echo 'ALL TESTS PASSED'
)

main ''
