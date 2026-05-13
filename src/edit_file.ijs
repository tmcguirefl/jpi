NB. Phase 4: Code Editing Tool
NB. edit_file.ijs

NB. edit_file: precise replace of first occurrence
NB. y = filename ; oldstring ; newstring
edit_file =: monad define
  'fn old new' =. y
  try.
    txt =. fread fn
    if. 0 = #txt do. 0 return. end.
    pos =. I. old E. txt
    if. 0 = #pos do. 0 return. end.
    p =. {. pos
    newtxt =. (p {. txt) , new , (p + #old) }. txt
    newtxt fwrite fn
    1
  catch.
    0
  end.
)

echo 'edit_file loaded.'
