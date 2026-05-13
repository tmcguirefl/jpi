# LLM Integration

## New Components
- `src/config.ijs` — loads API key from `ANTHROPIC_API_KEY` env var
- `src/http.ijs` — curl-based HTTP POST for JSON APIs
- `src/llm.ijs` — Claude API integration (tool definitions, payload building, `llm_ask`)
- `src/tool_exec.ijs` — executes tool calls from LLM responses using `gethash_json`

## Setup
```bash
export ANTHROPIC_API_KEY='sk-ant-...'
cd jpi/src
jconsole
```
```j
   load 'main.ijs'
   run_agent ''
```

## Usage
```
read somefile.txt        NB. direct file read
run ls -la               NB. direct shell command
ask what files are here  NB. sends question to Claude API
exit
```

## Architecture
```
User → agent.ijs → chopstring + i. + agenda
                     ├─ read/run/edit/write (direct tools)
                     └─ ask → llm.ijs → curl → Claude API
                                            → tool_exec.ijs (if tool_use response)
```
