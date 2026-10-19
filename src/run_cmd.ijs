NB. Command Execution Tool
NB. run_cmd.ijs

load 'utils.ijs'

NB. Max output chars before truncation
MAX_OUTPUT =: 50000

NB. Default timeout in seconds
DEFAULT_TIMEOUT =: 30

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
  candidates =. '/Applications/j9.8/bin/jconsole' ; '/usr/local/bin/jconsole' ; '/usr/local/j9.8/bin/jconsole'
  if. 2 = 3!:0 home do.
    candidates =. (< home , '/j9.8/bin/jconsole') , candidates
  end.
  for_c. candidates do.
    if. is_j_jconsole > c do. > c return. end.
  end.
  NB. Last resort: return JBIN if it was set (even if validation failed)
  if. 2 = 3!:0 r do. r return. end.
  ''
)
JBIN_PATH =: resolve_jbin ''
echo 'run_cmd: JBIN_PATH=' , JBIN_PATH , > (0 = #JBIN_PATH) { '' ; '  WARNING: not found — jconsole calls will use PATH (may hit Java jconsole)'

NB. squote: wrap in single quotes for shell, escaping internal single quotes
NB. Shell idiom: ' → '\'' (close quote, escaped quote, reopen quote)
SQ =: ''''
BS =: '\'
squote_repl =: SQ , BS , SQ , SQ
squote =: monad define
  escaped =. y rplc SQ ; squote_repl
  SQ , escaped , SQ
)

NB. run_cmd: execute shell command with timeout and output truncation
NB. Redirects stderr to stdout so both are captured
NB. y = command string, or command;timeout (boxed)
run_cmd =: monad define
  args =. boxopen y
  cmd =. > 0 { args
  timeout =. DEFAULT_TIMEOUT
  if. 1 < #args do. timeout =. > 1 { args end.
  try.
    NB. wrap with stderr redirect; use perl for timeout (works on macOS)
    NB. inject a jconsole function that calls J's jconsole (not Java's).
    NB. The path is inlined from JBIN_PATH, resolved at load time.
    NB. </dev/null keeps the command off the TUI's stdin.
    shell_setup =. 'jconsole() { ' , (squote JBIN_PATH) , ' "$@"; }; '
    full_cmd =. 'perl -e ''alarm ' , (": timeout) , '; exec @ARGV'' sh -c ' , (dquote (shell_setup,cmd)) , ' </dev/null 2>&1'
    out =. 2!:0 full_cmd
    NB. truncate if too long
    if. MAX_OUTPUT < #out do.
      out =. (MAX_OUTPUT {. out) , LF , '[output truncated at ' , human_size MAX_OUTPUT , ']'
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
