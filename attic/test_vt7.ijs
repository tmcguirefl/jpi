NB. Minimal test: exact tui2 pattern but with debug output
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
  'rows cols' =. gethw_vt_''
  raw_vt_ 1
  
  NB. Clear screen
  out (CSI,'2J')
  out (CSI,'H')
  
  NB. Draw 3 lines at specific rows
  out (CSI,'38;5;7m')
  out 'Row 0: Welcome',CR,LF
  
  out (CSI,'0m')
  out 'Row 1: Terminal is ',(": rows),'x',(": cols),CR,LF
  
  out (CSI,'38;5;2m')
  out 'Row 2: Press q to quit',CR,LF
  
  NB. Status bar
  out (CSI,(": rows-1),';1f')
  out (CSI,'48;5;6m')
  out (CSI,'38;5;0m')
  out ' Status bar here ',CR,LF
  
  NB. Input line
  out (CSI,(": rows),';1f')
  out (CSI,'38;5;6m')
  out '> ',CR,LF
  
  out (CSI,'0m')
  out (CSI,(": rows),';4f')
  out (CSI,'?25h')
  
  NB. Main loop — exact same pattern as tui2
  running =. 1
  while. running do.
    if. keyp_vt_ 100 do.
      k =. inp ''
      out (CSI,'38;5;7m')
      out 'Key: ',(": k),CR,LF
      if. k = (a. i. 'q') do. running =. 0 end.
    else.
      6!:3 (0.05)
    end.
  end.
  
  raw_vt_ 0
  out (CSI,'0m')
  out CR,LF
)

test ''
