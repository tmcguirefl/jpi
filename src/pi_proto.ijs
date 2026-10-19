NB. pi_proto.ijs - shared JSONL protocol for jpi's pipe/socket
NB. frontends (pi_rpc, pi_serve).
NB.
NB. Protocol: command objects in (one JSON per line), event
NB. objects out (one JSON per line). Loaded AFTER the agent
NB. stack (uses dec_json, gethash_json, agent, llm_ask).
NB. The HOST (rpc/serve) installs rpc_echo (the original
NB. stdout writer) and redefines echo to emit log events - the
NB. same trick the TUI uses - BEFORE loading this module.

NB. emit one JSONL event. Object shape for enc_json:
NB. 2x2 table, ROW 1 = keys, ROW 2 = values.
rpc_emit =: dyad define
  ev =. ('type' ; 'text') ,: x ; y
  rpc_echo enc_json ev
)

NB. Process one command line. Returns 1 to continue, 0 when
NB. the client asked to stop ({"cmd":"exit"}). ask runs the
NB. full agent loop; any agent /-command works (session, fork,
NB. context, status, help, ...). Malformed input is an error
NB. event, never a crash.
rpc_command =: monad define
  ln =. deb y
  if. 0 = # ln do. 1 return. end.
  try.
    js =. dec_json ln
    v =. 'cmd' gethash_json js
    if. _1 -: v do.
      'error' rpc_emit 'missing cmd field'
      1 return.
    end.
    cmd =. tolower > v
    if. cmd -: 'exit' do. 0 return. end.
    if. cmd -: 'ask' do.
      p =. 'prompt' gethash_json js
      if. _1 -: p do.
        'error' rpc_emit 'ask: missing prompt'
        1 return.
      end.
      reply =. llm_ask > p
      'reply' rpc_emit reply
    else.
      a =. 'arg' gethash_json js
      arg =. ''
      if. -. _1 -: a do. arg =. > a end.
      agent cmd , ' ' , arg
    end.
  catch.
    'error' rpc_emit 'command failed: ' , ln
  end.
  1
)

echo 'pi_proto loaded.'
