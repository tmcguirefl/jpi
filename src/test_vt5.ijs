NB. Test writing to fd 1 vs fd 0 for ANSI escape codes
load 'agent.ijs'
require 'tangentstorm/j-kvm/vt'

u =: unxlib 'c'

NB. Our own puts that writes to fd 1 (stdout)
my_puts =: monad define
  0 0 $ (u,' write n i &c l')&cd (1 ; , y ; #y)
)

test_render =: monad define
  'h w' =. gethw_vt_''
  raw_vt_ 1
  cscr_vt_''
  curs_vt_ 0
  
  NB. Line 0: using our fd 1 write (should work)
  my_puts (27{a.),'[' , '0m'           NB. reset
  my_puts (27{a.),'[' , '38;5;7m'     NB. 256-color white fg
  my_puts 'Line 0: fd 1 write — white text'
  my_puts CR,LF
  
  NB. Line 1: using puts_vt_ (writes to fd 0 — might break)
  goxy_vt_ 0 , 1
  reset_vt_''
  fgc_vt_ _7
  puts_vt_ 'Line 1: puts_vt_ (fd 0) — white text'
  my_puts CR,LF
  
  NB. Line 2: using fd 1 write
  goxy_vt_ 0 , 2
  my_puts (27{a.),'[' , '38;5;2m'     NB. green
  my_puts 'Line 2: fd 1 write — green text'
  my_puts CR,LF
  
  NB. Line 3: using fd 1 write with bg
  goxy_vt_ 0 , 3
  my_puts (27{a.),'[' , '48;5;6m'     NB. cyan bg
  my_puts (27{a.),'[' , '38;5;0m'     NB. black fg
  my_puts 'Line 3: fd 1 write — black on cyan'
  my_puts CR,LF
  
  NB. Status bar
  goxy_vt_ 0 , (h - 2)
  my_puts (27{a.),'[' , '48;5;6m'
  my_puts (27{a.),'[' , '38;5;0m'
  my_puts ' Status bar here '
  my_puts (27{a.),'[' , '0m'
  
  NB. Input line
  goxy_vt_ 0 , (h - 1)
  my_puts (27{a.),'[' , '38;5;6m'
  my_puts '> '
  my_puts (27{a.),'[' , '0m'
  my_puts 'press q to quit'
  
  goxy_vt_ 23 , (h - 1)
  curs_vt_ 1
  
  NB. Read loop from fd 0
  while. 1 do.
    buf =. (,0){a.
    res =. (u,' read l i *c l')&cd (0 ; buf ; 1)
    k =. a. i. 0 { 2 {:: res
    if. k = (a. i. 'q') do. break. end.
  end.
  
  raw_vt_ 0
  curs_vt_ 1
  reset_vt_''
)

test_render ''
