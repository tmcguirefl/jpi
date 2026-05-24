NB. test_task_stream.ijs
NB. Testing if native spawn_jtask_ gives us chunked output or blocks

load 'task'

test_jtask =: monad define
  smoutput 'Starting spawn_jtask_ for streaming ...'
  started =. 6!:1 ''

  NB. Let's see if we can do something like host_cmd or spawn
  res =. spawn_jtask_ 'curl -N -s https://httpbin.org/stream/5'

  smoutput 'Done! Bytes received: ' , ": # res
  took =. (6!:1 '') - started
  smoutput 'Took ' , (":took) , ' seconds.'
)

test_jtask ''
