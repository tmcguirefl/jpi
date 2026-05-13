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

NB. Trim oldest messages (keep system + most recent) if over budget
NB. Preserves the first message (usually the first user msg) and trims from front
trim_history =: monad define
  total =. history_tokens ''
  if. total < MAX_TOKENS do. return. end.
  NB. keep dropping oldest messages until under budget
  NB. never drop below 4 messages (preserve recent context)
  while. (history_tokens '') > MAX_TOKENS do.
    if. 4 >: #HISTORY do.
      echo 'WARNING: context still over limit after trimming'
      return.
    end.
    NB. drop the oldest pair (user + assistant)
    HISTORY =: 2 }. HISTORY
  end.
  echo 'Context trimmed. Messages: ' , (": #HISTORY) , '  Est. tokens: ' , ": history_tokens ''
)

echo 'context loaded.'
