NB. Command Execution Tool
NB. run_cmd.ijs

NB. Max output chars before truncation
MAX_OUTPUT =: 50000

NB. Default timeout in seconds
DEFAULT_TIMEOUT =: 30

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
    full_cmd =. 'perl -e ''alarm ' , (": timeout) , '; exec @ARGV'' sh -c ' , (dquote cmd) , ' 2>&1'
    out =. 2!:0 full_cmd
    NB. truncate if too long
    if. MAX_OUTPUT < #out do.
      out =. (MAX_OUTPUT {. out) , LF , '[output truncated at ' , (": MAX_OUTPUT) , ' chars]'
    end.
    < out
  catch.
    < 'ERROR: command failed or timed out: ' , cmd
  end.
)

NB. run_cmd_str: returns raw string (empty on error)
run_cmd_str =: monad define
  > run_cmd y
)

NB. dquote: wrap in double quotes, escaping internal doubles and backslashes
dquote =: monad define
  escaped =. y rplc '\';'\\';'"';'\"';'$';'\$';'`';'\`'
  '"' , escaped , '"'
)

echo 'run_cmd loaded.'
