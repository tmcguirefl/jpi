NB. Phase 4: Code Editing Tool
NB. edit_file.ijs

NB. edit_file: precise replace of first occurrence
NB. y = filename ; oldstring ; newstring
edit_file =: 3 : 0
  'fn old new' =. y
  try.
    txt =. fread fn
    if. 0 = #txt do. 0 return. end.
    idx =. txt E.i old
    if. 0 = #idx do. 0 return. end.          NB. not found
    pos =. {. idx
    len =. #old
    newtxt =. (pos {. txt) , new , (pos+len) }. txt
    newtxt 1!:2 < fn
    1
  catch.
    0
  end.
)

echo 'Phase 4: edit_file loaded.'