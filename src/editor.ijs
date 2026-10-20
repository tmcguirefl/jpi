NB. Editor helpers: @file mentions, path completion, image notes.

NB. y = prompt text. @path and a message that is only an image
NB. path are expanded into text the model can read. Image files
NB. also get the marker split_jpi_image understands.
expand_mentions =: monad define
  s =. y
  if. (0 = # s) +. '/' = {. s do. s return. end.
  if. (fexist s) *. (3 = 4!:0 <'is_image') *. is_image s do.
    (mention_block s) , LF , s return.
  end.
  out =. ''
  i =. 0
  extra =. ''
  while. i < # s do.
    if. '@' = i { s do.
      j =. i + 1
      while. (j < # s) *. -. ((j { s) e. ' ', LF, TAB) do. j =. j + 1 end.
      tok =. (i + 1) }. j {. s
      if. (0 < # tok) *. fexist tok do.
        out =. out , tok
        extra =. extra , LF , mention_block tok
        i =. j
        continue.
      end.
    end.
    out =. out , i { s
    i =. i + 1
  end.
  out , extra
)

mention_block =: monad define
  path =. y
  if. (3 = 4!:0 <'is_image') *. is_image path do.
    mime =. image_mime path
    b64 =. file_to_base64 path
    note =. 'Image file: ' , path
    info =. image_info path
    if. 0 < # info do. note =. note , LF , info end.
    if. 120000 < # b64 do.
      note , LF , '(image is large; not inlined)'
    else.
      note , LF , '[[jpi-image ' , mime , ']]' , LF , b64
    end.
  else.
    raw =. ''
    try. raw =. fread path catch. raw =. '' end.
    if. 2 ~: 3!:0 raw do. raw =. '' end.
    if. 8000 < # raw do.
      raw =. (8000 {. raw) , LF , '[file truncated]'
    end.
    LF , '--- ' , path , ' ---' , LF , raw
  end.
)

NB. Complete the path token at the cursor. One match replaces it.
NB. Several matches extend the shared prefix and list the names.
tui_tab_complete =: monad define
  if. 0 = 4!:0 <'TUI_INPUT' do. '' return. end.
  head =. TUI_CURSOR {. TUI_INPUT
  tail =. TUI_CURSOR }. TUI_INPUT
  i =. # head
  while. (i > 0) *. -. ((i - 1) { head) e. ' ', LF, TAB do. i =. i - 1 end.
  tok =. i }. head
  lead =. ''
  if. '@' = {. tok do. lead =. '@' [ tok =. }. tok end.
  if. 0 = # tok do. '' return. end.
  hits =. ''
  try.
    hits =. 2!:0 'ls -1d ' , (squote tok , '*') , ' 2>/dev/null'
  catch.
    hits =. ''
  end.
  if. 0 = # hits do. '' return. end.
  if. LF ~: {: hits do. hits =. hits , LF end.
  names =. <;._2 hits
  names =. names #~ 0 < # &> names
  if. 0 = # names do. '' return. end.
  if. 1 = # names do.
    pick =. > {. names
    if. '/' ~: {: pick do.
      isdir =. 0
      try. 2!:0 '[ -d ' , (squote pick) , ' ]' [ isdir =. 1 catch. isdir =. 0 end.
      if. isdir do. pick =. pick , '/' end.
    end.
    TUI_INPUT =: (i {. head) , lead , pick , tail
    TUI_CURSOR =: i + (# lead) + # pick
    if. 3 = 4!:0 <'tui_draw_bottom' do. tui_draw_bottom '' end.
    '' return.
  end.
  pref =. > {. names
  for_n. }. names do.
    w =. > n
    k =. 0
    m =. (# pref) <. # w
    while. (k < m) *. (k { pref) = (k { w) do. k =. k + 1 end.
    pref =. k {. pref
  end.
  if. (# tok) < # pref do.
    TUI_INPUT =: (i {. head) , lead , pref , tail
    TUI_CURSOR =: i + (# lead) + # pref
  end.
  echo 'paths:'
  for_n. names do. echo '  ' , > n end.
  if. 3 = 4!:0 <'tui_redraw' do. tui_redraw '' end.
  ''
)

NB. y = one bracketed paste. Returns text-to-insert ; attachment.
NB. An image path, a file:// URL, or a data:image URL becomes an
NB. attachment. The inserted text is a short [image: path] note.
NB. Any other paste is inserted as text with an empty attachment.
accept_paste =: monad define
  s =. y
  t =. deb s
  if. 1 < # t do.
    if. ('"' = {. t) *. ('"' = {: t) do.
      t =. deb }. }: t
    end.
  end.
  if. 7 <: # t do.
    if. 'file://' -: 7 {. t do.
      t =. 7 }. t
    end.
  end.
  if. 11 <: # t do.
    if. 'data:image/' -: 11 {. t do.
      if. 3 = 4!:0 <'save_data_image' do.
        path =. save_data_image t
        if. 0 < # path do.
          ('[image: ' , path , ']') ; mention_block path return.
        end.
      end.
      s ; '' return.
    end.
  end.
  if. fexist t do.
    if. 3 = 4!:0 <'is_image' do.
      if. is_image t do.
        ('[image: ' , t , ']') ; mention_block t return.
      end.
    end.
  end.
  s ; ''
)

echo 'editor loaded.'
