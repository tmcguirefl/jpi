NB. test_named_pipe.ijs
NB. Stream chunked HTTP output into J Native File operations via a FIFO Named Pipe
NB. This completely avoids disk-write buffering issues of standard tailing!

test_pipe_stream =: monad define
  smoutput 'Setting up FIFO Named Pipe...'
  2!:0 'rm -f /tmp/jpi_stream_pipe ; mkfifo /tmp/jpi_stream_pipe'

  smoutput 'Starting curl daemon in background via pipe...'
  NB. the & starts curl in the background. It will block until we open the pipe for reading
  2!:1 '( curl -N -s https://httpbin.org/stream/5 > /tmp/jpi_stream_pipe ) &'

  smoutput 'Opening FIFO on J side...'
  pipe =. 1!:21 <'/tmp/jpi_stream_pipe'  NB. Open pipe descriptor exclusively

  bytes_read =. 0
  chunks =. 0

  while. 1 do.
    NB. read 1000 bytes at a time
    NB. For a pipe (FIFO), 1!:11 with a chunk size will block until at least some bytes are available,
    NB. then it will return whatever is buffered, naturally giving us standard streaming tokens.
    try.
      chunk =. 1!:11 pipe ; 0 , 1000
    catchd.
      err =. 13!:12 ''
      smoutput 'Error: ', err
      break.
    end.

    if. 0 = #chunk do.
      break.  NB. EOF (curl finished)
    end.

    chunks =. >: chunks
    bytes_read =. bytes_read + #chunk
    
    smoutput ''
    smoutput '--- STREAM CHUNK ' , (":chunks) , ' (' , (":#chunk) , ' bytes) ---'
    smoutput chunk
  end.

  1!:22 pipe
  2!:0 'rm -f /tmp/jpi_stream_pipe'
  smoutput 'Done! Total bytes: ' , ": bytes_read
)

test_pipe_stream ''
