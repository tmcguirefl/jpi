NB. Phase 5: File Writing Tool
NB. write_file.ijs

NB. write_file: y = filename ; text
write_file =: monad define
  'fn txt' =. y
  try.
    txt fwrites fn
    1
  catch.
    0
  end.
)

NB. write_file_raw: binary write
write_file_raw =: monad define
  'fn txt' =. y
  try.
    txt fwrite fn
    1
  catch.
    0
  end.
)

echo 'write_file loaded.'
