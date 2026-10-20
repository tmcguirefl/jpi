NB. HTTP Stream transport using J/Libcurl FFI
NB. http_stream.ijs

load 'api/curl'
coinsert 'jcurl'

NB. Global chunk buffer for SSE parsing
SSE_BUFFER =: ''

NB. Global string accumulator to return the complete JSON for history tracking
LLM_FULL_RESPONSE =: ''

NB. Finish reason and tool-call fragments collected across SSE chunks.
NB. Tool arguments arrive as concatenated string pieces, keyed by index.
STREAM_FINISH =: ''
TC_IDS   =: 0$a:
TC_NAMES =: 0$a:
TC_ARGS  =: 0$a:

splitstring =: E. <;.1 ]

NB. convert/json represents null as the string json_null, boxed or bare
json_nullq =: monad define
  v =. y
  if. 32 = 3!:0 v do.
    if. 0 = $$ v do. v =. > v else. 0 return. end.
  end.
  (2 = 3!:0 v) *. v -: 'json_null'
)

NB. JSON array as a list of boxed items.
NB. dec_json boxes a one-element array as a scalar. Open scalar boxes,
NB. but stop before opening an object (a rank-2 table).
boxed_items =: monad define
  if. y -: _1 do. 0$a: return. end.
  if. json_nullq y do. 0$a: return. end.
  if. 32 ~: 3!:0 y do. 0$a: return. end.
  v =. y
  while. (32 = 3!:0 v) *. 0 = $$ v do. v =. > v end.
  if. 2 = $$ v do. , <v return. end.
  v
)

stream_reset =: monad define
  SSE_BUFFER =: ''
  LLM_FULL_RESPONSE =: ''
  STREAM_FINISH =: ''
  TC_IDS =: 0$a:
  TC_NAMES =: 0$a:
  TC_ARGS =: 0$a:
  ''
)

NB. Show one new text fragment. The TUI redraws the whole answer so far.
stream_show =: monad define
  if. 0 = #y do. return. end.
  if. 0 ~: 4!:0 <'TUI_RUNNING' do.
    smoutput y
  else.
    if. TUI_RUNNING do.
      TUI_OUTPUT =: STREAM_START_IDX {. TUI_OUTPUT
      tui_echo LLM_FULL_RESPONSE
      tui_redraw ''
    else.
      smoutput y
    end.
  end.
)

NB. Append real text. JSON null is the string json_null and must be ignored.
stream_take_content =: monad define
  if. y -: _1 do. return. end.
  if. json_nullq y do. return. end.
  text =. y
  if. 32 = 3!:0 text do. text =. > text end.
  if. 2 ~: 3!:0 text do. return. end.
  if. 0 = #text do. return. end.
  LLM_FULL_RESPONSE =: LLM_FULL_RESPONSE , text
  stream_show text
)

NB. Merge one streamed tool-call fragment into TC_* by its index.
stream_take_tool =: monad define
  tc =. y
  idx =. 'index' gethash_json tc
  i =. 0
  if. (idx -.@-: _1) *. -. json_nullq idx do.
    i =. <. > idx
  end.
  if. (i < 0) +. i > 31 do. return. end.
  while. i >: #TC_IDS do.
    TC_IDS =: TC_IDS , <''
    TC_NAMES =: TC_NAMES , <''
    TC_ARGS =: TC_ARGS , <''
  end.
  id =. 'id' gethash_json tc
  if. (id -.@-: _1) *. -. json_nullq id do.
    s =. > id
    if. (2 = 3!:0 s) *. 0 < #s do. TC_IDS =: (<s) (<i)} TC_IDS end.
  end.
  fn =. 'function' gethash_json tc
  if. (fn -: _1) +. json_nullq fn do. return. end.
  func =. > fn
  nm =. 'name' gethash_json func
  if. (nm -.@-: _1) *. -. json_nullq nm do.
    s =. > nm
    if. (2 = 3!:0 s) *. 0 < #s do. TC_NAMES =: (<s) (<i)} TC_NAMES end.
  end.
  ar =. 'arguments' gethash_json func
  if. (ar -: _1) +. json_nullq ar do. return. end.
  s =. ar
  if. 32 = 3!:0 s do. s =. > s end.
  if. 2 ~: 3!:0 s do. return. end.
  TC_ARGS =: (< ((> i{TC_ARGS) , s)) (<i)} TC_ARGS
)

NB. One SSE data payload (the JSON after "data: ")
stream_handle_data =: monad define
  try.
    json =. dec_json y
    choices =. > 'choices' gethash_json json
    if. 0 = # choices do. return. end.
    ch =. > {. choices
    fr =. 'finish_reason' gethash_json ch
    if. (fr -.@-: _1) *. -. json_nullq fr do.
      frs =. > fr
      if. (2 = 3!:0 frs) *. 0 < #frs do. STREAM_FINISH =: frs end.
    end.
    delta =. 'delta' gethash_json ch
    if. (delta -: _1) +. json_nullq delta do. return. end.
    delta =. > delta
    stream_take_content 'content' gethash_json delta
    tcs =. 'tool_calls' gethash_json delta
    if. (tcs -.@-: _1) *. -. json_nullq tcs do.
      for_t. boxed_items tcs do. stream_take_tool > t end.
    end.
  catch.
  end.
)

