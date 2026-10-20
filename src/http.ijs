NB. HTTP client via curl
NB. http.ijs

require 'utils.ijs'
NB.
NB. All requests capture curl's HTTP status code and stderr so that
NB. connection failures and non-2xx responses are reported to the caller
NB. instead of silently returning an empty string.
NB.
NB. Temp files: body avoids shell quoting, header config avoids
NB. exposing the API key in ps aux (curl -K reads from file, not args).
NB. HTTP_HEADERFILE is erased after each request — it contains the API
NB. key in plaintext and ~temp resolves to /tmp (world-readable).
NB.
NB. All temp names carry a per-process suffix (this jconsole's PID):
NB. concurrent jpi instances share ~temp, and with fixed names one
NB. instance overwrites another's in-flight request/response files
NB. (observed with a TUI session, a jllmbench run, and the test suite
NB. active at once). $PPID of the system() shell is this process's PID.
NB. Falls back to a random suffix if the PID cannot be determined.
NB. Control words are definition-body-only, so the fetch lives in a def.
http_tmp_suffix =: monad define
  try.
    '_' , _1 }. 2!:0 'echo $PPID'
  catch.
    '_' , ": ? 1e6
  end.
)
HTTP_TMP_SUFFIX =: http_tmp_suffix ''
HTTP_TMPFILE    =: jpath '~temp/jpi_post_body' , HTTP_TMP_SUFFIX , '.json'
HTTP_HEADERFILE =: jpath '~temp/jpi_headers' , HTTP_TMP_SUFFIX , '.conf'
HTTP_RESPONSE   =: jpath '~temp/jpi_response' , HTTP_TMP_SUFFIX , '.json'
HTTP_STDERR     =: jpath '~temp/jpi_curl_stderr' , HTTP_TMP_SUFFIX , '.txt'
HTTP_PID_FILE   =: jpath '~temp/jpi_curl_pid' , HTTP_TMP_SUFFIX , '.txt'

NB. ================================================================
NB. Auth header construction — table-driven, no per-provider select.
NB.
NB. Providers split into three groups:
NB.   bearer_always   — Bearer + key, always (key required)
NB.   bearer_optional — Bearer + key, only when key is non-empty
NB.   anthropic       — x-api-key + version header
NB.
NB. hyai was previously missing from the select block entirely,
NB. so requests to hostyourai.com went out with no auth header.
NB. The table-driven approach makes adding a provider a one-line change.
NB. Bearer-auth providers that always include the key
BEARER_ALWAYS =: <;._1 ' ' , 'openrouter google cohere mistral'
NB. Bearer-auth providers that include the key only when non-empty
BEARER_OPT =: <;._1 ' ' , 'local ollama tcm hyai'

NB. Build curl config file content with auth headers.
NB. Written to HTTP_HEADERFILE and passed via curl -K so the key
NB. never appears in the curl command line.
build_header_config =: monad define
  h =. 'header = "Content-Type: application/json"' , LF
  if. (< PROVIDER) e. BEARER_ALWAYS do.
    h , 'header = "Authorization: Bearer ' , API_KEY , '"' , LF
  elseif. (< PROVIDER) e. BEARER_OPT do.
    h , (0 < # API_KEY) # 'header = "Authorization: Bearer ' , API_KEY , '"' , LF
  elseif. PROVIDER -: 'anthropic' do.
    h , 'header = "x-api-key: ' , API_KEY , '"' , LF , 'header = "anthropic-version: 2023-06-01"' , LF
  elseif. do. h end.
)

NB. ================================================================
NB. Run curl, capturing HTTP status code and stderr separately.
NB. x = base curl command (without url), y = url
NB. Returns: http_code string ; response body
NB. On failure, http_code is '000' and stderr is in HTTP_STDERR.
NB.
NB. J's 2!:0 raises an error when the command exits non-zero, so
NB. we catch it and treat it as a connection failure (code '000').
NB. curl still writes the response file and stderr before exiting.
curl_run =: dyad define
  cmd =. x , ' -o ' , HTTP_RESPONSE , ' -w ''%{http_code}'''
  cmd =. cmd , ' ' , y , ' 2>' , HTTP_STDERR
  try.
    code =. 2!:0 cmd
  catch.
    code =. '000'
  end.
  body =. ''
  if. fexist HTTP_RESPONSE do. body =. fread HTTP_RESPONSE end.
  code ; body
)

NB. Check http_code and return body or error.
NB. x = http_code string, y = response body
NB. Returns: body on success, 'ERROR: ...' on failure.
curl_result =: dyad define
  if. x -: '000' do.
    err =. ''
    if. fexist HTTP_STDERR do. err =. fread HTTP_STDERR end.
    if. 0 = # err do. err =. 'curl connection failed' end.
    'ERROR: ' , err return.
  end.
  if. '2' ~: {. x do.
    err =. ''
    if. fexist HTTP_STDERR do. err =. fread HTTP_STDERR end.
    if. 0 = # err do. err =. y end.
    'ERROR: HTTP ' , x , ': ' , err return.
  end.
  y
)

