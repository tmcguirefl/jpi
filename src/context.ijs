NB. Context window management
NB. context.ijs

NB. Context window limit is set dynamically by config.ijs (update_config_state
NB. via context_limit '') based on the active provider/model. config.ijs loads
NB. before context.ijs in the agent load chain, so MAX_TOKENS is already defined
NB. when we get here. The guard below is a fallback for standalone loads (e.g.
NB. tests) that don't go through config. Wrapped in an explicit definition
NB. because control words (if.) are only valid inside explicit definitions,
NB. not at script top level.
set_max_tokens =: monad define
  if. _1 = 4!:0 <'MAX_TOKENS' do. MAX_TOKENS =: 100000 end.
)
set_max_tokens ''

NB. Approximate tokens per character (rough heuristic: 1 token ~ 4 chars)
CHARS_PER_TOKEN =: 4

NB. Estimate token count of a string
NB. Tacit: [: <. # % 4"_ — fork: floor of (length divided by constant)
NB. Explicit original:
NB.   est_tokens =: monad define
NB.     <. (#y) % CHARS_PER_TOKEN
NB. )
est_tokens =: [: <. # % CHARS_PER_TOKEN"_

NB. Estimate total tokens in HISTORY
NB. Tacit: +/ @: (est_tokens &>) — sum of est_tokens applied to each opened box
NB. Now takes HISTORY as argument (was: read global, called with '').
NB. Explicit original:
NB.   history_tokens =: monad define
NB.     +/ est_tokens&> HISTORY
NB. )
history_tokens =: +/ @: (est_tokens &>)

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
  
  NB. Build payload without tools.
  NB. MODEL MUST be routed via model_for_api (strip provider prefix) -
  NB. the raw jpi name (e.g. 'mistral/glm-5-2') is not a valid API
  NB. model id, which silently broke EVERY compaction call.
  api_model =. model_for_api MODEL
  all_msgs =. (< sys_msg) , chunk
  msgs_json =. _1 }. ; (,&',') each all_msgs

  NB. Anthropic requires max_tokens; all other providers omit it
  if. uses_openai_tools '' do.
    payload =. '{"model":"' , api_model , '","messages":[' , msgs_json , ']}'
  else.
    payload =. '{"model":"' , api_model , '","max_tokens":1024,"messages":[' , msgs_json , ']}'
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
  total =. history_tokens HISTORY
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