NB. One complete SSE line, including a leading LF left by splitstring
stream_handle_line =: monad define
  str =. y
  while. (0 < #str) *. ({. str) e. CR,LF do. str =. }. str end.
  str =. str -. CR
  if. 0 = #str do. return. end.
  if. 'data:' -: 5 {. str do.
    str =. dlb 5 }. str
    if. (str -: '[DONE]') +. 0 = #str do. return. end.
    stream_handle_data str
    return.
  end.
)

NB. Build the OpenAI chat-completion object the tool loop already parses
stream_assemble =: monad define
  calls =. 0$a:
  for_i. i. #TC_IDS do.
    id =. > i { TC_IDS
    nm =. > i { TC_NAMES
    args =. > i { TC_ARGS
    if. (0 = #id) *. (0 = #nm) *. (0 = #args) do. continue. end.
    if. 0 = #args do. args =. '{}' end.
    func =. ('name';'arguments') ,: (nm ; args)
    tc =. ('id';'type';'function') ,: (id ; 'function' ; <func)
    calls =. calls , <tc
  end.
  if. 0 < #calls do.
    if. 0 = #LLM_FULL_RESPONSE do. content =. 'json_null' else. content =. LLM_FULL_RESPONSE end.
    msg =. ('role';'content';'tool_calls') ,: ('assistant'; content; <calls)
    finish =. STREAM_FINISH
    if. (0 = #finish) +. finish -: 'stop' do. finish =. 'tool_calls' end.
  else.
    msg =. ('role';'content') ,: ('assistant'; LLM_FULL_RESPONSE)
    finish =. STREAM_FINISH
    if. 0 = #finish do. finish =. 'stop' end.
  end.
  choice =. ('finish_reason';'message') ,: (finish ; <msg)
  enc_json_fixed 2 1 $ ('choices' ; < , <choice)
)

NB. The libcurl unmanaged callback endpoint
cdcallback=: 3 : 0
  args =. 15!:17 ''
  if. 4 = #args do. writedata args end.
)

NB. Parse SSE chunks, update UI, and accumulate JSON
writedata =: 3 : 0
  'ptr size nmemb userp' =. y
  real_size =. size * nmemb
  chunk =. memr ptr, 0, real_size, 2
  
  NB. Append to incomplete line buffer
  SSE_BUFFER =: SSE_BUFFER , chunk
  
  NB. Split by newline
  parts =. (LF) splitstring SSE_BUFFER
  
  if. 1 < #parts do.
    NB. Keep the last part (it might not be a complete line)
    SSE_BUFFER =: > {: parts
    complete_lines =. }: parts
    
    for_line. complete_lines do.
      str =. > line
      NB. trim leading LF if present from splitstring
      if. LF = {. str do. str =. }. str end.
      
      stream_handle_line str
    end.
  end.
  
  real_size
)

NB. stream POST utilizing proper Libcurl handles
http_stream_post =: dyad define
  url =. x
  body =. y
  
  NB. Reset global variables
  stream_reset ''
  
  if. 0 = 4!:0 <'TUI_OUTPUT' do. STREAM_START_IDX =: #TUI_OUTPUT else. STREAM_START_IDX =: 0 end.
  
  f =. [: 15!:13 (IFWIN#'+') , ' x' $~ +:@>:
  cb_ptr =. f 4
  
  curl_global_init <0
  curl =. curl_easy_init ''
  if. curl = 0 do. 'error' return. end.

  NB. Setup headers
  headers =. 0
  headers =. curl_slist_append headers ; 'Content-Type: application/json'
  headers =. curl_slist_append headers ; 'Accept: text/event-stream'

  select. PROVIDER
  case. 'openrouter' do.
    headers =. curl_slist_append headers ; 'Authorization: Bearer ' , API_KEY
  case. 'google' do.
    headers =. curl_slist_append headers ; 'Authorization: Bearer ' , API_KEY
  case. 'local' do.
    if. 0 < #API_KEY do. headers =. curl_slist_append headers ; 'Authorization: Bearer ' , API_KEY end.
  case. 'ollama' do.
    if. 0 < #API_KEY do. headers =. curl_slist_append headers ; 'Authorization: Bearer ' , API_KEY end.
  case. 'tcm' do.
    if. 0 < #API_KEY do. headers =. curl_slist_append headers ; 'Authorization: Bearer ' , API_KEY end.
  case. 'anthropic' do.
    headers =. curl_slist_append headers ; 'x-api-key: ' , API_KEY
    headers =. curl_slist_append headers ; 'anthropic-version: 2023-06-01'
  end.

  curl_easy_setopt_str curl; CURLOPT_URL; setopt_variadic, <url
  curl_easy_setopt curl; CURLOPT_HTTPHEADER; setopt_variadic, <headers
  
  NB. Bind the POST body String!
  curl_easy_setopt_str curl; CURLOPT_POSTFIELDS; setopt_variadic, <body
  
  NB. Attach our J callback!
  curl_easy_setopt curl; CURLOPT_WRITEFUNCTION; setopt_variadic, <cb_ptr
  curl_easy_setopt curl; CURLOPT_WRITEDATA; setopt_variadic, <1

  NB. Run the stream (This blocks the line but constantly triggers 'writedata')
  rc =. curl_easy_perform <curl
  
  curl_slist_free_all <headers
  curl_easy_cleanup <curl
  curl_global_cleanup ''
  
  if. 0 = 4!:0 <'TUI_OUTPUT' do. TUI_OUTPUT =: STREAM_START_IDX {. TUI_OUTPUT end.
  
  NB. OpenAI-shaped completion. Tool-call fragments are reassembled.
  NB. JSON null content is omitted, so it cannot render as the text json_null.
  stream_assemble ''
)
