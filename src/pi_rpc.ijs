NB. pi_rpc.ijs - interactive JSONL RPC mode
NB. pi_rpc.ijs
NB.
NB. usage (via launcher):  jpi rpc
NB. direct:                jconsole pi_rpc.ijs
NB.
NB. Protocol (INTERACTIVE): commands arrive one JSON object per
NB. line on stdin; events stream out as they are produced; the
NB. run ends at EOF or {"cmd":"exit"}. The peer may hold the
NB. pipe open as long as it likes - replies arrive while it does.
NB. Line reads use lineio.ijs (libc read(2) on fd 0, buffered in
NB. J): J has no other way to read piped stdin line-by-line.
NB.
NB. Commands, one JSON object per line:
NB.   {"cmd":"ask","prompt":"..."}        full agent loop; reply event
NB.   {"cmd":"session","arg":"name"}      switch session (autosaves)
NB.   {"cmd":"fork","arg":"name"}         fork current session
NB.   {"cmd":"clear"}                     start a fresh context
NB.   {"cmd":"model","arg":"provider/id"} change model
NB.   {"cmd":"exit"}                      stop the run
NB. Any TUI /-command name works; unknown names are echoed as errors.
NB.
NB. Events, one JSON object per line on stdout:
NB.   {"type":"log","text":"..."}     everything the TUI would print
NB.   {"type":"reply","text":"..."}   the reply to an ask
NB.   {"type":"error","text":"..."}   malformed or failed command
NB.   {"type":"bye"}                  end of run
NB.
NB. Sessions persist to ~/.jpi/sessions like the TUI (the active
NB. session is loaded at start, saved on session switch and at end).

NB. Quiet through the loads: stdout must carry ONLY JSONL.
NB. rpc_echo holds the original stdout writer; load chatter is
NB. swallowed; afterwards echo is redefined to emit log events -
NB. the same trick the TUI uses (tui_echo).
rpc_echo =: echo f.     NB. fixed value (a bare =: would alias)
echo =: ''"_

3 : 0 ''
  srcdir =: > 2!:5 'JPI_SRC'
  if. (2 ~: 3!:0 srcdir) +. 0 = # srcdir do.
    NB. direct jconsole invocation (no launcher): derive from this script's path
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
NB. chdir: agent.ijs and its siblings bare-load, which resolves
NB. against the cwd (same pattern as tui.ijs)
load 'agent.ijs'
load 'lineio.ijs'
load 'pi_proto.ijs'
1!:44 old
finish_project_scan ''
NB. init_session ran during the loads while chdir'd into srcdir
NB. (folder_session saw 'src'); re-init now that cwd is the
NB. user's folder, so the per-folder session is the right one.
init_session ''
load_session ''

NB. everything the agent prints becomes a log event
NB. BOND the left argument (&): a bare 'log' rpc_emit juxtaposition
NB. is a noun-verb fragment, not a verb (the manual's own rule)
echo =: 'log'&rpc_emit

NB. ----------------------------------------------------------------
NB. Main loop: one command per stdin line (lineio), stop on EOF/exit

3 : 0 ''
  while. 1 do.
    ln =. stdin_read_line ''
    if. 0 = # ln do. break. end.        NB. EOF
    if. 0 = rpc_command ln do. break. end.
  end.
  if. 0 < # HISTORY do. save_session '' end.
  echo =: rpc_echo
  'bye' rpc_emit ''
  i. 0 0 NB. final sentence must yield a noun: verb-valued assignments cannot end a define
)
exit 0 NB. terminate: do not let the REPL re-read consumed stdin
