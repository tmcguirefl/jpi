NB. Fixed domain error in sleep
test_pipe2 =: monad define
  smoutput 'Starting curl background redirect to file...'
  2!:0 'rm -f /tmp/jdata.json'
  2!:0 'touch /tmp/jdata.json'
  
  NB. We wrap the curl command in a subshell and echo a DONE marker when it finishes
  2!:1 '( curl -N -s https://httpbin.org/stream/20 ; echo "[[STREAM_DONE]]" ) > /tmp/jdata.json &'

  started =. 6!:1 ''
  offset =. 0
  chunks =. 0
  
  while. 1 do.
    sz =. 1!:4 <'/tmp/jdata.json'
    if. sz > offset do.
      chunk =. 1!:11 ('/tmp/jdata.json' ; offset , sz - offset)
      offset =. sz
      
      NB. Check if curl finished by looking for our marker
      marker =. '[[STREAM_DONE]]'
      idx =. marker E. chunk
      done =. 1 e. idx
      
      if. done do.
        chunk =. (idx i. 1) {. chunk  NB. trim the marker out
      end.
      
      if. 0 < #chunk do.
        chunks =. >: chunks
        smoutput 'Chunk ' , (":chunks) , ': ', (": #chunk) , ' bytes'
        smoutput chunk
      end.
      
      if. done do. break. end.  NB. Exit immediately!
    end.
    
    6!:3 ] 0.1
    if. (6!:1 '') > started + 15 do. 
      smoutput 'Stream Timed Out!'
      break. 
    end.  NB. Safety timeout bumped up, just in case
  end.
  smoutput 'Done background file stream.'
)
test_pipe2 ''
