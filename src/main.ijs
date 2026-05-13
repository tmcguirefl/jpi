NB. J-PI Agent - Phase 1: Basic Setup and Echo Loop
NB. main.ijs

echo 'J-PI Agent initialized.'

NB. Simple interactive loop (simulated for now)
NB. In a real J session, use wd or user input mechanisms.
run_agent =: 3 : 0
  echo 'Agent loop started. Type "exit" to quit.'
  while. 1 do.
    input =: 1!:1 ] 1   NB. Read from stdin (keyboard)
    if. input -: 'exit' do. break. end.
    echo 'Echo: ', input
  end.
  echo 'Agent stopped.'
)

NB. Run the agent when this script is loaded
run_agent ''