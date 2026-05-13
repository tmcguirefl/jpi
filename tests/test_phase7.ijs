NB. Phase 7 Tests: End-to-end integration
load '../src/agent.ijs'

echo 'Running Phase 7 end-to-end tests...'

NB. ----------------------------------------------------------------
NB. Test 1: Write a file, read it back, edit it, read again
testfile =. 'test_e2e.txt'

echo 'Step 1: Write file'
assert. 1 = write_file testfile ; 'Hello World'

echo 'Step 2: Read file'
content =. read_file_str testfile
assert. 'Hello World' -: content
echo 'Read back: ', content

echo 'Step 3: Edit file'
assert. 1 = edit_file testfile ; 'World' ; 'J-PI'

echo 'Step 4: Read edited file'
content2 =. read_file_str testfile
assert. 'Hello J-PI' -: content2
echo 'After edit: ', content2

ferase testfile

NB. ----------------------------------------------------------------
NB. Test 2: Safety check blocks dangerous commands
echo 'Step 5: Safety checks'
assert. 1 = is_safe 'ls -la'
assert. 0 = is_safe 'rm -rf /'
assert. 0 = is_safe 'dd if=/dev/zero'
echo 'Safety tests passed.'

NB. ----------------------------------------------------------------
NB. Test 3: Agent dispatch
echo 'Step 6: Agent dispatch'
agent 'run echo hello from agent'

NB. ----------------------------------------------------------------
NB. Test 4: Logging
echo 'Step 7: Log check'
assert. fexist LOGFILE
echo 'Log file exists: ', LOGFILE

NB. Cleanup
ferase LOGFILE

echo 'All Phase 7 tests passed!'
