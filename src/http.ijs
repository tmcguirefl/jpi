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
  case. 'google' do.
    cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"'
  case. 'local' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'ollama' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'tcm' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'anthropic' do.
    cmd =. cmd , ' -H "x-api-key: ' , API_KEY , '"'
    cmd =. cmd , ' -H "anthropic-version: 2023-06-01"'
  end.
  cmd =. cmd , ' -d @' , HTTP_TMPFILE
  cmd =. cmd , ' ' , url
  2!:0 cmd
)

NB. ================================================================
NB. Async POST — runs curl in background, returns immediately
HTTP_RESPONSE_FILE =: jpath '~temp/jpi_response.json'
HTTP_DONE_FILE     =: jpath '~temp/jpi_done.flag'

NB. Start a POST request in background
NB. x = url, y = json body string
http_post_async =: dyad define
  url =. x
  body =. y
  body fwrite HTTP_TMPFILE
  NB. clear output files
  '' fwrite HTTP_RESPONSE_FILE
  ferase HTTP_DONE_FILE
  cmd =. 'curl -s -X POST'
  cmd =. cmd , ' -H "Content-Type: application/json"'
  select. PROVIDER
  case. 'openrouter' do.
    cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"'
  case. 'google' do.
    cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"'
  case. 'local' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'ollama' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'tcm' do.
    if. 0 < #API_KEY do. cmd =. cmd , ' -H "Authorization: Bearer ' , API_KEY , '"' end.
  case. 'anthropic' do.
    cmd =. cmd , ' -H "x-api-key: ' , API_KEY , '"'
    cmd =. cmd , ' -H "anthropic-version: 2023-06-01"'
  end.
  cmd =. cmd , ' -d @' , HTTP_TMPFILE
  cmd =. cmd , ' -o ' , HTTP_RESPONSE_FILE
  cmd =. cmd , ' ' , url
  NB. run in background, touch done flag when finished
  cmd =. '(' , cmd , ' ; touch ' , HTTP_DONE_FILE , ') &'
  2!:0 cmd
)

NB. Check if async request is done
http_async_done =: monad define
  fexist HTTP_DONE_FILE
)

NB. Read the async response
http_async_read =: monad define
  fread HTTP_RESPONSE_FILE
)

NB. Simple GET helper
http_get =: dyad define
  url =. x
  2!:0 'curl -s -H "Authorization: Bearer ' , API_KEY , '" ' , url
)
