NB. Test: does loading tui2.ijs break tui_in?
load 'tui2.ijs'

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
  out (CSI,'38;5;7m'),'After tui2 load test',CR,LF
  out (CSI,'0m'),'Press q to quit',CR,LF
  
  while. 1 do.
    k =. inp ''
    out 'Key: ',(": k),CR,LF
    if. k = (a. i. 'q') do. break. end.
  end.
  
  raw_vt_ 0
  out (CSI,'0m'),CR,LF
)

test ''
