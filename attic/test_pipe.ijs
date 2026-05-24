NB. Testing explicit pipe usage via Unix mkfifo/tail

test_pipe =: monad define
  smoutput 'Creating pipe...'
  2!:0 'rm -f /tmp/jpipe && mkfifo /tmp/jpipe'
  
  smoutput 'Starting curl in background...'
  NB. Run curl in background, redirecting output to the pipe
  2!:1 '( curl -N -s https://httpbin.org/stream/20 > /tmp/jpipe ) &'

  smoutput 'Reading from pipe asynchronously...'
  started =. 6!:1 ''
  
  NB. We can't block on J file reads without freezing the interpreter.
  NB. Fortunately, we can use non-blocking raw OS read, or just shell polling.
  
  chunks =. 0
  while. 1 do.
    NB. J's built in file read (1!:1) blocks if pipe is empty. 
    NB. But a shell read with a tiny timeout doesn't.
    chunk =. 2!:0 'dd if=/tmp/jpipe iflag=nonblock status=none 2>/dev/null'
    
    if. 0 < #chunk do.
      chunks =. >: chunks
      smoutput 'Chunk ' , (":chunks) , ': ', (": #chunk) , ' bytes'
      smoutput chunk
    end.
    
    6!:3 0.1
    if. (6!:1 '') > started + 5 do. break. end.  NB. timeout
  end.
)
test_pipe ''
