NB. Configuration
NB. config.ijs

require 'files'

NB. Provider: 'openrouter', 'anthropic', 'cohere', 'google', 'local', 'ollama', 'tcm', 'hyai', 'mistral'
PROVIDER =: 'openrouter'

NB. API URLs for each provider
API_URL_openrouter =: 'https://openrouter.ai/api/v1/chat/completions'
API_URL_anthropic =: 'https://api.anthropic.com/v1/messages'
API_URL_cohere =: 'https://api.cohere.com/v2/chat'
API_URL_google =: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
API_URL_local =: 'http://localhost:8080/v1/chat/completions'
API_URL_ollama =: 'http://localhost:11434/v1/chat/completions'
API_URL_tcm =: 'https://tcmcguire.servehttp.com/v1/chat/completions'
API_URL_hyai =: 'https://hostyourai.com/api/v1/chat/completions'
API_URL_mistral =: 'https://api.mistral.ai/v1/chat/completions'
API_URL_xai =: 'https://api.x.ai/v1/chat/completions'

NB. Environment variable names for each provider
ENV_KEY_openrouter =: 'OPENROUTER_API_KEY'
ENV_KEY_mistral =: 'MISTRAL_API_KEY'
ENV_KEY_anthropic =: 'ANTHROPIC_API_KEY'
ENV_KEY_cohere =: 'COHERE_API_KEY'
ENV_KEY_google =: 'GEMINI_API_KEY'
ENV_KEY_local =: 'LOCAL_API_KEY'
ENV_KEY_ollama =: 'OLLAMA_API_KEY'
ENV_KEY_tcm =: 'TCM_API_KEY'
ENV_KEY_hyai =: 'HYAI_API_KEY'
ENV_KEY_xai =: 'XAI_API_KEY'

NB. Infer provider from the model string
infer_provider =: monad define
  if. 'ollama/' -: 7 {. y do. 'ollama' return. end.
  if. 'local/' -: 6 {. y do. 'local' return. end.
  if. 'claude-' -: 7 {. y do. 'anthropic' return. end.
  if. 'gemini' +./@E. y do. 'google' return. end.
  if. 'command-' -: 8 {. y do. 'cohere' return. end.
  NB. Cohere North models (north-*) are served by api.cohere.com directly.
  if. 'north-' -: 6 {. y do. 'cohere' return. end.
  NB. cohere/ prefix: uniform routing for ALL Cohere-listed models
  NB. (command-*, aya, embed...) as picked from the model list.
  if. 'cohere/' -: 7 {. y do. 'cohere' return. end.
  if. 'mistral/' -: 8 {. y do. 'mistral' return. end.
  if. 'tcm/' -: 4 {. y do. 'tcm' return. end.
  if. 'hyai/' -: 5 {. y do. 'hyai' return. end.
  NB. xai/ and a bare grok- id talk to api.x.ai. x-ai/ stays
  NB. on OpenRouter, which is how that catalog spells Grok.
  if. 'xai/' -: 4 {. y do. 'xai' return. end.
  if. 'grok-' -: 5 {. y do. 'xai' return. end.
  'openrouter'
)

NB. Strip the routing prefix from MODEL for the API payload.
NB. e.g. 'hyai/moonshotai/Kimi-K' -> 'moonshotai/Kimi-K'
NB. Models without a routing prefix (claude-*, command-*, gemini-*) pass through.
model_for_api =: monad define
  pfx =. infer_provider y
  select. pfx
  case. 'hyai' do. 5 }. y
  case. 'tcm' do. 4 }. y
  case. 'ollama' do. 7 }. y
  case. 'local' do. 6 }. y
  case. 'mistral' do. 8 }. y
  case. 'cohere' do.
    NB. strip ONLY the uniform cohere/ prefix; the legacy forms
    NB. (command-*, north-*) pass through unchanged
    if. 'cohere/' -: 7 {. y do. 7 }. y else. y end.
  case. 'xai' do.
    if. 'xai/' -: 4 {. y do. 4 }. y else. y end.
  case. do. y end.
)

NB. Does the current provider use the OpenAI tool format?
NB. All providers except Anthropic use {"type":"function","function":...}
NB. with "parameters" as the schema key. Anthropic uses bare tool objects
NB. with "input_schema".
NB.
NB. This checks TOOL FORMAT only — it does not mean the provider's API
NB. is OpenAI-compatible. Cohere v2 has its own native API format; the
NB. request shape happens to overlap but the response side needs
NB. special-casing (see llm.ijs).
NB. Tacit: -.@:(-:&'anthropic') reads PROVIDER via ".@('PROVIDER'"_)
NB. Explicit original:
NB.   uses_openai_tools =: monad define
NB.     -. PROVIDER -: 'anthropic'
NB. )
uses_openai_tools =: -.@:(-:&'anthropic') @ (".@('PROVIDER'"_))

NB. Get the schema key for tool definitions.
NB. anthropic -> 'input_schema', else -> 'parameters'
NB. Explicit original:
NB.   schema_key =: monad define
NB.     if. PROVIDER -: 'anthropic' do. 'input_schema' else. 'parameters' end.
NB. )
schema_key =: ('parameters'"_) ` ('input_schema'"_) @. (-:&'anthropic' @ (".@('PROVIDER'"_)))

