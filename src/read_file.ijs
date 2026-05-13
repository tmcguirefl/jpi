NB. Phase 2: File Reading Tool (revised to use built-in fread)
NB. read_file.ijs

NB. J already supplies the verb 'fread' which reads an entire file
NB. as a character string. We wrap it for line-limited and boxed output.

NB. read_file: y = filename, [x = max lines] (default 100)
NB. Returns boxed list of lines
read_file =: 3 : 0
  100 read_file y
:
  max =. x
  try.
    content =. fread y
    if. 0 = #content do. <'' return. end.
    lines =. <;._2 content,LF
    if. max < #lines do. lines =. max {. lines end.
    < lines
  catch.
    < 'ERROR: could not read ', y
  end.
)

NB. Convenience wrapper returning a single string
read_file_str =: 3 : 0
  fread y
)

echo 'Phase 2 (revised): read_file loaded.'