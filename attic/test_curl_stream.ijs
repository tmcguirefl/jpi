NB. test_curl_stream.ijs
NB. Standalone test script for real-time streaming via libcurl FFI

load '/Users/tomdevel/j9.7/addons/api/curl/curl.ijs'
coinsert 'jcurl'

test_curl_stream =: monad define 
  test_url =: 'https://httpbin.org/stream/20'

  smoutput LF , '=== Real-time libcurl streaming test ==='
  smoutput 'URL: ' , test_url

  h =. curl_easy_init ''
  if. h = 0 do.
    smoutput 'Failed to init curl handle'
    return.
  end.

  NB. Set URL
  if. CURLE_OK ~: curl_easy_setopt_str h ; CURLOPT_URL ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; test_url do.
    smoutput 'setopt URL failed'
    curl_easy_cleanup h
    return.
  end.

  NB. CONNECT_ONLY
  if. CURLE_OK ~: curl_easy_setopt h ; CURLOPT_CONNECT_ONLY ; 1 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 do.
    smoutput 'setopt CONNECT_ONLY failed'
    curl_easy_cleanup h
    return.
  end.

  smoutput 'Performing connect-only...'
  rc =. curl_easy_perform h
  if. rc ~: CURLE_OK do.
    smoutput 'perform failed: ' , >{: curl_easy_strerror rc
    curl_easy_cleanup h
    return.
  end.

  smoutput 'Connected. Sending HTTP GET request...'
  CRLF =. (13{a.),(10{a.)
  req  =. 'GET /stream/20 HTTP/1.1' , CRLF , 'Host: httpbin.org' , CRLF , 'Accept: */*' , CRLF , 'Connection: close' , CRLF , CRLF
  
  req_addr =. mema #req
  (req) memw req_addr, 0, (#req), 2
  nsent =. ,0
  rc =. curl_easy_send h ; req_addr ; (#req) ; nsent ; 0 ; 0 ; 0 ; 0 ; 0
  memf req_addr
  
  if. rc ~: CURLE_OK do.
    smoutput 'send failed with code: ' , ": rc
  end.

  smoutput 'Entering recv loop (chunk-by-chunk)...'

  maxbuf  =. 65536
  chunks  =. 0
  bytes   =. 0
  started =. 6!:1 ''

  buf_addr =. mema maxbuf

  while. 1 do.
    nread =. ,0
    rc    =. curl_easy_recv h ; buf_addr ; maxbuf ; nread
    select. rc
    case. CURLE_OK do.
      n =. {. nread
      if. n = 0 do. break. end.
      chunks =. >: chunks
      bytes  =. bytes + n
      
      chunk_data =. memr buf_addr, 0, n, 2

      smoutput '  chunk ' , (":chunks) , '  +' , (":n) , ' bytes   (total ' , (":bytes) , ')'
      smoutput '    DATA: ' , chunk_data
    case. CURLE_AGAIN do.
      6!:3 0.05
    case. do.
      smoutput 'recv returned code ' , ": rc
      break.
    end.
  end.

  memf buf_addr

  took =. 0.001 %~ <. 0.5 + 1000 * (6!:1 '') - started
  smoutput 'Done. ' , (":chunks) , ' chunks, ' , (":bytes) , ' bytes in ' , (":took) , ' ms'

  curl_easy_cleanup h
  smoutput '=== Test complete ===' , LF
  1
)

test_curl_stream ''