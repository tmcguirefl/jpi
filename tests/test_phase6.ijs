NB. Phase 6 Tests: Agent Framework
load '../src/agent.ijs'

echo 'Running Phase 6 tests...'

NB. Test parser
assert. 'read'  -: parse_action 'read something'
assert. 'run'   -: parse_action 'run ls'
assert. 'edit'  -: parse_action 'edit the file'
assert. 'write' -: parse_action 'write this'
echo 'Parser tests passed.'

NB. Basic agent call (mock)
echo 'Agent demo:'
agent 'run ls'

echo 'Phase 6 tests completed.'