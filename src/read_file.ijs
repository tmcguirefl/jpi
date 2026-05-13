NB. Phase 2: File Reading Tool
NB. read_file.ijs

NB. Uses built-in 'freads' with 'b' option: returns boxed list of lines
NB. read_file: [x = max lines] (default 100), y = filename
read_file =: 3 : 0
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

echo 'Phase 2: read_file loaded.'