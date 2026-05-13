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

echo 'http loaded.'
