NB. pi_serve.ijs - jpi service mode: JSONL over a localhost TCP
NB. socket, the OpenCode-style shape (phase 1).
NB.
NB. usage (via launcher):  jpi serve
NB. direct:                jconsole pi_serve.ijs
NB. port:                  JPI_SERVE_PORT env (default 8765).
NB.
NB. The service owns the session(s); clients attach, send the
NB. SAME JSONL command protocol as `jpi rpc`, and detach without
NB. killing anything - the next client (or the same one tomorrow)
NB. attaches to the live session. PHASE 1 SCOPE: one client at a
NB. time (sequential accept); multi-client needs the sdselect
NB. fan-out (see addons/net/clientserver/jsss.ijs for the
NB. battle-tested pattern).
NB.
NB. Commands beyond the shared rpc set:
NB.   {"cmd":"sessions"}               list saved session names
NB.   {"cmd":"attach","arg":"name"}    switch session + replay its
NB.                                    messages as raw-JSONL 'history'
NB.                                    events, then an 'attached' event
NB. On connect the service emits a 'welcome' event (session, model,
NB. session count). {"cmd":"exit"} closes THAT CLIENT ONLY; the
NB. service keeps serving. Bind: localhost only, by design (the
NB. service owns shell execution and API keys - do not expose it
NB. off-machine).
NB.
NB. EMIT CHANNEL: the shared pi_proto verbs (rpc_command/rpc_emit)
NB. send their JSONL lines to rpc_echo. Serve installs rpc_echo =
NB. sock_emit_line, which routes to the attached client socket
NB. (global serve_sock), falling back to stdout when nobody is
NB. attached - so EVERY event the agent produces flows to the
NB. socket automatically, and startup chatter stays on stdout.

NB. Quiet through the loads: the socket carries ONLY JSONL.
serve_echo =: echo f.     NB. fixed value (a bare =: would alias)
echo =: ''"_

3 : 0 ''
  srcdir =: > 2!:5 'JPI_SRC'
  if. (2 ~: 3!:0 srcdir) +. 0 = # srcdir do.
    p =. > 1 { ARGV
    if. (# p) > p i: '/' do.
      srcdir =: (p i: '/') {. p
    else.
      srcdir =: 1!:43 ''  NB. relative script path: its dir is the cwd
    end.
  end.
  i. 0 0
)
old =. 1!:43 ''
LAUNCH_CWD =: old
1!:44 srcdir
load 'agent.ijs'
load 'lineio.ijs'
load 'pi_proto.ijs'
require 'socket'
coinsert <'jsocket'
1!:44 old
finish_project_scan ''

NB. init_session ran during the loads while chdir'd into srcdir
NB. (folder_session saw 'src'); re-init now that cwd is the
NB. user's folder, so the per-folder session is the right one.
init_session ''
load_session ''

NB. ----------------------------------------------------------------
NB. port + socket globals

SERVE_PORT =: 8765
3 : 0 ''
  v =. > 2!:5 'JPI_SERVE_PORT'
  if. (2 = 3!:0 v) *. 0 < # v do.
    n =. (". :: 0:) v
    if. (0 < # , n) *. 0 < n do. SERVE_PORT =: <. n end.
  end.
)
serve_sock =: 0
SRV_BUF =: ''
NB. MSG_NOSIGNAL on Linux sends: a client that detaches mid-event
NB. must kill the service with SIGPIPE. BSD lacks the flag (there
NB. it would need SO_NOSIGPIPE) - flag 0 is the current fallback.
SND_FLAGS =: (UNAME -: 'Linux') { 0 , 16384

NB. send raw text (no trailing LF in y; we add it) to socket x,
NB. looping over partial sends. Silent on a dead socket.
sock_send =: dyad define
  d =. y , LF
  while. 0 < # d do.
    r =. d sdsend x , SND_FLAGS
    n =. > 1 { r
    if. (n = 0) +. 0 = # , n do. '' return. end.
    d =. n }. d
  end.
  ''
)

NB. one JSONL line: to the attached client, or stdout when no
NB. client is attached. NOT f.-fixed: serve_sock must stay live.
sock_emit_line =: monad define
  if. 0 = serve_sock do.
    serve_echo y
  else.
    serve_sock sock_send y
  end.
  ''
)

NB. buffered line read from socket y. Result: status ; line
NB. (status 0 = EOF/reset, 1 = a line). Blocking socket: sdrecv
NB. waits for data. An empty line is status 1 with an empty line.
NB. sdrecv returns rc;data: rc is 0 on SUCCESS (even when the
NB. peer closed and the data is empty) and nonzero on error.
NB. So EOF/reset is judged from EMPTY DATA, never from rc.
sock_read_line =: monad define
  while. -. LF e. SRV_BUF do.
    r =. sdrecv y , 4096
    d =. > 1 { r
    if. 0 = # d do.
      0 ; '' return.
    end.
    SRV_BUF =: SRV_BUF , d
  end.
  pos =. SRV_BUF i. LF
  ln =. pos {. SRV_BUF
  SRV_BUF =: (pos + 1) }. SRV_BUF
  1 ; ln
)

NB. install the emit channel: everything the shared protocol and
NB. the agent print now flows to the attached client.
rpc_echo =: sock_emit_line
echo =: 'log'&rpc_emit

NB. ----------------------------------------------------------------
NB. serve-only commands

NB. boxed session names (no .jsonl suffix). Uses 1!:0 (boxed
NB. table, column 0 = names): the 'dir' verb renders a char
NB. table, which silently mangled the names.
serve_session_names =: monad define
  ensure_session_dir ''
  raw =. {."1 [ 1!:0 < SESSION_DIR , '/*.jsonl'
  _6 }. each raw
)

NB. Replay one stored line. Legacy files are one message per
NB. line. Tree files wrap the message in a row, and the meta
NB. line is not a message.
serve_replay_line =: monad define
  ln =. y
  if. 0 = # ln do. return. end.
  o =. ''
  try. o =. dec_json ln catch. end.
  if. 2 ~: #$ o do.
    'history' rpc_emit ln
    return.
  end.
  typ =. 'type' sj_text o
  if. 0 = # typ do.
    'history' rpc_emit ln
    return.
  end.
  if. typ -: 'meta' do. return. end.
  body =. 'body' sj_text o
  if. 0 = # body do. return. end.
  if. typ -: 'message' do.
    'history' rpc_emit body
    return.
  end.
  if. typ -: 'compaction' do.
    body =. '<summary>' , LF , body , LF , '</summary>'
  end.
  if. (typ -: 'compaction') +. typ -: 'note' do.
    'history' rpc_emit 'user' mk_msg body
  end.
  ''
)

