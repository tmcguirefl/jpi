NB. lineio.ijs - line-by-line stdin for J, via libc read(2) on fd 0
NB.
NB. Why this module exists: J has NO portable way to read piped
NB. stdin one line at a time. 1!:1[1 is the script stream (reads
NB. the running script, or throws on a pipe), 1!:1 </dev/stdin
NB. reads to EOF (batch only), and child-process line readers
NB. (head -n 1) over-read the pipe and lose the excess. The fix:
NB. call libc read(2) on fd 0 directly and buffer in J - the fd
NB. offset is ours, so nothing is lost and no line is over-read.
NB.
NB. Bonus: lines built from a plain J buffer match with -: (the
NB. mapped/utf8-flagged literal problem of 1!:1/fread does not
NB. apply - 'x' -: stdin_read_line'' is a reliable test).
NB.
NB. Consumers: pi_rpc (interactive JSONL), the klj Shen REPL
NB. (repl.ijs), and any J REPL driven over a pipe. Blocking
NB. semantics: reads wait for data; EOF returns ''. A terminal in
NB. cooked mode delivers one line per read(2), so interactive use
NB. works too.
NB.
NB. Standalone: only needs unxlib (ships with J). No other module
NB. is required.

NB. libc handle (unxlib ships with J)
lio_libc =: unxlib 'c'

NB. read(fd, bufsize) -> data; '' on EOF or error
NB. Same binding as jpi's mcp.ijs sys_read (kept separate so this
NB. module loads without the MCP stack).
lio_read =: dyad define
  buf =. y # ' '
  rres =. (lio_libc , ' read l i *c l')&cd x ; buf ; y
  nread =. > 0 { rres
  if. nread < 0 do. '' return. end.
  nread {. > 2 { rres
)

NB. leftover bytes from a previous read (lines are cut here)
STDIN_BUF =: ''

NB. read one line (up to LF) from fd 0. '' at EOF. The line
NB. excludes the LF; a final line without LF is returned at EOF.
NB. Leftover bytes stay buffered for the next call.
stdin_read_line =: monad define
  while. -. LF e. STDIN_BUF do.
    chunk =. 0 lio_read 4096
    if. 0 = # chunk do. break. end.
    STDIN_BUF =: STDIN_BUF , chunk
  end.
  if. 0 = # STDIN_BUF do. '' return. end.
  d =. STDIN_BUF i. LF
  if. d < # STDIN_BUF do.
    line =. d {. STDIN_BUF
    STDIN_BUF =: (d + 1) }. STDIN_BUF
  else.
    line =. STDIN_BUF
    STDIN_BUF =: ''
  end.
  line
)

NB. drop any buffered input (e.g. between REPL commands)
stdin_reset =: monad define
  STDIN_BUF =: ''
  ''
)
