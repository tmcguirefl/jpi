srcdir =. 2!:5 'JPI_SRC'

NB. Spin up worker threads so J can transparently parallelise array primitives
NB. and any future t.-modified verb. Canonical J idiom: spawn (cores-2) workers
NB. on first call. Wrapped in a dfn-level try/catch so old J builds with no
NB. thread support fall back silently to single-threaded operation.
3 : 0 ''
  try.
    {{0 T. 0}}^:] _2&+ {. 8 T. ''
  catch. end.
  i. 0 0
)

load srcdir , '/tui.ijs'
tui_run ''
