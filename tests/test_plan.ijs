NB. Session CLI, paste classification, and mcp.json writer.
NB. Run from src/ with JPI_SESSION_DIR, JPI_IMAGE_DIR, JPI_MCP_FILE,
NB. and JPI_MCP_PROJECT all under /tmp. Does not load agent.ijs.

main =: monad define
  dir =. > 2!:5 'JPI_SESSION_DIR'
  if. -. '/tmp/' -: 5 {. dir , '     ' do.
    echo 'JPI_SESSION_DIR must be under /tmp'
    0 return.
  end.
  load 'session.ijs'

  base =. dir
  meta =. '{"type":"meta","name":"Shown","cwd":"/tmp/other","head":"e1"}'
  msg =. '{"id":"e1","parent":"","type":"message","body":"{\"role\":\"user\",\"content\":\"hi\"}"}'
  text =. meta , LF , msg , LF
  text fwrite base , '/alpha.jsonl'
  text fwrite base , '/alpine.jsonl'

  'p n' =. session_resolve 'alpha'
  assert n -: 'alpha'
  'p n' =. session_resolve 'alph'
  assert n -: 'alpha'
  assert 0 = # session_resolve 'al'
  assert 0 = # session_resolve 'missing'
  'p n' =. session_resolve base , '/alpha.jsonl'
  assert n -: 'alpha'

  assert 1 = session_cli_id 'freshid' ; 0
  assert CURRENT_SESSION -: 'freshid'
  assert -. fexist session_path 'freshid'
  SESSION_PERSIST =: 0
  save_session ''
  assert -. fexist session_path 'freshid'
  SESSION_PERSIST =: 1

  got =. session_cli_open (base , '/alpha.jsonl') ; 1 ; 1
  assert got = 1
  forked =. session_path folder_session ''
  assert fexist forked
  assert (1!:43 '') -: session_file_cwd forked
  echo 'session cli ok'

  load 'image.ijs'
  load 'editor.ijs'
  img =. (> 2!:5 'JPI_IMAGE_DIR') , '/dot.png'
  'x' fwrite img
  'ins att' =. accept_paste 'file://' , img
  assert +./ '[image:' E. ins
  assert +./ '[[jpi-image' E. att
  'ins att' =. accept_paste 'hello there'
  assert ins -: 'hello there'
  assert 0 = # att
  b64 =. 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  'ins att' =. accept_paste 'data:image/png;base64,' , b64
  assert +./ '[image:' E. ins
  p =. 8 }. ins
  if. ']' = {: p do. p =. }: p end.
  raw =. fread p
  assert 'PNG' -: 1 2 3 { raw
  echo 'paste ok'

  load 'mcp_cfg.ijs'
  project_trusted =: 0:
  'u p' =. mcp_load_paths ''
  assert 0 = # p
  assert u -: > 2!:5 'JPI_MCP_FILE'
  project_trusted =: 1:
  'u p' =. mcp_load_paths ''
  assert p -: > 2!:5 'JPI_MCP_PROJECT'

  path =. mcp_user_path ''
  assert 1 = mcp_cli_add path ; < ('demo';'--';'echo';'hi')
  mode =. 2!:0 'stat -f %Lp ' , squote path
  assert +./ '600' E. mode
  rows =. mcp_entries path
  assert 'demo' -: > (< 0, 0) { rows
  cfg =. > (< 0, 1) { rows
  assert 'stdio' -: > 'type' gethash_json cfg
  assert 'echo' -: > 'command' gethash_json cfg

  assert 1 = mcp_cli_add path ; < ('web';'--url';'http://127.0.0.1:9';'--bearer-env';'DEMO_TOKEN')
  tok =. > 2!:5 'DEMO_TOKEN'
  got =. mcp_expand_refs 'Bearer ${DEMO_TOKEN}'
  assert got -: 'Bearer ' , tok
  assert -. +./ tok E. fread path
  rows =. mcp_entries path
  found =. 0
  for_i. i. # rows do.
    if. 'web' -: > (< i, 0) { rows do.
      cfg =. > (< i, 1) { rows
      hdrs =. > 'headers' gethash_json cfg
      auth =. > 'Authorization' gethash_json hdrs
      assert +./ '${DEMO_TOKEN}' E. auth
      found =. 1
    end.
  end.
  assert found = 1

  NB. Read both servers through load_mcp_json without spawning.
  load 'plugins.ijs'
  SEEN_MCP =: 0 $ <''
  NB. One-line verbs: a nested definition would close main.
  load_mcp_stdio =: 3 : 'SEEN_MCP =: SEEN_MCP , < > {: y'
  load_mcp_http =: 3 : 'SEEN_MCP =: SEEN_MCP , < > {: y'
  dir =. (path i: '/') {. path
  load_mcp_json dir ; 'user'
  assert ('demo' ; 'web') -: SEEN_MCP
  quiet =. ('type';'command';'enabled') ,: 'stdio' ; 'echo' ; 0
  mcp_put path ; 'quiet' ; < quiet
  SEEN_MCP =: 0 $ <''
  load_mcp_json dir ; 'user'
  assert ('demo' ; 'web') -: SEEN_MCP
  mcp_drop path ; 'quiet'
  pp =. mcp_project_path ''
  assert 1 = mcp_cli_add pp ; < ('demo';'--';'echo';'there')
  SEEN_MCP =: 0 $ <''
  load_user_and_project_mcp ''
  assert ('web' ; 'demo') -: SEEN_MCP

  mcp_drop path ; 'demo'
  rows =. mcp_entries path
  assert 1 = # rows
  assert 'web' -: > (< 0, 0) { rows
  off =. ('type';'enabled') ,: 'stdio' ; 0
  assert 0 = mcp_is_enabled off
  offj =. ('type';'enabled') ,: 'stdio' ; 'json_false'
  assert 0 = mcp_is_enabled offj
  echo 'mcp cfg ok'

  NB. A saved yes must match fread text, and script load must
  NB. not treat JPI_SRC as the project the user opened.
  load 'utils.ijs'
  oldtf =. TRUSTED_FILE
  TRUSTED_FILE =: '/tmp/jpi-plan-trust'
  try. ferase TRUSTED_FILE catch. end.
  assert 0 = is_trusted '/tmp/proj'
  ('/tmp/proj' , LF) fappend TRUSTED_FILE
  assert 1 = is_trusted '/tmp/proj'
  assert 0 = is_trusted '/tmp/other'
  ferase TRUSTED_FILE
  TRUSTED_FILE =: oldtf
  LAUNCH_CWD =: '/tmp/jpitest'
  assert 1 = defer_project_scan ''
  assert 0 = project_trusted ''
  LAUNCH_CWD =: 1!:43 ''
  assert 0 = defer_project_scan ''
  echo 'trust ok'
  echo 'ALL TESTS PASSED'
)

main ''
