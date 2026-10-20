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
