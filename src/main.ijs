NB. J-PI Agent - Main entry point
NB. main.ijs

load 'agent.ijs'

NB. Interactive loop
run_agent =: monad define
  echo ''
  echo 'J-PI Agent ready.'
  echo 'Commands: read <file> | run <cmd> | edit | write | ask <question> | clear | exit'
  echo ''
  while. 1 do.
    input =. 1!:1 ] 1
    if. input -: 'exit' do. break. end.
    if. 0 = #input do. continue. end.
    agent input
  end.
  echo 'J-PI Agent stopped.'
)
