NB. Server-sent events for chat completions.
NB. OpenAI-style data lines and Anthropic content-block events
NB. both become one OpenAI chat.completion object. A JSON null
NB. content delta is skipped, never stored as the text json_null.

STREAM_BUF =: ''
STREAM_TEXT =: ''
STREAM_FINISH =: ''
STREAM_TC =: 0 3 $ <''
STREAM_BLOCK =: _1
STREAM_SAW =: 0
STREAM_SHOWN =: 0

stream_reset =: monad define
  STREAM_BUF =: ''
  STREAM_TEXT =: ''
  STREAM_FINISH =: ''
  STREAM_TC =: 0 3 $ <''
  STREAM_BLOCK =: _1
  STREAM_SAW =: 0
  STREAM_SHOWN =: 0
  ''
)

stream_null =: monad define
  v =. y
  while. (32 = 3!:0 v) *. 0 = #$ v do. v =. > v end.
  (2 = 3!:0 v) *. 'json_null' -: v
)

stream_str =: monad define
  if. _1 -: y do. '' return. end.
  if. stream_null y do. '' return. end.
  v =. > y
  if. 2 ~: 3!:0 v do. '' return. end.
  v
)

stream_show =: monad define
  if. 0 = # y do. '' return. end.
  STREAM_TEXT =: STREAM_TEXT , y
  STREAM_SHOWN =: 1
  if. 3 = 4!:0 <'tui_stream_add' do. tui_stream_add y end.
  ''
)

NB. y = id ; name ; arguments fragment. x = index.
stream_tc_merge =: dyad define
  idx =. x
  if. (idx < 0) +. idx > 32 do. '' return. end.
  'tid name frag' =. y
  while. idx >: # STREAM_TC do.
    STREAM_TC =: STREAM_TC , 1 3 $ '' ; '' ; ''
  end.
  row =. idx { STREAM_TC
  oid =. > 0 { row
  oname =. > 1 { row
  oargs =. > 2 { row
  if. 0 < # tid do. oid =. tid end.
  if. 0 < # name do. oname =. name end.
  oargs =. oargs , frag
  row =. 1 3 $ oid ; oname ; oargs
  STREAM_TC =: (idx {. STREAM_TC) , row , (idx + 1) }. STREAM_TC
  ''
)

stream_openai_delta =: monad define
  choices =. 'choices' gethash_json y
  if. _1 -: choices do. 0 return. end.
  choices =. > choices
  if. 0 = # choices do. 0 return. end.
  ch =. {. choices
  while. (32 = 3!:0 ch) *. 0 = #$ ch do. ch =. > ch end.
  if. 2 ~: #$ ch do. 0 return. end.
  fin =. stream_str 'finish_reason' gethash_json ch
  if. 0 < # fin do. STREAM_FINISH =: fin end.
  delta =. 'delta' gethash_json ch
  if. _1 -: delta do. 1 return. end.
  delta =. > delta
  while. (32 = 3!:0 delta) *. 0 = #$ delta do. delta =. > delta end.
  if. 2 ~: #$ delta do. 1 return. end.
  c =. 'content' gethash_json delta
  if. (_1 -.@-: c) *. -. stream_null c do.
    txt =. stream_str c
    if. 0 < # txt do. stream_show txt end.
  end.
  tcs =. 'tool_calls' gethash_json delta
  if. _1 -: tcs do. 1 return. end.
  tcs =. > tcs
  for_tc. tcs do.
    tc =. > tc
    while. (32 = 3!:0 tc) *. 0 = #$ tc do. tc =. > tc end.
    if. 2 ~: #$ tc do. continue. end.
    ix =. 'index' gethash_json tc
    n =. _1
    if. _1 -.@-: ix do.
      iv =. > ix
      if. (3!:0 iv) e. 1 4 8 do. n =. <. iv end.
    end.
    if. n = _1 do. n =. 0 end.
    tid =. stream_str 'id' gethash_json tc
    fn =. 'function' gethash_json tc
    name =. ''
    frag =. ''
    if. _1 -.@-: fn do.
      fn =. > fn
      while. (32 = 3!:0 fn) *. 0 = #$ fn do. fn =. > fn end.
      if. 2 = #$ fn do.
        name =. stream_str 'name' gethash_json fn
        frag =. stream_str 'arguments' gethash_json fn
      end.
    end.
    n stream_tc_merge tid ; name ; frag
  end.
  1
)

stream_anthropic =: monad define
  typ =. stream_str 'type' gethash_json y
  if. 0 = # typ do. 0 return. end.
  if. typ -: 'content_block_start' do.
    ix =. 'index' gethash_json y
    n =. 0
    if. _1 -.@-: ix do.
      iv =. > ix
      if. (3!:0 iv) e. 1 4 8 do. n =. <. iv end.
    end.
    STREAM_BLOCK =: n
    blk =. 'content_block' gethash_json y
    if. _1 -: blk do. 1 return. end.
    blk =. > blk
    while. (32 = 3!:0 blk) *. 0 = #$ blk do. blk =. > blk end.
    if. 2 ~: #$ blk do. 1 return. end.
    bt =. stream_str 'type' gethash_json blk
    if. bt -: 'tool_use' do.
      tid =. stream_str 'id' gethash_json blk
      name =. stream_str 'name' gethash_json blk
      n stream_tc_merge tid ; name ; ''
    end.
    1 return.
  end.
  if. typ -: 'content_block_delta' do.
    d =. 'delta' gethash_json y
    if. _1 -: d do. 1 return. end.
    d =. > d
    while. (32 = 3!:0 d) *. 0 = #$ d do. d =. > d end.
    if. 2 ~: #$ d do. 1 return. end.
    dt =. stream_str 'type' gethash_json d
    if. dt -: 'text_delta' do.
      stream_show stream_str 'text' gethash_json d
    elseif. dt -: 'input_json_delta' do.
      n =. STREAM_BLOCK
      if. n = _1 do. n =. 0 end.
      n stream_tc_merge '' ; '' ; stream_str 'partial_json' gethash_json d
    end.
    1 return.
  end.
  if. typ -: 'message_delta' do.
    d =. 'delta' gethash_json y
    if. _1 -.@-: d do.
      d =. > d
      while. (32 = 3!:0 d) *. 0 = #$ d do. d =. > d end.
      if. 2 = #$ d do.
        s =. stream_str 'stop_reason' gethash_json d
        if. s -: 'tool_use' do. STREAM_FINISH =: 'tool_calls'
        elseif. s -: 'end_turn' do. STREAM_FINISH =: 'stop'
        elseif. s -: 'max_tokens' do. STREAM_FINISH =: 'length'
        elseif. 0 < # s do. STREAM_FINISH =: 'stop'
        end.
      end.
    end.
    1 return.
  end.
  0
)

stream_line =: monad define
  line =. dlb y -. CR
  if. 0 = # line do. '' return. end.
  if. 'data:' -: 5 {. line do.
    STREAM_SAW =: 1
    data =. dlb 5 }. line
    if. '[DONE]' -: data do. '' return. end.
    if. 0 = # data do. '' return. end.
    o =. ''
    try. o =. dec_json data catch. '' return. end.
    if. 2 ~: #$ o do. '' return. end.
    if. stream_anthropic o do. '' return. end.
    stream_openai_delta o
    '' return.
  end.
  ''
)

stream_consume =: monad define
  STREAM_BUF =: STREAM_BUF , y
  while. LF e. STREAM_BUF do.
    i =. STREAM_BUF i. LF
    line =. i {. STREAM_BUF
    STREAM_BUF =: (i + 1) }. STREAM_BUF
    stream_line line
  end.
  ''
)

