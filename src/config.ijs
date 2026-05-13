NB. Configuration
NB. config.ijs

NB. Provider: 'openrouter' or 'anthropic'
PROVIDER =: 'openrouter'

NB. Lookup tables (_2 ]\ turns flat list into 2-column table)
API_URLS =: _2 ]\ 'openrouter';'https://openrouter.ai/api/v1/chat/completions';'anthropic';'https://api.anthropic.com/v1/messages'
ENV_KEYS =: _2 ]\ 'openrouter';'OPENROUTER_API_KEY';'anthropic';'ANTHROPIC_API_KEY'
MODELS   =: _2 ]\ 'openrouter';'anthropic/claude-sonnet-4-20250514';'anthropic';'claude-sonnet-4-20250514'

NB. Table lookup: find provider in column 0, return column 1
tlookup =: dyad define
  NB. x = provider string, y = 2-column table
  idx =. ({."1 y) i. < x
  > (<idx, 1) { y
)

NB. Derive config from tables
API_URL =: PROVIDER tlookup API_URLS
MODEL   =: PROVIDER tlookup MODELS

NB. Load API key from environment
API_KEY =: monad define
  env =. PROVIDER tlookup ENV_KEYS
  try.
    key =. 2!:5 env
    if. 0 < #key do. key return. end.
  catch. end.
  ''
) ''

echo 'config loaded. Provider: ' , PROVIDER , '  API_KEY length: ' , ": #API_KEY
