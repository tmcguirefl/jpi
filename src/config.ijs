NB. Configuration
NB. config.ijs
NB. Set API_KEY here or in your session before loading agent

NB. Load from environment variable if available
API_KEY =: monad define
  try.
    key =. 2!:5 'ANTHROPIC_API_KEY'
    if. 0 < #key do. key return. end.
  catch. end.
  ''
) ''

MODEL =: 'claude-sonnet-4-20250514'
API_URL =: 'https://api.anthropic.com/v1/messages'

echo 'config loaded. API_KEY length: ' , ": #API_KEY
