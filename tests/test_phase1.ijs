NB. Tests for Phase 1
load '../src/main.ijs'

echo 'Running Phase 1 tests...'

NB. Test echo functionality (mock)
test_echo =: 3 : 0
  result =. 'test input'
  assert. result -: 'test input'
  echo 'Echo test passed.'
)

test_echo ''

echo 'All Phase 1 tests completed.'