serve_attach =: monad define
  name =. deb y
  if. 0 = # name do.
    'error' rpc_emit 'attach: missing session name'
    return.
  end.
  if. -. fexist session_path name do.
    'error' rpc_emit 'attach: no such session: ' , name
    return.
  end.
  switch_session name
  NB. switch_session loads HISTORY; replay the STORED lines so a
  NB. UI can render roles/content itself (raw JSONL, escaped).
  raw =. fread session_path CURRENT_SESSION
  if. 0 < # raw do.
    if. LF ~: {: raw do. raw =. raw , LF end.
    for_m. <;._2 raw do.
      serve_replay_line > m
    end.
  end.
  'attached' rpc_emit CURRENT_SESSION , ' (' , (": # HISTORY) , ' messages)'
)

NB. dispatch: serve-only commands first, then the shared rpc set.
NB. Returns 1 to keep the client, 0 to close it (exit).
serve_command =: monad define
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
    if. cmd -: 'sessions' do.
      'sessions' rpc_emit ; (,&LF) each (<'  ') ,each serve_session_names ''
      1 return.
    end.
    if. cmd -: 'attach' do.
      a =. 'arg' gethash_json js
      if. _1 -: a do.
        'error' rpc_emit 'attach: missing arg'
      else.
        serve_attach > a
      end.
      1 return.
    end.
    rpc_command ln
  catch.
    'error' rpc_emit 'command failed: ' , ln
    1
  end.
)

NB. ----------------------------------------------------------------
NB. Main loop: listen on localhost, one client at a time. A
NB. client disconnect (EOF or exit) saves the session and leaves
NB. the service running for the next client.
3 : 0 ''
  lsk =. {. > sdcheck sdsocket ''
  bound =. 0
  try.
    sdcheck sdbind lsk ; AF_INET ; '127.0.0.1' ; SERVE_PORT
    bound =. 1
  catch.
    serve_echo 'serve: bind 127.0.0.1 failed, falling back to all interfaces'
  end.
  if. 0 = bound do.
    sdcheck sdbind lsk ; AF_INET ; '' ; SERVE_PORT
  end.
  sdcheck sdlisten lsk , 1
  serve_echo 'jpi serve listening on 127.0.0.1:' , ": SERVE_PORT
  serve_echo 'session: ' , CURRENT_SESSION , '  model: ' , MODEL
  while. 1 do.
    serve_sock =: > sdcheck sdaccept lsk
    SRV_BUF =: ''
    'welcome' rpc_emit 'jpi serve | session ' , CURRENT_SESSION , ' | model ' , MODEL , ' | ' , (": # serve_session_names '') , ' saved sessions'
    while. 1 do.
      'st ln' =. sock_read_line serve_sock
      if. 0 = st do. break. end.
      if. 0 = serve_command ln do. break. end.
    end.
    if. 0 < # HISTORY do. save_session '' end.
    sdclose serve_sock
    serve_sock =: 0
    serve_echo 'client detached; serving continues'
  end.
  sdclose lsk
  i. 0 0 NB. final sentence must yield a noun
)
exit 0 NB. terminate: never fall into the REPL
