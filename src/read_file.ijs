NB. Phase 2: File Reading Tool
NB. read_file.ijs

NB. 'b' freads returns boxed list of lines
NB. read_file: [x = max lines] (default 100), y = filename
read_file =: verb define
  100 read_file y
:
  try.
    lines =. 'b' freads y
    x {. lines
  catch.
    < 'ERROR: could not read ', y
  end.
)

NB. Full file as string
read_file_str =: fread

echo 'read_file loaded.'
