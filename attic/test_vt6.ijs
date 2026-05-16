NB. Test: use keyp_vt_ for polling + fd 0 for reading
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

U =: unxlib 'c'

NB. Write to fd 1
out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)

NB. Read one byte from fd 0
inp =: monad define
  buf =. (,0){a.
  res =. (U,' read l i *c l')&cd (0 ; buf ; 1)
  a. i. 0 { 2 {:: res
)

ESC =: 27{a.
CSI =: ESC,'['

test =: monad define
  'rows cols' =. gethw_vt_''
  raw_vt_ 1
  
  out (CSI,'2J')
  out (CSI,'H')
  
  out (CSI,'38;5;7m')
  out '=== Test: keyp_vt_ + fd0 read ===',CR,LF
  
  out (CSI,'0m')
  out 'Press q to quit',CR,LF
  
  while. 1 do.
    if. keyp_vt_ 100 do.
      k =. inp ''
      out (CSI,'38;5;7m')
      out 'Got key: ',(": k),CR,LF
      if. k = (a. i. 'q') do. break. end.
    end.
  end.
  
  raw_vt_ 0
  out (CSI,'0m')
  out (CSI,'?25h')
  out CR,LF
)

test ''
