NB. Prompt templates. A Markdown file in a prompts directory is a
NB. slash command. The file name is the command. $1 and ${1:-default}
NB. expand from the arguments.

PROMPTS =: 0 3 $ <''

prompt_front =: monad define
  lines =. <;._2 y , (LF -. {: y) # LF
  if. 0 = # lines do. '' ; y return. end.
  if. '-' ~: {. > {. lines do. '' ; y return. end.
  end =. 1
  while. (end < # lines) *. '-' ~: {. > end { lines do. end =. end + 1 end.
  if. end >: # lines do. '' ; y return. end.
  desc =. ''
  for_i. 1 + i. end - 1 do.
    line =. > i { lines
    if. 'description:' -: 12 {. line do.
      desc =. deb 12 }. line
    end.
  end.
  rest =. (end + 1) }. lines
  if. 0 = # rest do. body =. '' else. body =. }: ; rest ,each <LF end.
  desc ; body
)

prompt_take_dir =: monad define
  if. -. fexist y do. return. end.
  files =. ''
  try. files =. 2!:0 'ls -1 ' , (squote y) , '/*.md 2>/dev/null' catch. files =. '' end.
  if. 0 = # files do. return. end.
  if. LF ~: {: files do. files =. files , LF end.
  for_p. <;._2 files do.
    path =. > p
    if. 0 = # path do. continue. end.
    name =. (path i: '/') }. path
    if. '.md' -: _3 {. name do. name =. _3 }. name end.
    raw =. fread path
    if. 2 ~: 3!:0 raw do. continue. end.
    'desc body' =. prompt_front raw
    if. 0 = # desc do. desc =. name end.
    PROMPTS =: PROMPTS , 1 3 $ name ; desc ; body
  end.
  ''
)

discover_prompts =: monad define
  PROMPTS =: 0 3 $ <''
  home =. ''
  try. home =. > 2!:5 'HOME' catch. home =. '' end.
  if. 0 < # home do.
    prompt_take_dir home , '/.jpi/prompts'
  end.
  ok =. 1
  if. 3 = 4!:0 <'project_trusted' do. ok =. project_trusted '' end.
  if. ok do.
    prompt_take_dir (1!:43 '') , '/.jpi/prompts'
    prompt_take_dir (1!:43 '') , '/prompts'
  end.
  echo 'Prompts loaded: ' , (": # PROMPTS) , ' template(s)'
)

split_args =: monad define
  out =. 0 $ <''
  cur =. ''
  q =. 0
  for_i. i. # y do.
    c =. i { y
    if. c = '"' do.
      q =. -. q
    elseif. (c = ' ') *. 0 = q do.
      if. 0 < # cur do. out =. out , < cur end.
      cur =. ''
    else.
      cur =. cur , c
    end.
  end.
  if. 0 < # cur do. out =. out , < cur end.
  out
)

NB. x = argument list (boxed), y = template body
expand_template =: dyad define
  args =. x
  s =. y
  out =. ''
  i =. 0
  while. i < # s do.
    if. ('${' -: 2 {. i }. s) do.
      rest =. (i + 2) }. s
      k =. rest i. '}'
      if. k < # rest do.
        spec =. k {. rest
        def =. ''
        num =. spec
        c =. spec i. ':'
        if. (c < # spec) *. '-' = (c + 1) { spec do.
          num =. c {. spec
          def =. (c + 2) }. spec
        end.
        n =. ". num
        val =. def
        if. (1 = # n) *. (n >: 1) *. n <: # args do.
          val =. > (n - 1) { args
        end.
        out =. out , val
        i =. i + 3 + k
        continue.
      end.
    end.
    if. ('$@' -: 2 {. i }. s) +. ('$ARGUMENTS' -: 10 {. i }. s) do.
      if. '$ARGUMENTS' -: 10 {. i }. s do.
        out =. out , ; args ,each <' '
        if. 0 < # args do. out =. }: out end.
        i =. i + 10
      else.
        out =. out , ; args ,each <' '
        if. 0 < # args do. out =. }: out end.
        i =. i + 2
      end.
      continue.
    end.
    if. '$' = i { s do.
      if. (i + 1) < # s do.
        if. ((i + 1) { s) e. '123456789' do.
          n =. ". (i + 1) { s
          if. n <: # args do. out =. out , > (n - 1) { args end.
          i =. i + 2
          continue.
        end.
      end.
    end.
    out =. out , i { s
    i =. i + 1
  end.
  out
)

is_prompt =: monad define
  if. 0 = # PROMPTS do. 0 return. end.
  names =. tolower each 0 {"1 PROMPTS
  (names i. < tolower y) < # PROMPTS
)

prompt_run =: dyad define
  name =. x
  names =. tolower each 0 {"1 PROMPTS
  i =. names i. < tolower name
  if. i >: # PROMPTS do.
    echo 'Unknown prompt: ' , name
    return.
  end.
  body =. > (< i, 2) { PROMPTS
  args =. split_args y
  text =. args expand_template body
  ask_verb text
)

echo 'prompts loaded.'
