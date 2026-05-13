NB. File Reading Tool
NB. read_file.ijs

NB. read_file: read lines from a file with optional offset and limit
NB. y = filename, or filename;offset;limit (boxed)
NB. offset is 1-indexed line number, limit is max lines to return
NB. Returns boxed list of lines
read_file =: monad define
  NB. parse arguments
  args =. boxopen y
  fn =. > 0 { args
  offset =. 1                          NB. default: start at line 1
  limit =. 2000                        NB. default: max 2000 lines
  if. 1 < #args do. offset =. > 1 { args end.
  if. 2 < #args do. limit =. > 2 { args end.
  try.
    lines =. 'b' freads fn
    total =. # lines
    NB. clamp offset to valid range
    offset =. 1 >. offset <. total
    NB. take from offset (1-indexed), limited to limit lines
    chunk =. limit {. (offset - 1) }. lines
    chunk
  catch.
    < 'ERROR: could not read ' , fn
  end.
)

NB. read_file_str: read file as string, optional offset/limit in lines
NB. y = filename or filename;offset;limit
read_file_str =: monad define
  args =. boxopen y
  fn =. > 0 { args
  if. 1 = #args do.
    NB. no offset/limit, read whole file
    fread fn
  else.
    NB. use line-based read, rejoin with LF
    lines =. read_file y
    ; (,&LF) each lines
  end.
)

echo 'read_file loaded.'
