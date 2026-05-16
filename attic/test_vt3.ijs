NB. Test reading from fd 0 (stdin) — simplified
require 'tangentstorm/j-kvm/vt'

u =: unxlib 'c'

test_fd =: monad define
  raw_vt_ 1
  cscr_vt_''
  
  goxy_vt_ 0 , 0
  fgc_vt_ _7
  puts_vt_ 'Test: Press any key...'
  
  NB. Wait for keypress
  while. -. keyp_vt_ 100 do. end.
  
  NB. Read from fd 0 (stdin)
  buf0 =. (,0){a.
  res0 =. (u,' read l i *c l')&cd (0 ; buf0 ; 1)
  ch0 =. 0 { 2 {:: res0
  k0 =. a. i. ch0
  
  goxy_vt_ 0 , 2
  puts_vt_ 'fd 0 (stdin) code: ' , ": k0
  
  goxy_vt_ 0 , 4
  puts_vt_ 'Now reading from fd 0 in a loop. Press q to quit.'
  
  while. 1 do.
    buf =. (,0){a.
    res =. (u,' read l i *c l')&cd (0 ; buf ; 1)
    ch =. 0 { 2 {:: res
    k =. a. i. ch
    goxy_vt_ 0 , 5
    ceol_vt_''
    puts_vt_ 'key: ' , ": k
    if. k = (a. i. 'q') do. break. end.
  end.
  
  raw_vt_ 0
  curs_vt_ 1
  reset_vt_''
)

test_fd ''
