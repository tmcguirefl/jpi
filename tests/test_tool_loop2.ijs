NB. Debug exec_tool input
load '../src/agent.ijs'

debug_exec =: monad define
  HISTORY =: HISTORY , < 'user' mk_msg 'list the files in the current directory'
  payload =. build_payload ''
  resp =. llm_call payload
  tc =. get_or_tool_calls resp
  item =. > {. tc
  'tc_id name args' =. parse_or_tool_call item
  echo 'tc_id: ' , tc_id
  echo 'name: ' , name
  echo 'args type: ' , ": 3!:0 args
  echo 'args shape: ' , ": $ args
  echo 'args rank: ' , ": $$ args
  echo 'args:'
  echo args
  echo ''
  echo 'Calling exec_tool with name ; < args'
  y =. name ; < args
  echo 'y shape: ' , ": $ y
  'n inp' =. y
  echo 'n: ' , n
  echo 'inp type: ' , ": 3!:0 inp
  echo 'inp shape: ' , ": $ inp
  echo 'inp rank: ' , ": $$ inp
  inp2 =. > inp
  echo 'after > inp type: ' , ": 3!:0 inp2
  echo 'after > inp shape: ' , ": $ inp2
  echo 'after > inp rank: ' , ": $$ inp2
)

debug_exec ''
