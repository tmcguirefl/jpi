NB. Token and cost tracking
NB. usage.ijs

NB. Session totals
TOTAL_INPUT_TOKENS  =: 0
TOTAL_OUTPUT_TOKENS =: 0
TOTAL_COST          =: 0

NB. Extract usage info from OpenRouter response and accumulate
NB. y = parsed response (from dec_json)
track_usage =: monad define
  usg =. 'usage' gethash_json y
  if. _1 -: usg do. return. end.
  usg =. > usg
  NB. extract token counts
  inp =. 'prompt_tokens' gethash_json usg
  out =. 'completion_tokens' gethash_json usg
  
  i =. 0
  o =. 0
  if. -. _1 -: inp do.
    i =. > inp
    TOTAL_INPUT_TOKENS =: TOTAL_INPUT_TOKENS + i
  end.
  if. -. _1 -: out do.
    o =. > out
    TOTAL_OUTPUT_TOKENS =: TOTAL_OUTPUT_TOKENS + o
  end.
  
  NB. Compute approximate cost per model (dollars per million tokens)
  NB. Default fallback is $1 in, $2 out
  in_cost =. 1.0
  out_cost =. 2.0
  
  if. 'claude-3-7-sonnet' +./@E. MODEL do.
    in_cost =. 3.0 [ out_cost =. 15.0
  elseif. 'claude-3-5-sonnet' +./@E. MODEL do.
    in_cost =. 3.0 [ out_cost =. 15.0
  elseif. 'claude-3-5-haiku' +./@E. MODEL do.
    in_cost =. 0.8 [ out_cost =. 4.0
  elseif. 'claude-3-opus' +./@E. MODEL do.
    in_cost =. 15.0 [ out_cost =. 75.0
  elseif. 'gpt-4o-mini' +./@E. MODEL do.
    in_cost =. 0.15 [ out_cost =. 0.60
  elseif. 'gpt-4o' +./@E. MODEL do.
    in_cost =. 2.5 [ out_cost =. 10.0
  elseif. 'o1-mini' +./@E. MODEL do.
    in_cost =. 1.10 [ out_cost =. 4.40
  elseif. 'o3-mini' +./@E. MODEL do.
    in_cost =. 1.10 [ out_cost =. 4.40
  elseif. 'o1' +./@E. MODEL do.
    in_cost =. 15.0 [ out_cost =. 60.0
  elseif. 'tcm/' +./@E. MODEL do.
    in_cost =. 0.0 [ out_cost =. 0.0
  elseif. 'gemini-2.5-flash' +./@E. MODEL do.
    in_cost =. 0.07 [ out_cost =. 0.30
  elseif. 'gemini' +./@E. MODEL do.
    in_cost =. 0.15 [ out_cost =. 0.60
  elseif. 'llama' +./@E. MODEL do.
    in_cost =. 0.05 [ out_cost =. 0.15
  elseif. 'deepseek-chat' +./@E. MODEL do.
    in_cost =. 0.14 [ out_cost =. 0.28
  elseif. 'deepseek-reasoner' +./@E. MODEL do.
    in_cost =. 0.55 [ out_cost =. 2.19
  end.
  
  cost_inc =. (i * in_cost % 1000000) + (o * out_cost % 1000000)
  TOTAL_COST =: TOTAL_COST + cost_inc
)

NB. Format cost to string rounding to 4 decimals
format_cost =: monad define
  fmt =. ": 0.0001 * <. 0.5 + 10000 * TOTAL_COST
  '$' , fmt
)

NB. Display session usage summary
show_usage =: monad define
  echo 'Session usage:'
  echo '  Input tokens:  ' , ": TOTAL_INPUT_TOKENS
  echo '  Output tokens: ' , ": TOTAL_OUTPUT_TOKENS
  echo '  Total tokens:  ' , ": TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS
  echo '  Est. Cost:     ' , format_cost ''
)

NB. Reset counters
reset_usage =: monad define
  TOTAL_INPUT_TOKENS  =: 0
  TOTAL_OUTPUT_TOKENS =: 0
  TOTAL_COST          =: 0
)

echo 'usage loaded.'
