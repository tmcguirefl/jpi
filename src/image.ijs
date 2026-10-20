NB. Image support
NB. image.ijs

require 'utils.ijs'

NB. File extensions we treat as images
IMG_EXTENSIONS =: '.jpg';'.jpeg';'.png';'.gif';'.webp';'.bmp';'.svg'

NB. Check if a filename is an image based on extension
is_image =: monad define
  ext =. tolower (#y) {. y ,~ '.'
  NB. check if any image extension is a suffix
  found =. 0
  for_e. IMG_EXTENSIONS do.
    ie =. > e
    if. ie -: ((- #ie) {. y) do. found =. 1 end.
  end.
  found
)

NB. Base64 encode a file using shell
NB. y = filepath, returns base64 string
file_to_base64 =: monad define
  try.
    _1 }. 2!:0 'base64 < ' , squote y
  catch.
    ''
  end.
)

NB. Get image dimensions string via sips (macOS)
image_info =: monad define
  try.
    _1 }. 2!:0 'sips -g pixelWidth -g pixelHeight ' , (squote y) , ' 2>/dev/null'
  catch.
    ''
  end.
)

NB. y = a tool result. Returns text ; mime ; base64.
NB. mime is '' when the result has no image marker.
image_mime =: monad define
  e =. tolower y
  if. ('.jpg' -: _4 {. e) +. ('.jpeg' -: _5 {. e) do. 'image/jpeg' return. end.
  if. '.png' -: _4 {. e do. 'image/png' return. end.
  if. '.gif' -: _4 {. e do. 'image/gif' return. end.
  if. '.webp' -: _5 {. e do. 'image/webp' return. end.
  'application/octet-stream'
)

split_jpi_image =: monad define
  mark =. '[[jpi-image '
  m =. mark E. y
  if. -. +./ m do. y ; '' ; '' return. end.
  a =. m i. 1
  rest =. (a + # mark) }. y
  b =. rest i. ']'
  mime =. b {. rest
  tail =. (b + 2) }. rest
  if. (0 < # tail) *. LF = {. tail do. tail =. }. tail end.
  b64 =. tail -. ' ', LF, CR, TAB
  (a {. y) ; mime ; b64
)

NB. Display an image inline using iTerm2 protocol (OSC 1337)
NB. Works in iTerm2, WezTerm, Ghostty, etc.
NB. y = filepath
display_image_inline =: monad define
  b64 =. file_to_base64 y
  if. 0 = #b64 do.
    echo 'ERROR: could not read image ' , y
    return.
  end.
  NB. iTerm2 inline image: ESC ] 1337 ; File=inline=1;size=N : base64 BEL
  ESC =. 27 { a.
  BEL =. 7 { a.
  NB. get file size
  sz =. ": > {. 1!:4 < y
  NB. construct the escape sequence
  seq =. ESC , ']1337;File=inline=1;size=' , sz , ':' , b64 , BEL
  1!:2&2 seq
  1!:2&2 LF
)

NB. Detect if terminal likely supports inline images
NB. Check TERM_PROGRAM env var
supports_inline_images =: monad define
  try.
    tp =. 2!:5 'TERM_PROGRAM'
    if. 'iTerm' +./@E. tp do. 1 return. end.
    if. 'WezTerm' +./@E. tp do. 1 return. end.
    if. 'ghostty' +./@E. tp do. 1 return. end.
  catch. end.
  0
)

NB. Directory for pasted and clipboard images. JPI_IMAGE_DIR
NB. overrides it so a test does not write into the home directory.
image_dir =: monad define
  t =. ''
  try. t =. > 2!:5 'JPI_IMAGE_DIR' catch. t =. '' end.
  if. (2 = 3!:0 t) *. 0 < # t do. t return. end.
  (> 2!:5 'HOME') , '/.jpi/images'
)

NB. y = data:image/<type>;base64,<payload>
NB. Decodes into image_dir and returns the path, or ''.
save_data_image =: monad define
  s =. y
  if. 11 > # s do. '' return. end.
  if. -. 'data:image/' -: 11 {. s do. '' return. end.
  rest =. 11 }. s
  semi =. rest i. ';'
  if. semi = # rest do. '' return. end.
  mime =. semi {. rest
  tail =. (semi + 1) }. rest
  if. 7 > # tail do. '' return. end.
  if. -. 'base64,' -: 7 {. tail do. '' return. end.
  b64 =. 7 }. tail
  b64 =. b64 -. ' ', LF, CR, TAB
  if. 120000 < # b64 do.
    echo 'Image is large; not inlined.'
    '' return.
  end.
  ext =. 'bin'
  if. 'png' -: mime do.
    ext =. 'png'
  elseif. 'jpeg' -: mime do.
    ext =. 'jpg'
  elseif. 'jpg' -: mime do.
    ext =. 'jpg'
  elseif. 'gif' -: mime do.
    ext =. 'gif'
  elseif. 'webp' -: mime do.
    ext =. 'webp'
  end.
  dir =. image_dir ''
  try. 2!:0 'mkdir -p ' , squote dir catch. end.
  fn =. dir , '/paste-' , (": <. 1e6 * 6!:1 '') , '.' , ext
  tmp =. fn , '.b64'
  b64 fwrite tmp
  NB. Capture stdout. A shell redirect in 2!:0 does not land
  NB. in the file on this host; 1!:2 writes the bytes exactly.
  bin =. ''
  try.
    bin =. 2!:0 'base64 -d -i ' , squote tmp
  catch.
    bin =. ''
  end.
  try. ferase tmp catch. end.
  if. 0 = # bin do. '' return. end.
  bin 1!:2 < fn
  fn
)

NB. Read a PNG from the macOS clipboard into image_dir.
NB. Returns the path, or '' when the clipboard has no PNG.
clipboard_image =: monad define
  dir =. image_dir ''
  try. 2!:0 'mkdir -p ' , squote dir catch. end.
  fn =. dir , '/clip-' , (": <. 1e6 * 6!:1 '') , '.png'
  script =. dir , '/clip.applescript'
  body =. 'try', LF
  body =. body , 'set pngData to the clipboard as «class PNGf»', LF
  body =. body , 'set fh to open for access POSIX file "' , fn , '" with write permission', LF
  body =. body , 'set eof of fh to 0', LF
  body =. body , 'write pngData to fh', LF
  body =. body , 'close access fh', LF
  body =. body , 'return "OK"', LF
  body =. body , 'on error', LF
  body =. body , 'return "NO"', LF
  body =. body , 'end try', LF
  body fwrite script
  out =. ''
  try.
    out =. 2!:0 'osascript ' , squote script
  catch.
    out =. 'NO'
  end.
  try. ferase script catch. end.
  NB. osascript appends a newline. Match the leading OK.
  if. -. 'OK' -: 2 {. out , '  ' do. '' return. end.
  if. -. fexist fn do. '' return. end.
  fn
)

NB. Display an image — inline if supported, otherwise open externally
NB. y = filepath
display_image =: monad define
  if. -. fexist y do.
    echo 'ERROR: file not found: ' , y
    return.
  end.
  echo 'Image: ' , y
  info =. image_info y
  if. 0 < #info do. echo info end.
  if. supports_inline_images '' do.
    display_image_inline y
  else.
    NB. fallback: open with system viewer
    try. 2!:0 'open ' , squote y catch. end.
    echo '(opened in system viewer)'
  end.
)

echo 'image loaded.'
