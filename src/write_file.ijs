NB. Phase 5: File Writing Tool
NB. write_file.ijs

NB. write_file: writes text file, creating directories if possible
NB. y = filename ; text
write_file =: 3 : 0
  'fn txt' =. y
  try.
    txt fwrites fn
    1
  catch.
    0
  end.
)

NB. write_file_raw uses fwrite (binary)
write_file_raw =: 3 : 0
  'fn txt' =. y
  try.
    txt fwrite fn
    1
  catch.
    0
  end.
)

echo 'Phase 5: write_file loaded.'