NB. Context window limit (tokens) for the active provider/model.
NB. Uses the model's real context window rather than an artificial cost cap,
NB. so compaction triggers only when genuinely necessary (correctness over
NB. economy). Local/ollama default conservative since model windows vary.
context_limit =: monad define
  select. PROVIDER
  case. 'cohere' do. 256000      NB. Command A / A+: 256k
  case. 'mistral' do. 128000     NB. Mistral API models: 128k safe default
  case. 'anthropic' do. 200000   NB. Claude 3.x: 200k
  case. 'google' do. 1000000     NB. Gemini 1.5/2.0: 1M+
  case. 'openrouter' do. 128000  NB. varies by model; 128k safe modern default
  case. 'hyai' do. 128000        NB. HostYourAI serves open models; 128k safe default
  case. 'xai' do. 131072         NB. grok-4 class: 128k
  case. do. 100000 end.           NB. local/ollama/tcm: conservative default
)

NB. Dynamic context window: query the provider's model listing
NB. for the ACTIVE model's advertised window. Returns 0 when the
NB. provider/model does not advertise one; the caller then keeps
NB. the provider-default table above. Network is touched ONLY
NB. when explicitly called (/model change, /context auto) -
NB. never at load time, so bench drivers and print/rpc startup
NB. are unaffected. Requires http.ijs verbs (curl_run) at CALL
NB. time; config.ijs itself loads before http and must not call
NB. this at load.
model_context_window =: monad define
  select. PROVIDER
  case. 'mistral' do. url =. 'https://api.mistral.ai/v1/models'
  case. 'hyai' do. url =. 'https://hostyourai.com/api/v1/models'
  case. do. 0 return.
  end.
  try.
    key =. get_api_key (toupper PROVIDER) , '_API_KEY'
  catch.
    0 return.
  end.
  if. 0 = # key do. 0 return. end.
  hcfg =. 'header = "Content-Type: application/json"' , LF
  hcfg =. hcfg , 'header = "Authorization: Bearer ' , key , '"' , LF
  hcfg fwrite HTTP_HEADERFILE
  'code res' =. ('curl -s -K ' , HTTP_HEADERFILE) curl_run url
  ferase HTTP_HEADERFILE
  if. 'ERROR:' -: 6 {. res do. 0 return. end.
  try.
    js =. dec_json res
    marr =. 'data' gethash_json js
    if. marr -.@-: _1 do.
      api_model =. model_for_api MODEL
      for_m. > marr do.
        m =. > m
        idv =. 'id' gethash_json m
        if. (idv -.@-: _1) *. (api_model -: > idv) do.
          NB. providers name the field differently; json_num
          NB. returns _1 for missing/JSON-null fields
          wv =. json_num 'max_context_length' gethash_json m
          if. _1 = wv do. wv =. json_num 'context_length' gethash_json m end.
          if. 0 < wv do. wv return. end.
          0 return.
        end.
      end.
    end.
  catch.
    0 return.
  end.
  0
)

NB. Context budget policy: the provider-default table above is a
NB. COST CAP, not a correctness limit - a smaller budget fires
NB. compaction earlier and keeps requests cheap. The provider's
NB. advertised window is cached in MODEL_WINDOW purely as
NB. information; the budget changes ONLY when the user chooses
NB. (/context auto to adopt the advertised window, /context N to
NB. set any budget). /model changes never inflate the budget.
MODEL_WINDOW =: 0

NB. Look up + cache + report the advertised window (called on
NB. /model). Never changes MAX_TOKENS.
report_model_window =: monad define
  w =. model_context_window ''
  MODEL_WINDOW =: w
  if. 0 < w do.
    echo 'Model advertises a ' , (": w) , '-token context; budget stays ' , (": MAX_TOKENS) , ' (/context auto to use it)'
  end.
)

