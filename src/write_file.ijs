NB. File Writing Tool
NB. write_file.ijs

NB. Extract directory portion of a path (everything up to last /)
dir_of =: monad define
  slashes =. I. '/' = y
  if. 0 = #slashes do. '' return. end.
  ({: slashes) {. y
)

NB. Ensure parent directories exist
ensure_dirs =: monad define
  dir =. dir_of y
  if. 0 < #dir do.
    try. 2!:0 'mkdir -p ' , dir catch. end.
  end.
)

NB. write_file: y = filename ; text
NB. Creates parent directories automatically
write_file =: monad define
  'fn txt' =. y
  try.
    ensure_dirs fn
    txt fwrites fn
    1
  catch.
    0
  end.
)

NB. write_file_raw: binary write with mkdir -p
write_file_raw =: monad define
  'fn txt' =. y
  try.
    ensure_dirs fn
    txt fwrite fn
    1
  catch.
    0
  end.
)

echo 'write_file loaded.'
