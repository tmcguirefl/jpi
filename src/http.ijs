NB. HTTP client via curl
NB. http.ijs

NB. http_post: send a POST request with JSON body
NB. x = url, y = json string body
NB. Returns response string
http_post =: dyad define
  url =. x
  body =. y
  cmd =. 'curl -s -X POST'
  cmd =. cmd , ' -H "Content-Type: application/json"'
  cmd =. cmd , ' -H "x-api-key: ' , API_KEY , '"'
  cmd =. cmd , ' -H "anthropic-version: 2023-06-01"'
  cmd =. cmd , ' -d ' , (quote body)
  cmd =. cmd , ' ' , url
  2!:0 cmd
)

NB. quote: wrap string in single quotes, escaping internal single quotes
quote =: monad define
  '''' , (y rplc '''' ; '''\\''''') , ''''
)

echo 'http loaded.'