NB. Opt in: adopt the advertised window when the provider lists
NB. one, else fall back to the provider default.
adopt_context_window =: monad define
  w =. model_context_window ''
  MODEL_WINDOW =: w
  if. 0 < w do.
    MAX_TOKENS =: w
    echo 'Context budget: ' , (": w) , ' tokens (model listing)'
  else.
    MAX_TOKENS =: context_limit ''
    echo 'Context budget: ' , (": MAX_TOKENS) , ' tokens (provider default)'
  end.
)


NB. Update networking configuration based on active MODEL
update_config_state =: monad define
  NB. If y is non-empty, update MODEL; otherwise use existing MODEL
  if. 0 < #y do. MODEL =: y end.

  PROVIDER =: infer_provider MODEL
  NB. Set context window limit based on provider/model
  MAX_TOKENS =: context_limit ''
  NB. Set API_URL based on PROVIDER
  API_URL =: ''
  select. PROVIDER
  case. 'openrouter' do. API_URL =: API_URL_openrouter
  case. 'anthropic' do. API_URL =: API_URL_anthropic
  case. 'cohere' do. API_URL =: API_URL_cohere
  case. 'google' do. API_URL =: API_URL_google
  case. 'local' do. API_URL =: API_URL_local
  case. 'ollama' do. API_URL =: API_URL_ollama
  case. 'tcm' do. API_URL =: API_URL_tcm
  case. 'hyai' do. API_URL =: API_URL_hyai
  case. 'mistral' do. API_URL =: API_URL_mistral
  case. 'xai' do. API_URL =: API_URL_xai
  case. do. API_URL =: API_URL_openrouter end.
  
  NB. Set ENV_KEY based on PROVIDER
  env =: ''
  select. PROVIDER
  case. 'openrouter' do. env =: ENV_KEY_openrouter
  case. 'anthropic' do. env =: ENV_KEY_anthropic
  case. 'cohere' do. env =: ENV_KEY_cohere
  case. 'google' do. env =: ENV_KEY_google
  case. 'local' do. env =: ENV_KEY_local
  case. 'ollama' do. env =: ENV_KEY_ollama
  case. 'tcm' do. env =: ENV_KEY_tcm
  case. 'hyai' do. env =: ENV_KEY_hyai
  case. 'mistral' do. env =: ENV_KEY_mistral
  case. 'xai' do. env =: ENV_KEY_xai
  case. do. env =: ENV_KEY_openrouter end.
  
  NB. Allow environment variables to override endpoints for self-hosted LLMs
  try.
    if. PROVIDER -: 'local' do.
      if. 0 < # > 2!:5 'LOCAL_API_URL' do. API_URL =: > 2!:5 'LOCAL_API_URL' end.
    elseif. PROVIDER -: 'ollama' do.
      if. 0 < # > 2!:5 'OLLAMA_API_URL' do. API_URL =: > 2!:5 'OLLAMA_API_URL' end.
    end.
  catch. end.

  NB. API key management policy:
  NB.   Keys are read from ~/.jpi_providers only (chmod 600 on load).
  NB.   Keys are NEVER read from environment variables. This is deliberate:
  NB.   env vars are visible to all child processes — any bash command or
  NB.   MCP tool the LLM runs could exfiltrate keys via `env` or
  NB.   /proc/self/environ. The file-based approach limits key access to
  NB.   jpi's own process. Keys are passed to curl via -K config file
  NB.   (see http.ijs), not on the command line, so they don't appear in
  NB.   ps aux either. The header config file is erased after each request.
  NB.
  NB.   URL overrides (LOCAL_API_URL, OLLAMA_API_URL) DO read env vars —
  NB.   URLs are not secrets, so this is safe and convenient for self-hosted
  NB.   LLMs.
  try.
    name =. env , '_VAL'
    if. 0 = 4!:0 < name do.
      val =. ". name
      if. (2 = 3!:0 val) *. 0 < #val do.
        API_KEY =: val
        NB. NO early return here: a return skipped the API_KEY
        NB. normalization below AND the persistent context-budget
        NB. preference at the end of this verb - the pref never
        NB. applied at load because the key was always found.
        NB. Falling through is harmless: normalization just
        NB. validates, and the pref must run.
      end.
    end.
  catch. end.

  NB. Ensure API_KEY is defined and valid
  try.
    if. 0 = # API_KEY do. API_KEY =: '' end.
    if. 2 ~: 3!:0 API_KEY do. API_KEY =: '' end.
    if. '0' -: API_KEY do. API_KEY =: '' end.
  catch. API_KEY =: '' end.

  NB. apply the user's persistent context-budget preference
  try. apply_context_pref '' catch. end.
)

