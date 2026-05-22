NB. Configuration
NB. config.ijs

require 'files'

NB. Provider: 'openrouter' or 'anthropic'
PROVIDER =: 'openrouter'

NB. Lookup tables (_2 ]\ turns flat list into 2-column table)
API_URLS =: _2 ]\ 'openrouter';'https://openrouter.ai/api/v1/chat/completions';'anthropic';'https://api.anthropic.com/v1/messages';'google';'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';'local';'http://localhost:8080/v1/chat/completions';'ollama';'http://localhost:11434/v1/chat/completions';'tcm';'https://tcmcguire.servehttp.com/v1/chat/completions'
ENV_KEYS =: _2 ]\ 'openrouter';'OPENROUTER_API_KEY';'anthropic';'ANTHROPIC_API_KEY';'google';'GEMINI_API_KEY';'local';'LOCAL_API_KEY';'ollama';'OLLAMA_API_KEY';'tcm';'TCM_API_KEY'
MODELS   =: _2 ]\ 'openrouter';'anthropic/claude-sonnet-4';'anthropic';'claude-sonnet-4-20250514';'google';'gemini-2.5-flash';'local';'local/llama-server';'ollama';'ollama/llama3';'tcm';'tcm/llama.cpp9270'

NB. Infer provider from the model string
infer_provider =: monad define
  if. 'ollama/' -: 7 {. y do. 'ollama' return. end.
  if. 'local/' -: 6 {. y do. 'local' return. end.
  if. 'claude-' -: 7 {. y do. 'anthropic' return. end.
  if. 'gemini' +./@E. y do. 'google' return. end.
  if. 'tcm/' -: 4 {. y do. 'tcm' return. end.
  'openrouter'   NB. fallback covers all 'org/model' formatted OpenRouter strings
)

NB. Update networking configuration based on active MODEL
update_config_state =: monad define
  PROVIDER =: infer_provider MODEL
  API_URL =: > (<(({."1 API_URLS) i. <PROVIDER), 1) { API_URLS
  
  NB. Allow environment variables to override endpoints for self-hosted LLMs
  try.
    if. PROVIDER -: 'local' do.
      if. 0 < # > 2!:5 'LOCAL_API_URL' do. API_URL =: > 2!:5 'LOCAL_API_URL' end.
    elseif. PROVIDER -: 'ollama' do.
      if. 0 < # > 2!:5 'OLLAMA_API_URL' do. API_URL =: > 2!:5 'OLLAMA_API_URL' end.
    end.
  catch. end.

  env =. > (<(({."1 ENV_KEYS) i. <PROVIDER), 1) { ENV_KEYS
  try.
    key =. 2!:5 env
    if. 0 < #key do. API_KEY =: key return. end.
  catch. end.
  API_KEY =: ''
)

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
  update_config_state ''
)
load_model ''

NB. Save current model to disk
save_model =: monad define
  MODEL fwrite CONFIG_MODEL_FILE
  update_config_state ''
)

echo 'config loaded. Provider: ' , PROVIDER , '  API_KEY length: ' , ": #API_KEY
