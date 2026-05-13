NB. Basic ncurses test — does it load and init?
require 'api/ncurses'

test_init =: monad define
  echo 'ncurses library: ' , > libncurses
  NB. try to init
  stdscr =: initscr ''
  echo 'stdscr: ' , ": stdscr
  if. 0 = stdscr do.
    echo 'FAILED: initscr returned null'
    return.
  end.
  cbreak ''
  noecho ''
  NB. check screen size
  rows =. {. 2 ic 2!:0 'tput lines'
  cols =. {. 2 ic 2!:0 'tput cols'
  NB. draw something
  move 0 0
  addstr < 'J-PI TUI Test'
  move 1 0
  addstr < 'Press any key to exit...'
  refresh ''
  NB. wait for key
  getch ''
  endwin ''
  echo 'ncurses test passed.'
)

test_init ''
