NB. Code Editing Tool
NB. edit_file.ijs

NB. edit_file: precise replace with uniqueness check
NB. y = filename ; oldstring ; newstring
NB. Returns 1 on success, 0 on failure
NB. Fails if oldstring is not found or matches more than once
edit_file =: monad define
  'fn old new' =. y
  try.
    txt =. fread fn
    if. 0 = #txt do. 0 return. end.
    NB. find all occurrences
    positions =. I. old E. txt
    NB. must match exactly once
    if. 0 = #positions do. 0 return. end.
    if. 1 < #positions do.
      echo 'ERROR: old text matches ' , (": #positions) , ' locations (must be unique)'
      0 return.
    end.
    p =. {. positions
    newtxt =. (p {. txt) , new , (p + #old) }. txt
    newtxt fwrite fn
    1
  catch.
    0
  end.
)

NB. edit_file_multi: apply multiple edits to a single file
NB. y = filename ; (old1;new1) ; (old2;new2) ; ...
NB. Edits are applied in sequence; each must be unique at time of application
NB. Returns count of successful edits
edit_file_multi =: monad define
  fn =. > {. y
  edits =. }. y
  count =. 0
  for_e. edits do.
    'old new' =. > e
    if. edit_file fn ; old ; new do.
      count =. count + 1
    else.
      echo 'ERROR: edit #' , (": count + 1) , ' failed in ' , fn
      count return.
    end.
  end.
  count
)

echo 'edit_file loaded.'