NB. Persistent context-budget preference (~/.jpi_context): a
NB. NUMBER, pinned by /context N or by /context auto (which
NB. looks up the current model's advertised window and pins
NB. THAT number). Numbers only - applied at every startup via
NB. update_config_state: instant, offline, deterministic, no
NB. network at load, no bench contamination. Switch models and
NB. want the new window? Re-run /context auto once.
CONFIG_CONTEXT_FILE =: (2!:5 'HOME') , '/.jpi_context'
apply_context_pref =: monad define
  if. -. fexist CONFIG_CONTEXT_FILE do. return. end.
  p =. deb fread CONFIG_CONTEXT_FILE
  if. 0 = # p do. return. end.
  n =. (". :: 0:) p
  if. (0 < # , n) *. 0 < n do.
    MAX_TOKENS =: n
  end.
  ''
)

NB. Helper to check if an API key exists in ~/.jpi_providers
has_api_key =: monad define
  k =. y , '_VAL'
  if. 0 = 4!:0 < k do.
    v =. ". k
    (2 = 3!:0 v) *. 0 < # v
  else.
    0
  end.
)

NB. Helper to get an API key from ~/.jpi_providers
get_api_key =: monad define
  k =. y , '_VAL'
  if. 0 = 4!:0 < k do. ": ". k return. end.
  ''
)
CONFIG_MODEL_FILE =: (2!:5 'HOME') , '/.jpi_model'
CONFIG_PROVIDERS_FILE =: (2!:5 'HOME') , '/.jpi_providers'

