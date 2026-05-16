NB. Test: blocking read instead of polling — 0% CPU when idle
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

U =: unxlib 'c'

out =: monad define
  0 0 $ (U,' write n i &c l')&cd (1 ; , y ; #y)
)

inp =: monad define
  NB. Blocking read from fd 0 — sleeps until key available
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
  out 'Row 0: Blocking read test',CR,LF
  out (CSI,'0m')
  out 'Row 1: 0% CPU when idle',CR,LF
  out (CSI,'38;5;2m')
  out 'Row 2: Press q to quit',CR,LF
  
  NB. Status bar
  out CSI,(": rows-1),';1f'
  out (CSI,'48;5;6m'),(CSI,'38;5;0m')
  out ' Status bar here '
  out (CSI,'0m'),CR,LF
  
  NB. Input line
  out CSI,(": rows),';1f'
  out (CSI,'38;5;6m'),'> ',(CSI,'0m')
  out CSI,(": rows),';4f',(CSI,'?25h')
  
  while. 1 do.
    k =. inp ''           NB. blocks here — no CPU used while waiting
    if. k = (a. i. 'q') do. break. end.
    out (CSI,'38;5;7m')
    out 'Key: ',(": k),CR,LF
  end.
  
  raw_vt_ 0
  out (CSI,'0m'),CR,LF
)

test ''
