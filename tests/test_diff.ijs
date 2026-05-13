NB. Test diff display on edits
load '../src/agent.ijs'

test_diff =: monad define
  NB. create test file with several lines
  content =. 'line 1' , LF , 'line 2' , LF , 'line 3' , LF , 'hello world' , LF , 'line 5' , LF , 'line 6' , LF , 'line 7'
  content fwrites '/tmp/diff_test.txt'
  echo '--- Before ---'
  echo fread '/tmp/diff_test.txt'
  echo ''
  echo '--- Edit with diff ---'
  echo edit_file '/tmp/diff_test.txt' ; 'hello world' ; 'goodbye earth'
  echo ''
  echo '--- After ---'
  echo fread '/tmp/diff_test.txt'
  ferase '/tmp/diff_test.txt'
)

test_diff ''