NB. Load saved model from disk if present
load_model =: monad define
  try.
    NB. Only load from file if MODEL is not already set
    model_set =. 0
    try. model_set =. (0 < #MODEL) catch. end.
    if. -. model_set do.
      if. fexist CONFIG_MODEL_FILE do.
        m =. fread CONFIG_MODEL_FILE
        if. 0 < #m do.
          MODEL =: m -. 10 13 { a.
        end.
      end.
    end.
    if. fexist CONFIG_PROVIDERS_FILE do.
      NB. Ensure tight permissions — file contains API keys in plaintext.
      2!:0 'chmod 600 ' , CONFIG_PROVIDERS_FILE
      prov =. fread CONFIG_PROVIDERS_FILE
      if. 0 < #prov do.
        lines =. <;._2 prov, (LF -. {: prov) # LF
        for_l. lines do.
          line =. > l
          if. 0 = #line do. continue. end.
          if. '#' = {. line do. continue. end.
          idx =. line i. '='
          if. idx < #line do.
            k =. > idx {. line
            v =. > (idx+1) }. line
            name =. k , '_VAL'
            (name) =: v
          end.
        end.
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

NB. ----------------------------------------------------------------
NB. Thinking configuration for reasoning models.
NB. THINK_ON: 1 = thinking enabled, 0 = disabled.
NB. THINK_BUDGET: max thinking tokens, 0 = unlimited (provider default).
NB. Only providers whose API exposes a thinking parameter consume these
NB. (see thinking_param in llm.ijs); others ignore them.
THINK_ON =: 1
THINK_BUDGET =: 0
CONFIG_THINK_FILE =: (2!:5 'HOME') , '/.jpi_think'

NB. Load saved thinking config: file holds 'on budget' as one line
NB. (e.g. '1 2000'). Malformed or missing file keeps the defaults.
NB. ". returns an empty noun silently for non-noun do-strings, so
NB. guard on the item count before using the result.
load_think =: monad define
  try.
    if. fexist CONFIG_THINK_FILE do.
      t =. fread CONFIG_THINK_FILE
      t =. t -. 10 13 { a.
      if. 0 < #t do.
        v =. ". t
        if. 2 = #v do.
          THINK_ON =: {. v
          THINK_BUDGET =: {: v
        end.
      end.
    end.
  catch. end.
)
load_think ''

NB. Save current thinking config to disk
save_think =: monad define
  ((": THINK_ON) , ' ' , ": THINK_BUDGET) fwrite CONFIG_THINK_FILE
)

NB. Name of the key line in ~/.jpi_providers. '' when unknown.
provider_key_name =: monad define
  select. tolower deb y
  case. 'openrouter' do. 'OPENROUTER_API_KEY'
  case. 'anthropic' do. 'ANTHROPIC_API_KEY'
  case. 'cohere' do. 'COHERE_API_KEY'
  case. 'google' do. 'GEMINI_API_KEY'
  case. 'mistral' do. 'MISTRAL_API_KEY'
  case. 'xai' do. 'XAI_API_KEY'
  case. 'hyai' do. 'HYAI_API_KEY'
  case. 'tcm' do. 'TCM_API_KEY'
  case. 'local' do. 'LOCAL_API_KEY'
  case. 'ollama' do. 'OLLAMA_API_KEY'
  case. do. '' end.
)

NB. Read the providers file into boxed lines. Empty when absent.
providers_lines =: monad define
  if. -. fexist CONFIG_PROVIDERS_FILE do. 0 $ <'' return. end.
  raw =. fread CONFIG_PROVIDERS_FILE
  if. (2 ~: 3!:0 raw) +. 0 = # raw do. 0 $ <'' return. end.
  <;._2 raw , (LF -. {: raw) # LF
)

NB. Write lines back and keep the file private. The value is
NB. not echoed.
providers_write =: monad define
  text =. ''
  if. 0 < # y do. text =. ; y ,each <LF end.
  text fwrite CONFIG_PROVIDERS_FILE
  try. 2!:0 'chmod 600 ' , CONFIG_PROVIDERS_FILE catch. end.
  ''
)

NB. y = keyname ; value. Insert or replace that line.
providers_put =: monad define
  'k v' =. y
  lines =. providers_lines ''
  out =. 0 $ <''
  found =. 0
  for_l. lines do.
    line =. > l
    idx =. line i. '='
    if. (idx < # line) *. k -: idx {. line do.
      out =. out , < k , '=' , v
      found =. 1
    else.
      out =. out , < line
    end.
  end.
  if. -. found do. out =. out , < k , '=' , v end.
  providers_write out
)

NB. Remove the line for this key name.
providers_drop =: monad define
  lines =. providers_lines ''
  out =. 0 $ <''
  for_l. lines do.
    line =. > l
    idx =. line i. '='
    if. (idx < # line) *. y -: idx {. line do. continue. end.
    out =. out , < line
  end.
  providers_write out
)

NB. /login [provider]. The key is read with echo off and only
NB. its length is shown. An empty entry cancels.
login_provider =: monad define
  p =. deb tolower y
  if. 0 = # p do. p =. PROVIDER end.
  keyname =. provider_key_name p
  if. 0 = # keyname do.
    echo 'Unknown provider: ' , p
    echo 'Providers: openrouter anthropic cohere google mistral xai hyai tcm local ollama'
    return.
  end.
  wasraw =. 0
  if. 3 = 4!:0 <'raw' do.
    raw 0
    wasraw =. 1
  end.
  ansfile =. '/tmp/jpi_login_' , (6!:0 'hhmmss')
  cmd =. 'trap "stty echo </dev/tty 2>/dev/null" EXIT; stty -echo </dev/tty; printf "%s" "API key for ' , p , ' (input hidden): " >/dev/tty; IFS= read -r ans </dev/tty; printf "\n" >/dev/tty; printf "%s" "$ans" > ' , ansfile
  try. 2!:0 cmd catch. end.
  if. wasraw do. raw 1 end.
  key =. ''
  if. fexist ansfile do.
    key =. fread ansfile
    ferase ansfile
    if. 2 ~: 3!:0 key do. key =. '' end.
  end.
  key =. key -. CR , LF
  if. 0 = # key do.
    echo 'Login cancelled.'
    return.
  end.
  providers_put keyname ; key
  (keyname , '_VAL') =: key
  if. p -: PROVIDER do. API_KEY =: key end.
  echo 'Saved ' , keyname , ' (' , (": # key) , ' characters).'
)

NB. /logout [provider]. Removes that one line.
logout_provider =: monad define
  p =. deb tolower y
  if. 0 = # p do. p =. PROVIDER end.
  keyname =. provider_key_name p
  if. 0 = # keyname do.
    echo 'Unknown provider: ' , p
    return.
  end.
  providers_drop keyname
  (keyname , '_VAL') =: ''
  if. p -: PROVIDER do. API_KEY =: '' end.
  echo 'Removed ' , keyname , '.'
)

echo 'config loaded. Provider: ' , PROVIDER , '  API_KEY length: ' , ": #API_KEY
