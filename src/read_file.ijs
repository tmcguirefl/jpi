NB. Phase 2: File Reading Tool
NB. read_file.ijs

NB. read_file: reads text file, optional max lines (y = filename; [x = max lines])
NB. Returns boxed list of lines (empty box on error)
read_file =: 3 : 0
  100 read_file y
:
  max =. x
  try.
    lines =. 1!:0 < y
    if. 0 = #lines do. <'' return. end.
    if. max > #lines do. max =. #lines end.
    <@,". each max {. lines
  catch.
    <'ERROR: could not read ', y
  end.
)

NB. Convenience wrapper that returns a single string (with newlines)
read_file_str =: 3 : 0
  ; read_file y
)

echo 'Phase 2: read_file loaded.'