NB. OpenAI chat.completion JSON, or '' if no SSE data arrived.
stream_result_json =: monad define
  if. 0 = STREAM_SAW do. '' return. end.
  if. 0 ~: 4!:0 <'enc_json_fixed' do. load 'enc_json_fixed.ijs' end.
  finish =. STREAM_FINISH
  if. 0 = # finish do.
    if. 0 < # STREAM_TC do. finish =. 'tool_calls' else. finish =. 'stop' end.
  end.
  if. (0 < # STREAM_TC) *. -. finish -: 'length' do. finish =. 'tool_calls' end.
  tcs =. ''
  if. 0 < # STREAM_TC do.
    parts =. 0 $ <''
    for_i. i. # STREAM_TC do.
      tid =. > (< i, 0) { STREAM_TC
      name =. > (< i, 1) { STREAM_TC
      args =. > (< i, 2) { STREAM_TC
      if. 0 = # args do. args =. '{}' end.
      part =. '{"id":' , (enc_json_fixed tid) , ',"type":"function","function":{"name":' , (enc_json_fixed name) , ',"arguments":' , (enc_json_fixed args) , '}}'
      parts =. parts , < part
    end.
    tcs =. ',"tool_calls":[' , (}. ; (','&,)&.> parts) , ']'
  end.
  msg =. '{"role":"assistant","content":' , (enc_json_fixed STREAM_TEXT) , tcs , '}'
  '{"choices":[{"finish_reason":' , (enc_json_fixed finish) , ',"message":' , msg , '}]}'
)

echo 'stream loaded.'
