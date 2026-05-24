NB. HTTP Stream transport using J/Libcurl FFI
NB. http_stream.ijs

load 'api/curl'
coinsert 'jcurl'

NB. Global chunk buffer for SSE parsing
SSE_BUFFER =: ''

NB. Global string accumulator to return the complete JSON for history tracking
LLM_FULL_RESPONSE =: ''

splitstring =: E. <;.1 ]

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
      
      if. 'data: ' -: 6 {. str do.
        str =. 6 }. str
        if. str -: '[DONE]' do. continue. end.
        if. 0 < #str do.
          NB. Safely parse JSON and extract text delta
          try.
            json =. dec_json str
            choices =. > 'choices' gethash_json json
            if. 0 < #choices do.
              delta =. > 'delta' gethash_json > {. choices
              
              NB. Check if it's text content
              if. _1 -.@-: 'content' gethash_json delta do.
                content =. > 'content' gethash_json delta
                if. 0 < #content do.
                  LLM_FULL_RESPONSE =: LLM_FULL_RESPONSE , content
                  if. 0 ~: 4!:0 <'TUI_RUNNING' do.
                    smoutput content
                  else.
                    if. TUI_RUNNING do.
                      TUI_OUTPUT =: STREAM_START_IDX {. TUI_OUTPUT
                      tui_echo LLM_FULL_RESPONSE
                      tui_redraw ''
                    else.
                      smoutput content
                    end.
                  end.
                end.
              end.
            end.
          catch.
          end.
        end.
      else.
        NB. Ignore SSE comments starting with colon (e.g. : OPENROUTER PROCESSING)
        if. ':' ~: {. str do.
          if. 0 < #str do.
            LLM_FULL_RESPONSE =: LLM_FULL_RESPONSE , str , LF
            if. 0 ~: 4!:0 <'TUI_RUNNING' do.
              smoutput str
            else.
              if. TUI_RUNNING do.
                TUI_OUTPUT =: STREAM_START_IDX {. TUI_OUTPUT
                tui_echo LLM_FULL_RESPONSE
                tui_redraw ''
              else.
                smoutput str
              end.
            end.
          end.
        end.
      end.
    end.
  end.
  
  real_size
)

NB. stream POST utilizing proper Libcurl handles
http_stream_post =: dyad define
  url =. x
  body =. y
  
  NB. Reset global variables
  SSE_BUFFER =: ''
  LLM_FULL_RESPONSE =: ''
  
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
  
  NB. Return a mock JSON object that matches the old format so JPI's track_usage doesn't break
  '{"choices":[{"message":{"role":"assistant","content":"' , (LLM_FULL_RESPONSE rplc '"';'\"';LF;'\n';CR;'\r';TAB;'\t') , '"}}]}'
)
