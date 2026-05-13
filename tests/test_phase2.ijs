NB. Phase 2 Tests: File Reading Tool
load '../src/read_file.ijs'

echo 'Running Phase 2 tests...'

NB. Create a temp test file
testfile =. 'test_read.txt'
('Hello World',LF,'Line two',LF,'Third line') 1!:2 <testfile

NB. Basic read returns boxed lines
result =. read_file testfile
assert. 3 = #result
assert. 'Hello World' -: 0 { result
echo 'Basic read test passed.'

NB. Limited lines (2)
result2 =. 2 read_file testfile
assert. 2 = #result2
assert. 'Line two' -: 1 { result2
echo 'Limited lines test passed.'

NB. String version
str =. read_file_str testfile
assert. 'Hello World' -: 10 {. str
echo 'String read test passed.'

NB. Cleanup
1!:55 <testfile

echo 'All Phase 2 tests passed!'