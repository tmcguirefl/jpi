NB. Minimal rendering test — no key input needed
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

test_render =: monad define
  'h w' =. gethw_vt_''
  raw_vt_ 1
  cscr_vt_''
  curs_vt_ 0
  
  NB. Draw text at specific positions with goxy
  goxy_vt_ 0 , 0
  reset_vt_''
  puts_vt_ '=== Render Test ==='
  
  goxy_vt_ 0 , 1
  fgc_vt_ _7
  puts_vt_ 'White text (256-color 7)'
  
  goxy_vt_ 0 , 2
  fgc_vt_ _2
  puts_vt_ 'Green text (256-color 2)'
  
  goxy_vt_ 0 , 3
  fgc_vt_ _1
  puts_vt_ 'Red text (256-color 1)'
  
  goxy_vt_ 0 , 4
  fgc_vt_ _6
  puts_vt_ 'Cyan text (256-color 6)'
  
  goxy_vt_ 0 , 5
  reset_vt_''
  puts_vt_ 'Default reset text'
  
  goxy_vt_ 0 , 7
  fgc_vt_ _7
  puts_vt_ 'Terminal: ' , (": h) , 'x' , (": w)
  
  NB. Status bar
  goxy_vt_ 0 , (h - 2)
  fgc_vt_ 0
  bgc_vt_ _6
  puts_vt_ ' J-PI | status bar text here '
  reset_vt_''
  
  NB. Input line
  goxy_vt_ 0 , (h - 1)
  fgc_vt_ _6
  puts_vt_ '> '
  reset_vt_''
  puts_vt_ 'type text here'
  
  NB. Move cursor to end of input
  goxy_vt_ 14 , (h - 1)
  curs_vt_ 1
  
  NB. Simple blocking read from fd 0
  u =. unxlib 'c'
  while. 1 do.
    buf =. (,0){a.
    res =. (u,' read l i *c l')&cd (0 ; buf ; 1)
    k =. a. i. 0 { 2 {:: res
    if. k = (a. i. 'q') do. break. end.
    if. k = 10 do.
      NB. Enter
      goxy_vt_ 14 , (h - 1)
      ceol_vt_''
      puts_vt_ 'enter!'
    end.
  end.
  
  raw_vt_ 0
  curs_vt_ 1
  reset_vt_''
)

test_render ''
