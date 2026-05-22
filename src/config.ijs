NB. Configuration
NB. config.ijs

require 'files'

NB. Provider: 'openrouter' or 'anthropic'
PROVIDER =: 'openrouter'

NB. Lookup tables (_2 ]\ turns flat list into 2-column table)
API_URLS =: _2 ]\ 'openrouter';'https://openrouter.ai/api/v1/chat/completions';'anthropic';'https://api.anthropic.com/v1/messages';'google';'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
ENV_KEYS =: _2 ]\ 'openrouter';'OPENROUTER_API_KEY';'anthropic';'ANTHROPIC_API_KEY';'google';'GEMINI_API_KEY'
MODELS   =: _2 ]\ 'openrouter';'anthropic/claude-sonnet-4';'anthropic';'claude-sonnet-4-20250514';'google';'gemini-2.5-flash'

NB. Derive config from tables using i.
API_URL =: > (<(({."1 API_URLS) i. <PROVIDER), 1) { API_URLS
MODEL   =: > (<(({."1 MODELS)   i. <PROVIDER), 1) { MODELS

CONFIG_MODEL_FILE =: (2!:5 'HOME') , '/.jpi_model'

NB. Load saved model from disk if present
load_model =: monad define
  try.
    if. fexist CONFIG_MODEL_FILE do.
      m =. fread CONFIG_MODEL_FILE
      if. 0 < #m do.
        MODEL =: m -. 10 13 { a.    NB. strip newlines
      end.
    end.
  catch. end.
  ''
)
load_model ''

NB. Save current model to disk
save_model =: monad define
  MODEL fwrite CONFIG_MODEL_FILE
)

NB. Load API key from environment
get_api_key =: monad define
  env =. > (<(({."1 ENV_KEYS) i. <PROVIDER), 1) { ENV_KEYS
  try.
    key =. 2!:5 env
    if. 0 < #key do. key return. end.
  catch. end.
  ''
)
API_KEY =: get_api_key ''

echo 'config loaded. Provider: ' , PROVIDER , '  API_KEY length: ' , ": #API_KEY
