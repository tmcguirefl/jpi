NB. J-PI Agent - Main entry point
NB. main.ijs

load 'agent.ijs'

NB. Interactive loop: reads from stdin, dispatches to agent
run_agent =: monad define
  echo 'J-PI Agent ready. Type a command or "exit" to quit.'
  while. 1 do.
    input =. 1!:1 ] 1
    if. input -: 'exit' do. break. end.
    if. 0 = #input do. continue. end.
    agent input
  end.
  echo 'J-PI Agent stopped.'
)
