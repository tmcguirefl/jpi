NB. Phase 3 Tests: Command Execution Tool
load '../src/run_cmd.ijs'

echo 'Running Phase 3 tests...'

NB. Basic command (cross-platform enough)
result =. run_cmd 'echo hello'
assert. (<'hello') e. result   NB. rough check
echo 'Basic echo command test passed.'

NB. String version
str =. run_cmd_str 'echo test'
assert. 'test' -: 4{. str
echo 'String version test passed.'

echo 'All Phase 3 tests completed.'