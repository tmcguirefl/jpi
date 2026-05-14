NB. Theme system for TUI
NB. theme.ijs

NB. Theme is a table of named color pairs: name;fg;bg
NB. ncurses color constants (from ncurses addon):
NB.   0=BLACK 1=RED 2=GREEN 3=YELLOW 4=BLUE 5=MAGENTA 6=CYAN 7=WHITE

NB. ================================================================
NB. Theme definitions — each is a 2-column table: name;(fg,bg)

THEME_DEFAULT =: _2 ]\ 'normal';(7,0);'status';(0,6);'tool';(2,0);'error';(1,0);'prompt';(6,0);'muted';(3,0);'diff_add';(2,0);'diff_del';(1,0)

THEME_DARK =: _2 ]\ 'normal';(7,0);'status';(7,4);'tool';(2,0);'error';(1,0);'prompt';(5,0);'muted';(3,0);'diff_add';(2,0);'diff_del';(1,0)

THEME_LIGHT =: _2 ]\ 'normal';(0,7);'status';(7,4);'tool';(2,7);'error';(1,7);'prompt';(4,7);'muted';(3,7);'diff_add';(2,7);'diff_del';(1,7)

THEME_OCEAN =: _2 ]\ 'normal';(6,0);'status';(0,6);'tool';(2,0);'error';(1,0);'prompt';(4,0);'muted';(3,0);'diff_add';(2,0);'diff_del';(5,0)

NB. Available themes
THEMES =: _2 ]\ 'default';THEME_DEFAULT;'dark';THEME_DARK;'light';THEME_LIGHT;'ocean';THEME_OCEAN

NB. Current theme
CURRENT_THEME =: THEME_DEFAULT

NB. ================================================================
NB. Color pair index by name — CP_NORMAL=1, etc.
NB. Maps theme entry index to ncurses color pair number (1-based)

NB. Look up fg,bg for a theme entry by name
theme_colors =: monad define
  NB. y = name string
  idx =. ({."1 CURRENT_THEME) i. < y
  if. idx < #CURRENT_THEME do.
    > (<idx,1) { CURRENT_THEME
  else.
    7 , 0    NB. fallback: white on black
  end.
)

NB. Apply current theme to ncurses color pairs
apply_theme =: monad define
  for_i. i. {. $ CURRENT_THEME do.
    'fg bg' =. > (<i,1) { CURRENT_THEME
    NB. color pair numbers are 1-based (i+1)
    init_pair_ncurses_ (i+1) , fg , bg
  end.
)

NB. Switch to a named theme
set_theme =: monad define
  idx =. ({."1 THEMES) i. < y
  if. idx >: {. $ THEMES do.
    echo 'Unknown theme: ' , y , '. Available: ' , _1 }. ; (,&' ') each {."1 THEMES
    return.
  end.
  CURRENT_THEME =: > (<idx,1) { THEMES
  apply_theme ''
  echo 'Theme set to: ' , y
)

NB. List available themes
list_themes =: monad define
  echo 'Available themes: ' , _1 }. ; (,&' ') each {."1 THEMES
)

NB. Get the color pair number for a named element
NB. Returns 1-based index for use with COLOR_PAIR_ncurses_
theme_cp =: monad define
  1 + ({."1 CURRENT_THEME) i. < y
)

echo 'theme loaded.'
