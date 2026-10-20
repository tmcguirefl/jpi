NB. Command Execution Tool
NB. run_cmd.ijs

load 'utils.ijs'

NB. Max output chars before truncation
MAX_OUTPUT =: 50000

NB. Default timeout in seconds
DEFAULT_TIMEOUT =: 30

NB. Whole seconds in 1..86400, or 0 when y is not usable.
NB. JSON numbers arrive as booleans, ints, or floats. A string is rejected.
timeout_secs =: monad define
  t =. y
  if. 32 = 3!:0 t do.
    if. 1 ~: # , t do. 0 return. end.
    t =. > t
  end.
  if. -. (3!:0 t) e. 1 4 8 do. 0 return. end.
  if. t ~: <. t do. 0 return. end.
  n =. <. t
  if. (n < 1) +. n > 86400 do. 0 return. end.
  n
)

NB. is_j_jconsole: check if path is J's jconsole (not Java's).
NB. Java's jconsole is a GUI app; J's jconsole evaluates J expressions.
NB. Validation: echo 'i. 3' | path should contain "0 1 2" in output.
NB. The alarm must outlast exec + J startup; 3s killed slow starts
NB. (SIGALRM survives exec into the jconsole image).
is_j_jconsole =: monad define
  try.
    out =. 2!:0 'echo ''i. 3'' | perl -e ''alarm 10; exec @ARGV'' ' , y , ' 2>/dev/null'
    '0 1 2' +./@E. out
  catch.
    0
  end.
)

NB. Resolve J's jconsole path at load time.
NB. Prefers $JBIN (set and validated by the launcher, which also
NB. sources the untracked local/env.sh), falls back to common paths.
NB. Validates each candidate to reject Java's jconsole (e.g. /usr/bin/jconsole).
NB. 2!:5 returns 0 (boolean) for unset vars, so we check type (2=literal).
NB. parse JBIN= from local/env.sh (bash-sourced by the launcher;
NB. J cannot source shell files, so read the KEY=VALUE lines).
NB. Closes the last Java-console hole: without this, direct
NB. invocations without the JBIN env fell back to PATH, where
NB. /usr/bin/jconsole is JAVA's console.
env_jbin =: monad define
  NB. local/env.sh sits at the repo root. Read attempts, in
  NB. order: JPI_SRC-relative (launcher), ../local (cwd=src,
  NB. covers direct loads), ./local (cwd=repo root). All guarded:
  NB. unset env (2!:5 -> 0 numeric) must not crash the concat.
  txt =. ''
  try.
    jpi_src =. > 2!:5 'JPI_SRC'
    if. 2 = 3!:0 jpi_src do.
      txt =. fread jpi_src , '/../local/env.sh'
    end.
  catch.
  end.
  if. 0 = # txt do.
    try.
      txt =. fread '../local/env.sh'
    catch.
      txt =. ''
    end.
  end.
  if. 0 = # txt do.
    try.
      txt =. fread 'local/env.sh'
    catch.
      txt =. ''
    end.
  end.
  if. (2 ~: 3!:0 txt) +. 0 = # txt do. '' return. end.
  for_l. <;._2 txt , (LF -. {: txt) # LF do.
    ln =. > l
    m =. 'export JBIN=' E. ln
    if. +./ m do.
      p =. (m i. 1) + # 'export JBIN='
      deb p }. ln return.
    end.
  end.
  ''
)

resolve_jbin =: monad define
  r =. > 2!:5 'JBIN'
  if. (2 = 3!:0 r) *. is_j_jconsole r do. r return. end.
  NB. machine-local override (local/env.sh) before generic paths
  e =. env_jbin ''
  if. (0 < # e) *. is_j_jconsole e do. e return. end.
  home =. > 2!:5 'HOME'
  NB. ijconsole before jconsole. A renamed J install must win over
  NB. Java's /usr/bin/jconsole, which is only tried last.
  candidates =. '/Applications/j9.8/bin/ijconsole' ; '/Applications/j9.8/bin/jconsole' ; '/usr/local/bin/ijconsole' ; '/usr/local/j9.8/bin/ijconsole' ; '/usr/local/j9.8/bin/jconsole' ; '/usr/local/bin/jconsole'
  if. 2 = 3!:0 home do.
    candidates =. ((home , '/j9.8/bin/ijconsole') ; (home , '/j9.8/bin/jconsole')) , candidates
  end.
  for_c. candidates do.
    if. is_j_jconsole > c do. > c return. end.
  end.
  for_w. 'ijconsole' ; 'jconsole' do.
    path =. ''
    try.
      path =. _1 }. 2!:0 'which ' , (> w) , ' 2>/dev/null'
    catch.
      path =. ''
    end.
    if. (0 < # path) *. is_j_jconsole path do. path return. end.
  end.
  NB. Last resort: return JBIN if it was set (even if validation failed)
  if. 2 = 3!:0 r do. r return. end.
  ''
)
JBIN_PATH =: resolve_jbin ''
echo 'run_cmd: JBIN_PATH=' , JBIN_PATH , > (0 = #JBIN_PATH) { '' ; '  WARNING: not found — jconsole calls will use PATH (may hit Java jconsole)'

NB. Directory that holds the gitignored jconsole and ijconsole links.
NB. Absolute, because tool shells run in the user's project directory.
repo_local =: monad define
  jpi_src =. > 2!:5 'JPI_SRC'
  if. (2 = 3!:0 jpi_src) *. 0 < # jpi_src do.
    jpi_src , '/../local' return.
  end.
  if. fexist '../local/env.example' do. '../local' return. end.
  if. fexist 'local/env.example' do. 'local' return. end.
  '../local'
)

