NB. pi_print.ijs - one-shot print mode
NB. pi_print.ijs
NB.
NB. usage (via launcher):  jpi -p your prompt here
NB. direct:                jconsole pi_print.ijs your prompt here
NB.
NB. Runs ONE ask through the full agent loop (system prompt, j
NB. tool, MCP connectors - everything except the TUI) and prints
NB. ONLY the reply on stdout. Load chatter and tool traces are
NB. suppressed (echo is the single stdout chokepoint in jpi; the
NB. TUI redefines it, headless modes may too). Context is fresh:
NB. print mode neither loads nor saves a session. Use rpc mode
NB. (pi_rpc.ijs) to drive a session.

pi_out =: echo f.               NB. fixed value (a bare =: would alias)
echo =: ''"_                  NB. quiet until the reply

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
1!:44 srcdir
NB. chdir: agent.ijs and its siblings bare-load, which resolves
NB. against the cwd (same pattern as tui.ijs)
load 'agent.ijs'
1!:44 old
NB. init_session ran during the loads while chdir'd into srcdir
NB. (folder_session saw 'src'); re-init now that cwd is the
NB. user's folder, so the per-folder session is the right one.
init_session ''
load_session ''

3 : 0 ''
  args =. 2 }. ARGV
  if. 0 = # args do.
    echo =: pi_out
    echo 'usage: jpi -p "prompt"'
    i. 0 0 return.
  end.
  NB. join argv words into one prompt, trim
  prompt =. deb ; ' ' ,&.> args
  reply =. llm_ask prompt
  echo =: pi_out
  pi_out reply
)
exit 0
