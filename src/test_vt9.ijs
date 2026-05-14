NB. Test: does blocking read actually block inside a while loop?
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

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
  raw_vt_ 1
  
  out (CSI,'2J'),(CSI,'H')
  out (CSI,'38;5;7m'),'Blocking loop test',CR,LF
  out (CSI,'0m'),'Press q to quit',CR,LF
  
  running =. 1
  count =. 0
  
  while. running do.
    out (CSI,'3;1f'),(CSI,'0K')
    out 'Loop count: ',(": count),CR,LF
    count =. count + 1
    
    k =. inp ''            NB. This MUST block — does it?
    out 'Got key: ',(": k),CR,LF
    
    if. k = (a. i. 'q') do. running =. 0 end.
  end.
  
  raw_vt_ 0
  out (CSI,'0m'),CR,LF
)

test ''
