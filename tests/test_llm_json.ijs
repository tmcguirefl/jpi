NB. Unit test: mk_tool and get_tools JSON output
require 'convert/json'

PROVIDER =: 'openrouter'

NB. load llm which defines mk_tool, get_tools, build_payload
load '../src/config.ijs'
load '../src/log.ijs'
load '../src/safety.ijs'
load '../src/read_file.ijs'
load '../src/run_cmd.ijs'
load '../src/edit_file.ijs'
load '../src/write_file.ijs'
load '../src/llm.ijs'

echo '--- Test: mk_tool single ---'
echo 'parameters' mk_tool 'read';'Read file';'{"type":"object"}'
echo ''

echo '--- Test: get_tools (openrouter) ---'
echo get_tools ''
echo ''

echo '--- Test: build_payload ---'
echo build_payload 'what is J'
echo ''

echo 'All tests done.'
