NB. J-PI Agent - Main entry point
NB. main.ijs

load 'agent.ijs'

NB. Interactive loop
run_agent =: monad define
  echo ''
  echo 'J-PI Agent ready.'
  echo 'Commands:'
  echo '  read <file>                  - read a file'
  echo '  run <cmd>                   - run a shell command'
  echo '  edit <file> <old> <new>     - find/replace in file'
  echo '  write <file> <content>      - write content to file'
  echo '  ask <question>              - ask the LLM (with tool use)'
  echo '  clear                       - reset conversation'
  echo '  export                      - save session to JSONL file'
  echo '  import                      - restore session from JSONL file'
  echo '  session [name]              - show/switch active session'
  echo '  model [name]                - show/switch model'
  echo '  compact [N]                 - force summarize oldest N messages'
  echo '  usage                       - show token usage'
  echo '  git [cmd]                   - git status or pass-through'
  echo '  grep <pattern> [path]       - search files for pattern'
  echo '  find <args>                 - find files'
  echo '  exit                        - quit'
  echo ''
  while. 1 do.
    input =. 1!:1 ] 1
    if. input -: 'exit' do. break. end.
    if. 0 = #input do. continue. end.
    agent input
  end.
  echo 'J-PI Agent stopped.'
)
