NB. Context window management
NB. context.ijs

NB. Approximate token limit (most models support 128k+ but we cap for cost)
MAX_TOKENS =: 100000

NB. Approximate tokens per character (rough heuristic: 1 token ~ 4 chars)
CHARS_PER_TOKEN =: 4

NB. Estimate token count of a string
est_tokens =: monad define
  <. (#y) % CHARS_PER_TOKEN
)

NB. Estimate total tokens in HISTORY
history_tokens =: monad define
  +/ est_tokens&> HISTORY
)

NB. Force manual compaction of the oldest N messages
NB. y = number of messages to compact
force_compact =: monad define
  idx =. y
  if. idx > (#HISTORY) - 2 do. idx =. (#HISTORY) - 2 end.
  if. idx < 2 do. 
    echo 'Not enough history to compact.'
    return. 
  end.
  
  if. 2 | idx do. idx =. idx + 1 end.
  if. idx > #HISTORY do. idx =. #HISTORY end.
  perform_compaction idx
)

NB. Internal compaction execution given an index
perform_compaction =: monad define
  idx =. y
  if. idx < 2 do. return. end.

  sys_prompt =. 'You are a vital memory manager for an autonomous coding agent. Summarize the following early conversation turns into a dense paragraph. Retain all crucial facts, file paths discussed, constraints, code snippets requested, and decisions made. This summary will permanently replace the raw messages to save context space, so omit nothing that is needed for future reasoning. Output ONLY the summary.'
  sys_msg =. 'system' mk_msg sys_prompt
  
  echo 'Compacting oldest ' , (": idx) , ' messages from context buffer...'
  if. 3 = 4!:0 <'tui_redraw' do. tui_redraw'' end.
  
  chunk =. idx {. HISTORY
  
  NB. Build payload without tools
  all_msgs =. (< sys_msg) , chunk
  msgs_json =. _1 }. ; (,&',') each all_msgs
  
  if. (PROVIDER -: 'openrouter') +. (PROVIDER -: 'google') +. (PROVIDER -: 'local') +. (PROVIDER -: 'ollama') do.
    payload =. '{"model":"' , MODEL , '","messages":[' , msgs_json , ']}'
  else.
    payload =. '{"model":"' , MODEL , '","max_tokens":1024,"messages":[' , msgs_json , ']}'
  end.
  
  try.
    resp =. llm_call payload
    if. 0 = #resp do. echo 'WARNING: compaction failed (empty).' [ return. end.
    if. has_error resp do. show_error resp [ return. end.
    
    summary =. get_or_content resp
    if. 0 < #summary do.
      new_msg =. 'assistant' mk_msg '<summary>' , LF , summary , LF , '</summary>'
      HISTORY =: (< new_msg) , idx }. HISTORY
      echo 'Context compacted seamlessly.'
      if. 3 = 4!:0 <'tui_redraw' do. tui_redraw'' end.
    end.
  catch.
    echo 'WARNING: Failed to execute background compaction.'
  end.
)

NB. Trim oldest messages by summarizing them via background LLM call
trim_history =: monad define
  total =. history_tokens ''
  if. total < MAX_TOKENS do. return. end.
  
  if. 6 >: #HISTORY do.
    echo 'WARNING: context over limit but too few messages to compact.'
    return.
  end.
  
  NB. Target leaving 20% headroom
  target =. <. 0.8 * MAX_TOKENS
  accum =. 0
  idx =. 0
  
  NB. Find how many messages to compact from the beginning
  while. (idx < #HISTORY) *. (total - accum) > target do.
    accum =. accum + est_tokens > idx { HISTORY
    idx =. idx + 1
  end.
  
  NB. Need to compact an even number to keep user/assistant parity ideally, but not strictly required
  if. 2 | idx do. idx =. idx + 1 end.
  
  NB. Don't compact the very last few active messages (short term memory)
  if. idx > (#HISTORY) - 4 do. idx =. (#HISTORY) - 4 end.
  
  perform_compaction idx
)

echo 'context loaded.'
