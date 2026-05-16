NB. Test: tui_redraw logic exactly
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

goxy =: monad define
  'col row' =. y
  out CSI , (": row+1) , ';' , (": col+1) , 'f'
)

ceol =: monad define
  out CSI , '0K'
)

cscr =: monad define
  out (CSI,'2J')
  out (CSI,'H')
)

reset =: monad define
  out (CSI,'0m')
)

fgc =: monad define
  out CSI , '38;5;' , (": -y) , 'm'
)

bgc =: monad define
  out CSI , '48;5;' , (": -y) , 'm'
)

NB. Global state
T_LINES =: 0
T_COLS  =: 0
T_OUTPUT =: 0 $ <''
STATUS_H =: 1
INPUT_H  =: 1

wrap_line =: dyad define
  if. x >: #y do. ,< y return. end.
  r =. 0 $ <''
  while. x < #y do.
    r =. r , < x {. y
    y =. x }. y
  end.
  r , < y
)

tui_print =: verb define
  'normal' tui_print y
:
  wrapped =. (T_COLS - 1) wrap_line y
  T_OUTPUT =: T_OUTPUT , wrapped
)

theme_apply =: monad define
  'fg bg' =. theme_colors y
  fgc fg
  bgc bg
)

tui_redraw =: monad define
  out_h =. T_LINES - STATUS_H + INPUT_H
  total =. #T_OUTPUT
  start =. 0 >. total - out_h
  visible =. out_h {. start }. T_OUTPUT
  
  cscr ''
  reset ''
  
  for_i. i. #visible do.
    goxy 0 , i
    out > i { visible
  end.
  
  for_i. (#visible) + i. out_h - #visible do.
    goxy 0 , i
    ceol ''
  end.
  
  NB. Status bar
  goxy 0 , out_h
  theme_apply 'status'
  left =. ' J-PI | ' , MODEL
  right =. ' press q to quit '
  pad =. (T_COLS - (#left) + #right) # ' '
  out left , pad , right
  reset ''
  
  NB. Input line
  goxy 0 , (out_h + STATUS_H)
  theme_apply 'prompt'
  out '> '
  reset ''
  out 'type here'
  ceol ''
  
  goxy 0 , (out_h + STATUS_H)
  out CSI , '?25h'
)

test =: monad define
  raw_vt_ 1
  'T_LINES T_COLS' =: gethw_vt_''
  
  'prompt' tui_print '=== Redraw Test ==='
  'muted' tui_print 'Press q to quit'
  tui_print ''
  
  tui_redraw ''
  
  running =. 1
  while. running do.
    k =. inp ''
    if. k = (a. i. 'q') do. running =. 0 end.
  end.
  
  raw_vt_ 0
  reset ''
  out CR,LF
)

test ''
