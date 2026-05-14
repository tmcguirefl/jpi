NB. Example extension: weather command
NB. Demonstrates custom commands and custom tools
NB.
NB. Usage:
NB.   /weather London        (direct command)
NB.   ask what's the weather  (LLM may call the weather tool)

NB. ================================================================
NB. Custom command: /weather <city>
weather_cmd =: monad define
  if. 0 = #y do. echo 'Usage: /weather <city>' return. end.
  echo 'Weather for ' , y , ': sunny, 22C (example plugin - not real data)'
)

NB. register by verb name string
ext_register_command 'weather' ; 'weather_cmd'

NB. ================================================================
NB. Custom tool: weather (LLM can call this)
weather_tool =: monad define
  NB. y = parsed JSON args from LLM
  city =. > 'city' gethash_json y
  NB. in a real extension you'd call a weather API here
  'Weather for ' , city , ': sunny, 22C (example plugin - not real data)'
)

weather_params =: '{"type":"object","properties":{"city":{"type":"string","description":"City name"}},"required":["city"]}'

NB. register by verb name string
ext_register_tool 'weather' ; 'Get current weather for a city' ; weather_params ; 'weather_tool'
