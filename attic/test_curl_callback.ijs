NB. test_curl_callback.ijs
NB. Proper callback method for Libcurl streaming in J!

load '/Users/tomdevel/j9.7/addons/api/curl/curl.ijs'
coinsert 'jcurl'

NB. Global variables for tracking
total_bytes =: 0
chunks_recv =: 0

NB. The global callback function invoked by J's FFI when C calls a J function pointer
cdcallback=: 3 : 0
  args =. 15!:17 ''
  if. 4 = #args do.
    stream_chunk args
  end.
)

stream_chunk=: 3 : 0
  'ptr size nmemb userp' =. y
  real_size =. size * nmemb
  
  chunks_recv =: chunks_recv + 1
  total_bytes =: total_bytes + real_size
  
  NB. stringify the raw C memory
  chunk =. memr ptr, 0, real_size, 2
  
  smoutput ''
  smoutput '--- STREAM TUI CHUNK ' , (":chunks_recv) , ' (' , (":real_size) , ' bytes) ---'
  smoutput chunk
  
  real_size  NB. C callback must return the exact number of bytes handled
)

test_callback_stream =: 3 : 0
  smoutput 'Initializing Libcurl streaming with J Callbacks...'
  curl_global_init <0
  curl =. curl_easy_init ''
  
  if. curl = 0 do. smoutput 'failed' return. end.

  NB. Prepare a 4-argument C->J callback pointer using 15!:13
  NB. Windows (IFWIN) usually uses stdcall (+), Unix uses cdecl.
  f =. [: 15!:13 (IFWIN#'+') , ' x' $~ +:@>:
  callback_ptr =. f 4
  
  NB. Set URL (httpbin streaming endpoint)
  curl_easy_setopt_str curl; CURLOPT_URL; setopt_variadic, <'https://httpbin.org/stream/5'
  
  NB. Register our J Callback function pointer for WRITEFUNCTION
  curl_easy_setopt curl; CURLOPT_WRITEFUNCTION; setopt_variadic, <callback_ptr
  
  smoutput 'Starting curl_easy_perform (This will stream asynchronously via callbacks)...'
  rc =. curl_easy_perform <curl
  
  if. rc ~: CURLE_OK do.
    smoutput 'Curl error!'
  end.
  
  smoutput 'CURL DONE PERFORMING'

  smoutput ''
  smoutput 'Done! Received ' , (":chunks_recv) , ' chunks (' , (":total_bytes) , ' bytes total).'
  
  curl_easy_cleanup <curl
  curl_global_cleanup ''
  ''
)

test_callback_stream ''
