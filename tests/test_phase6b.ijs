NB. Phase 6 (revised) Tests
load '../src/agent.ijs'

echo 'Testing revised agent with boxed selection + agenda...'

NB. Show indexed lookup works
echo 'read index: ', ": get_action_index 'read the file'
echo 'run index : ', ": get_action_index 'run ls'
echo 'edit index: ', ": get_action_index 'edit foo'
echo 'unknown index:', ": get_action_index 'foo bar'

NB. Live demo of agenda dispatch
echo '--- Demo runs ---'
agent 'read something'
agent 'run ls'
agent 'edit the code'
agent 'write a new file'
agent 'xyzzy'

echo 'Phase 6 revised tests done.'