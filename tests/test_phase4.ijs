NB. Phase 4 Tests: Precise File Editing
load '../src/edit_file.ijs'

echo 'Running Phase 4 tests...'

testfile =. 'test_edit.txt'
'This is the original text.' 1!:2 <testfile

success =. edit_file testfile ; 'original' ; 'edited'
assert. success = 1

result =. fread testfile
assert. result -: 'This is the edited text.'
echo 'Edit test passed.'

ferase testfile
echo 'All Phase 4 tests passed!'