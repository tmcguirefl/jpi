NB. Debug tool call structure
load '../src/agent.ijs'

debug_tc =: monad define
  HISTORY =: HISTORY , < 'user' mk_msg 'list the files in the current directory'
  payload =. build_payload ''
  resp =. llm_call payload
  echo 'finish: ' , get_or_finish resp
  echo 'is_tool_call: ' , ": is_tool_call resp
  tc =. get_or_tool_calls resp
  echo 'tool_calls shape: ' , ": $ tc
  echo 'tool_calls type: ' , ": 3!:0 tc
  item =. > {. tc
  echo 'item 0 shape: ' , ": $ item
  echo 'item 0 type: ' , ": 3!:0 item
  echo 'item 0 rank: ' , ": $$ item
  NB. try gethash_json on it
  echo 'id: ' , ": > 'id' gethash_json item
  echo 'type: ' , ": > 'type' gethash_json item
  func =. > 'function' gethash_json item
  echo 'func shape: ' , ": $ func
  echo 'func type: ' , ": 3!:0 func
  echo 'func rank: ' , ": $$ func
  echo 'name: ' , > 'name' gethash_json func
  echo 'arguments: ' , > 'arguments' gethash_json func
  NB. now try parse_or_tool_call
  echo 'Calling parse_or_tool_call...'
  r =. parse_or_tool_call item
  echo 'result shape: ' , ": $ r
  echo r
)

debug_tc ''
