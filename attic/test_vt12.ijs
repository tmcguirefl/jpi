NB. Debug: what does tui_in actually return when called from tui2's context?
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'
load 'theme.ijs'

U =: unxlib 'c'

out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)

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
  
  out (CSI,'2J'),(CSI,'H')
  out (CSI,'38;5;7m'),'Debug test',CR,LF
  out (CSI,'0m'),'Testing tui_in return value...',CR,LF
  
  NB. Call inp 3 times and show what we get
  out 'Waiting for 3 keypresses...',CR,LF
  
  for_i. i. 3 do.
    k =. inp ''
    out 'Got: ',(": k),CR,LF
  end.
  
  out 'Now entering main loop, press q to quit',CR,LF
  
  running =. 1
  while. running do.
    k =. inp ''
    out 'Key: ',(": k),CR,LF
    if. k = (a. i. 'q') do. running =. 0 end.
  end.
  
  raw_vt_ 0
  out (CSI,'0m'),CR,LF
)

test ''
