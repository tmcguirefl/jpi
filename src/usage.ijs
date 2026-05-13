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
  if. -. _1 -: inp do.
    TOTAL_INPUT_TOKENS =: TOTAL_INPUT_TOKENS + > inp
  end.
  if. -. _1 -: out do.
    TOTAL_OUTPUT_TOKENS =: TOTAL_OUTPUT_TOKENS + > out
  end.
)

NB. Display session usage summary
show_usage =: monad define
  echo 'Session usage:'
  echo '  Input tokens:  ' , ": TOTAL_INPUT_TOKENS
  echo '  Output tokens: ' , ": TOTAL_OUTPUT_TOKENS
  echo '  Total tokens:  ' , ": TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS
)

NB. Reset counters
reset_usage =: monad define
  TOTAL_INPUT_TOKENS  =: 0
  TOTAL_OUTPUT_TOKENS =: 0
  TOTAL_COST          =: 0
)

echo 'usage loaded.'
