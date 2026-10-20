NB. http_async_cancel kills the background process group.
NB. Run from src/:  jconsole < ../tests/test_http_cancel.ijs
old =. 1!:43 ''
1!:44 '/Users/tomdevel/jdev/jpi/src'
load 'http.ijs'
1!:44 old

still_alive =: monad define
  try.
    2!:0 'ps -p ' , y , ' >/dev/null'
    1
  catch.
    0
  end.
)

main =: monad define
  pid =. deb (2!:0 'set -m; (sleep 30) </dev/null & echo $!') -. CR , LF
  pid fwrite HTTP_PID_FILE
  http_async_cancel ''
  if. still_alive pid do.
    try.
      2!:0 'kill -TERM -' , pid , ' 2>/dev/null || kill -TERM ' , pid , ' 2>/dev/null || true'
    catch.
    end.
    echo 'FAIL: sleep ' , pid , ' still running'
    echo 'TESTS FAILED'
  else.
    echo 'cancel killed ' , pid
    echo 'ALL TESTS PASSED'
  end.
  ''
)

main ''
exit 0
