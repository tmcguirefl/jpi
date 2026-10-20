NB. Paths passed to mkdir, base64, sips, and open are shell-quoted.
NB. Run from src/:  jconsole < ../tests/test_shell_quote.ijs
NB. Control words live in the verb. A one-line try. at the top
NB. level is a spelling error in this J.
old =. 1!:43 ''
1!:44 '/Users/tomdevel/jdev/jpi/src'
load 'write_file.ijs'
load 'image.ijs'
1!:44 old

PASS =: 0
FAIL =: 0
check =: monad define
  if. y do.
    PASS =: >: PASS
  else.
    FAIL =: >: FAIL
    echo '  FAIL'
  end.
)

NB. Run a shell command and ignore a nonzero status.
sh =: monad define
  try.
    2!:0 y
  catch.
    ''
  end.
)

main =: monad define
  lit =. '/tmp/jpi_mkdir_$(echo bad)'
  sh 'rm -rf ' , squote lit
  ensure_dirs lit , '/file.txt'
  check fexist lit
  check -. fexist '/tmp/jpi_mkdir_bad'
  sh 'rm -rf ' , squote lit

  pwn =. '/tmp/jpi_img_pwned'
  ferase < pwn
  image_info '/tmp/jpi_sips_$(touch /tmp/jpi_img_pwned).png'
  check -. fexist pwn
  file_to_base64 '/tmp/jpi_b64_$(touch /tmp/jpi_img_pwned).png'
  check -. fexist pwn

  NB. J rejects '(' in a file name, so the open branch is
  NB. exercised with the same quoted command display_image uses.
  sh 'open ' , squote '/tmp/jpi_open_$(touch /tmp/jpi_img_pwned).png'
  check -. fexist pwn
  ferase < pwn
  ''
)

main ''
report =: monad define
  echo 'Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed'
  if. 0 < FAIL do.
    echo 'TESTS FAILED'
  else.
    echo 'ALL TESTS PASSED'
  end.
)
report ''
exit 0