NB. http_post: send a POST request with JSON body
NB. x = url, y = json string body
NB. Writes body and headers to temp files, uses curl -K and -d @file
NB. to avoid shell escaping and key exposure in process args.
http_post =: dyad define
  url =. x
  body =. y
  body fwrite HTTP_TMPFILE
  (build_header_config '') fwrite HTTP_HEADERFILE
  base =. 'curl -s -X POST -K ' , HTTP_HEADERFILE , ' -d @' , HTTP_TMPFILE
  'code res' =. base curl_run url
  ferase HTTP_HEADERFILE
  code curl_result res
)

NB. ================================================================
NB. Async POST — runs curl in background, returns immediately
NB. Used by llm_call when TUI is active, so a spinner can animate
NB. while waiting for the response.
HTTP_RESPONSE_FILE =: HTTP_RESPONSE
HTTP_DONE_FILE     =: jpath '~temp/jpi_done' , HTTP_TMP_SUFFIX , '.flag'
HTTP_CODE_FILE     =: jpath '~temp/jpi_http_code' , HTTP_TMP_SUFFIX , '.txt'

NB. Start a POST request in background
NB. x = url, y = json body string
NB. Writes response body to HTTP_RESPONSE_FILE, HTTP status code to
NB. HTTP_CODE_FILE, stderr to HTTP_STDERR, and touches HTTP_DONE_FILE
NB. when complete.
http_post_async =: dyad define
  url =. x
  body =. y
  body fwrite HTTP_TMPFILE
  (build_header_config '') fwrite HTTP_HEADERFILE
  NB. clear output files
  '' fwrite HTTP_RESPONSE_FILE
  '' fwrite HTTP_CODE_FILE
  ferase HTTP_DONE_FILE
  ferase HTTP_PID_FILE
  NB. -N flushes each SSE chunk. A proxy that ignores stream
  NB. still writes one JSON body, and the caller falls back to it.
  cmd =. 'curl -s -N -X POST -K ' , HTTP_HEADERFILE
  cmd =. cmd , ' -d @' , HTTP_TMPFILE
  cmd =. cmd , ' -o ' , HTTP_RESPONSE_FILE
  cmd =. cmd , ' -w ''%{http_code}''' , ' > ' , HTTP_CODE_FILE , ' 2>' , HTTP_STDERR
  cmd =. cmd , ' ' , url
  NB. set -m gives the background subshell its own process group,
  NB. so Esc can kill curl and the touch together. echo $! is the
  NB. group leader. </dev/null keeps curl off the TUI's stdin.
  script =. 'set -m; (' , cmd , ' ; touch ' , (squote HTTP_DONE_FILE) , ') </dev/null & echo $!'
  pid =. ''
  try.
    pid =. 2!:0 script
  catch.
    pid =. ''
  end.
  pid =. deb pid -. CR , LF
  if. (0 < # pid) *. -. 0 e. pid e. '0123456789' do.
    pid fwrite HTTP_PID_FILE
  end.
)

NB. Kill the in-flight curl, if its pid file is still there.
NB. A late touch of the done flag would be read as the next reply.
http_async_cancel =: monad define
  pid =. ''
  try.
    pid =. fread HTTP_PID_FILE
  catch.
    pid =. ''
  end.
  pid =. deb pid -. CR , LF
  if. (0 < # pid) *. -. 0 e. pid e. '0123456789' do.
    try.
      2!:0 'kill -TERM -' , pid , ' 2>/dev/null || kill -TERM ' , pid , ' 2>/dev/null || true'
    catch.
    end.
  end.
  ferase HTTP_PID_FILE
  ferase HTTP_DONE_FILE
  '' fwrite HTTP_RESPONSE_FILE
  ''
)

NB. Check if async request is done
NB. Explicit original:
NB.   http_async_done =: monad define
NB.     fexist HTTP_DONE_FILE
NB. )
http_async_done =: fexist @ (HTTP_DONE_FILE"_)

NB. Read the async response
NB. Tacit original:
NB.   http_async_read =: fread @ (HTTP_RESPONSE_FILE"_)
http_async_read =: monad define
  ferase HTTP_HEADERFILE
  fread HTTP_RESPONSE_FILE
)

NB. Read the async response with error checking.
NB. Returns response body on success, 'ERROR: ...' on failure.
NB. Mirrors curl_result logic for the async path.
http_async_result =: monad define
  code =. ''
  if. fexist HTTP_CODE_FILE do. code =. fread HTTP_CODE_FILE end.
  body =. ''
  if. fexist HTTP_RESPONSE_FILE do. body =. fread HTTP_RESPONSE_FILE end.
  ferase HTTP_HEADERFILE
  if. code -: '000' do.
    err =. ''
    if. fexist HTTP_STDERR do. err =. fread HTTP_STDERR end.
    if. 0 = # err do. err =. 'curl connection failed' end.
    'ERROR: ' , err return.
  end.
  if. '2' ~: {. code do.
    err =. ''
    if. fexist HTTP_STDERR do. err =. fread HTTP_STDERR end.
    if. 0 = # err do. err =. body end.
    'ERROR: HTTP ' , code , ': ' , err return.
  end.
  body
)

NB. Simple GET helper
NB. x = url
http_get =: dyad define
  url =. x
  (build_header_config '') fwrite HTTP_HEADERFILE
  base =. 'curl -s -K ' , HTTP_HEADERFILE
  'code res' =. base curl_run url
  ferase HTTP_HEADERFILE
  code curl_result res
)
