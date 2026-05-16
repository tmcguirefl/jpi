NB. Step-by-step TUI diagnostic (proper J control flow)
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

test_tui =: monad define
  hw =. gethw_vt_''
  'h w' =. hw
  
  NB. Enter raw mode, clear screen
  raw_vt_ 1
  cscr_vt_''
  
  NB. Draw welcome lines at explicit positions
  goxy_vt_ 0 , 0
  reset_vt_''
  fgc_vt_ _7
  bgc_vt_ 0
  puts_vt_ '=== TUI2 Diagnostic ==='
  
  goxy_vt_ 0 , 1
  puts_vt_ 'Terminal: ' , (": h) , ' rows x ' , (": w) , ' cols'
  
  goxy_vt_ 0 , 2
  puts_vt_ 'Type q to quit, any other key to echo its code'
  
  NB. Input loop
  while. 1 do.
    if. keyp_vt_ 100 do.
      k =. a. i. rkey_vt_''
      goxy_vt_ 0 , 3
      ceol_vt_''
      puts_vt_ 'Key code: ' , ": k
      if. k = (a. i. 'q') do. break. end.
    end.
  end.
  
  NB. Cleanup
  raw_vt_ 0
  curs_vt_ 1
  reset_vt_''
  puts_vt_ CR,LF
)

test_tui ''
