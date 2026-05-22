NB. Code Editing Tool
NB. edit_file.ijs

NB. Number of context lines to show around edits
DIFF_CONTEXT =: 3

NB. Show a diff-style display of an edit
NB. y = filename ; oldstring ; newstring
show_diff =: monad define
  'fn old new' =. y
  txt =. fread fn
  lines =. <;._2 txt , LF -. {: txt
  NB. find which line the old text starts on
  pos =. {. I. old E. txt
  NB. count newlines before pos to get line number
  line_num =. +/ LF = pos {. txt
  NB. context range
  start =. 0 >. line_num - DIFF_CONTEXT
  NB. count lines in old and new text
  old_lines =. <;._2 old , LF -. {: old
  new_lines =. <;._2 new , LF -. {: new
  end_line =. (#lines) <. line_num + (#old_lines) + DIFF_CONTEXT
  ESC =. 27{a.
  
  NB. attempt to look up theme colors if theme engine loaded
  c_add =. '2'
  c_del =. '1'
  c_hdr =. '6'
  try.
    c_add =. ": {. theme_colors 'diff_add'
    c_del =. ": {. theme_colors 'diff_del'
    c_hdr =. ": {. theme_colors 'prompt'
  catch. end.
  
  C_ADD =. ESC,'[38;5;',c_add,'m'
  C_DEL =. ESC,'[38;5;',c_del,'m'
  C_HDR =. ESC,'[38;5;',c_hdr,'m'
  C_RES =. ESC,'[0m'
  
  echo C_HDR , '--- ' , fn , C_RES
  echo C_HDR , '+++ ' , fn , C_RES
  echo C_HDR , '@@ -' , (":start+1) , ',' , (":end_line-start) , ' @@' , C_RES
  NB. show context before
  for_i. start + i. line_num - start do.
    echo ' ' , > i { lines
  end.
  NB. show removed lines
  for_o. old_lines do.
    echo C_DEL , '-' , (> o) , C_RES
  end.
  NB. show added lines
  for_n. new_lines do.
    echo C_ADD , '+' , (> n) , C_RES
  end.
  NB. show context after
  after_start =. line_num + #old_lines
  for_i. after_start + i. DIFF_CONTEXT <. (#lines) - after_start do.
    echo ' ' , > i { lines
  end.
)

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
    NB. show diff before applying
    show_diff fn ; old ; new
    NB. apply the edit
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
