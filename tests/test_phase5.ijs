NB. Phase 5 Tests: File Writing Tool
load '../src/write_file.ijs'

echo 'Running Phase 5 tests...'

testfile =. 'test_write.txt'
txt =. 'Hello Phase 5!'

success =. write_file testfile ; txt
assert. success = 1

content =. fread testfile
assert. content -: txt
echo 'Text write test passed.'

ferase testfile
echo 'All Phase 5 tests passed!'