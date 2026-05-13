NB. Configuration
NB. config.ijs

NB. Provider: 'openrouter' or 'anthropic'
PROVIDER =: 'openrouter'

NB. Load API key from environment
API_KEY =: monad define
  select. PROVIDER
  case. 'openrouter' do. env =. 'OPENROUTER_API_KEY'
  case. 'anthropic'  do. env =. 'ANTHROPIC_API_KEY'
  case. do. '' return.
  end.
  try.
    key =. 2!:5 env
    if. 0 < #key do. key return. end.
  catch. end.
  ''
) ''

NB. API URLs
API_URLS =: 'openrouter';'https://openrouter.ai/api/v1/chat/completions';'anthropic';'https://api.anthropic.com/v1/messages'

API_URL =: monad define
  select. PROVIDER
  case. 'openrouter' do. 'https://openrouter.ai/api/v1/chat/completions'
  case. 'anthropic'  do. 'https://api.anthropic.com/v1/messages'
  case. do. ''
  end.
) ''

NB. Default model per provider
MODEL =: monad define
  select. PROVIDER
  case. 'openrouter' do. 'anthropic/claude-sonnet-4-20250514'
  case. 'anthropic'  do. 'claude-sonnet-4-20250514'
  case. do. ''
  end.
) ''

echo 'config loaded. Provider: ' , PROVIDER , '  API_KEY length: ' , ": #API_KEY
