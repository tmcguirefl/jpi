NB. HTTP client via curl
NB. http.ijs

NB. Temp file for POST body (avoids shell quoting issues)
HTTP_TMPFILE =: jpath '~temp/jpi_post_body.json'

NB. http_post: send a POST request with JSON body
NB. x = url, y = json string body
NB. Writes body to temp file, uses curl -d @file to avoid shell escaping
http_post =: dyad define
  url =. x
  body =. y
  NB. write body to temp file
  body fwrite HTTP_TMPFILE
  cmd =. 'curl -s -X POST'
  cmd =. cmd , ' -H "Content-Type: application/json"'
  select. PROVIDER
  case. 'openrouter' do.
    cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"'
  case. 'anthropic' do.
    cmd =. cmd , ' -H "x-api-key: ' , API_KEY , '"'
    cmd =. cmd , ' -H "anthropic-version: 2023-06-01"'
  end.
  cmd =. cmd , ' -d @' , HTTP_TMPFILE
  cmd =. cmd , ' ' , url
  2!:0 cmd
)

NB. ================================================================
NB. Streaming POST — runs curl in background, writes to stream file
HTTP_STREAM_FILE =: jpath '~temp/jpi_stream.txt'
HTTP_STREAM_PID  =: jpath '~temp/jpi_stream.pid'

NB. Start a streaming POST request in background
NB. x = url, y = json body string
NB. Returns immediately. Output accumulates in HTTP_STREAM_FILE.
http_post_stream_start =: dyad define
  url =. x
  body =. y
  body fwrite HTTP_TMPFILE
  NB. clear stream file
  '' fwrite HTTP_STREAM_FILE
  cmd =. 'curl -s -N --no-buffer -X POST'
  cmd =. cmd , ' -H "Content-Type: application/json"'
  select. PROVIDER
  case. 'openrouter' do.
    cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"'
  case. 'anthropic' do.
    cmd =. cmd , ' -H "x-api-key: ' , API_KEY , '"'
    cmd =. cmd , ' -H "anthropic-version: 2023-06-01"'
  end.
  cmd =. cmd , ' -d @' , HTTP_TMPFILE
  cmd =. cmd , ' ' , url
  cmd =. cmd , ' > ' , HTTP_STREAM_FILE , ' &'
  cmd =. cmd , ' echo $! > ' , HTTP_STREAM_PID
  2!:0 cmd
)

NB. Check if the background curl is still running
http_stream_alive =: monad define
  try.
    pid =. _1 }. fread HTTP_STREAM_PID
    if. 0 = #pid do. 0 return. end.
    r =. 2!:0 'kill -0 ' , pid , ' 2>/dev/null && echo 1 || echo 0'
    '1' = {. r
  catch.
    0
  end.
)

NB. Read current contents of stream file
http_stream_read =: monad define
  try. fread HTTP_STREAM_FILE catch. '' end.
)

echo 'http loaded.'