NB. Symlink target of y, or '' when y is not a symlink.
NB. The if keeps a normal file from making 2!:0 signal.
link_text =: monad define
  try.
    out =. 2!:0 'if [ -L ' , (squote y) , ' ]; then readlink ' , (squote y) , '; fi'
  catch.
    '' return.
  end.
  if. 0 = # out do. '' return. end.
  if. LF = {: out do. out =. }: out end.
  out -. CR
)

NB. If y is a symlink inside the local directory x, follow it until
NB. the path leaves that directory. Linking local/jconsole to itself
NB. would remove the only pointer to J's binary.
unwrap_local =: dyad define
  abs =. x
  t =. y
  pref =. abs , '/'
  for_i. i. 5 do.
    if. -. pref -: ((# pref) {. t) do. t return. end.
    nxt =. link_text t
    if. 0 = # nxt do. t return. end.
    if. '/' ~: {. nxt do. nxt =. abs , '/' , nxt end.
    if. nxt -: t do. t return. end.
    t =. nxt
  end.
  t
)

NB. y = path of J's jconsole. Create local/jconsole and
NB. local/ijconsole when they are missing or point elsewhere.
NB. A real file at either path is left alone.
NB. Returns the absolute local directory, or ''.
ensure_j_links =: monad define
  target =. y
  if. 0 = # target do. '' return. end.
  dir =. repo_local ''
  2!:0 'mkdir -p ' , squote dir
  abs =. 2!:0 'cd ' , (squote dir) , ' && pwd'
  if. LF = {: abs do. abs =. }: abs end.
  abs =. abs -. CR
  if. 0 = # abs do. '' return. end.
  target =. abs unwrap_local target
  if. (abs , '/') -: ((1 + # abs) {. target) do.
    echo 'jpi: not linking local/ to itself'
    '' return.
  end.
  if. -. is_j_jconsole target do. '' return. end.
  for_name. 'jconsole' ; 'ijconsole' do.
    link =. abs , '/' , > name
    cur =. link_text link
    if. (fexist link) *. 0 = # cur do.
      echo 'jpi: ' , link , ' exists and is not a symlink; leaving it'
      continue.
    end.
    if. cur -: target do. continue. end.
    2!:0 'ln -sfn ' , (squote target) , ' ' , squote link
    echo 'jpi: linked ' , link , ' -> ' , target
  end.
  abs
)

NB. Top-level if. is a spelling error in this J. ensure_j_links
NB. returns '' when the path is empty, so the call is unconditional.
LOCAL_BIN =: ensure_j_links JBIN_PATH

NB. run_cmd: execute shell command with timeout and output truncation
NB. Redirects stderr to stdout so both are captured
NB. y = command string, or command;timeout (boxed)
run_cmd =: monad define
  args =. boxopen y
  cmd =. > 0 { args
  timeout =. DEFAULT_TIMEOUT
  if. 1 < #args do. timeout =. > 1 { args end.
  NB. alarm's argument is spliced into a single-quoted perl program.
  NB. A non-number (": of the string 1'; evil is 1'; evil) would
  NB. close that quote. Reject it before the shell sees it.
  secs =. timeout_secs timeout
  if. 0 = secs do.
    < 'ERROR: timeout must be a whole number of seconds' return.
  end.
  try.
    NB. wrap with stderr redirect; use perl for timeout (works on macOS)
    NB. local/ is first on PATH, so jconsole and ijconsole (and
    NB. command/env lookups) hit the symlinks, not Java's jconsole.
    NB. The functions cover the same names when PATH is ignored.
    NB. </dev/null keeps the command off the TUI's stdin.
    path_setup =. ''
    if. 0 < # LOCAL_BIN do.
      path_setup =. 'export PATH=' , (squote LOCAL_BIN) , ':"$PATH"; '
    end.
    shell_setup =. path_setup , 'jconsole() { ' , (squote JBIN_PATH) , ' "$@"; }; ijconsole() { ' , (squote JBIN_PATH) , ' "$@"; }; '
    full_cmd =. 'perl -e ''alarm ' , (": secs) , '; exec @ARGV'' sh -c ' , (dquote (shell_setup,cmd)) , ' </dev/null 2>&1'
    out =. 2!:0 full_cmd
    NB. truncate if too long. The full text stays in a file.
    if. MAX_OUTPUT < #out do.
      home =. > 2!:5 'HOME'
      dir =. home , '/.jpi/tool-out'
      try. 2!:0 'mkdir -p ' , squote dir catch. end.
      fn =. dir , '/out-' , (": <. 1e6 * 6!:1 '') , '.txt'
      out fwrite fn
      out =. (MAX_OUTPUT {. out) , LF , '[output truncated at ' , (human_size MAX_OUTPUT) , '; full text in ' , fn , ']'
    end.
    < out
  catch.
    < 'ERROR: command failed or timed out: ' , cmd
  end.
)

NB. run_cmd_str: returns raw string (empty on error)
NB. Explicit original:
NB.   run_cmd_str =: monad define
NB.     > run_cmd y
NB. )
run_cmd_str =: > @ run_cmd

NB. dquote: wrap in double quotes, escaping internal doubles and backslashes
dquote =: monad define
  escaped =. y rplc '\';'\\';'"';'\"';'$';'\$';'`';'\`'
  '"' , escaped , '"'
)

echo 'run_cmd loaded.'
