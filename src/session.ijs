NB. Session persistence — save/load conversation history
NB. session.ijs

require 'files'
require 'dir'

NB. JPI_SESSION_DIR overrides the default so tests do not touch
NB. the user's sessions.
session_dir_of =: monad define
  t =. ''
  try. t =. > 2!:5 'JPI_SESSION_DIR' catch. t =. '' end.
  if. (2 = 3!:0 t) *. 0 < # t do. t return. end.
  (2!:5 'HOME') , '/.jpi/sessions'
)
SESSION_DIR =: session_dir_of ''
ACTIVE_SESSION_FILE =: (2!:5 'HOME') , '/.jpi_active_session'

CURRENT_SESSION =: 'default'
NB. sanitized session name from the working directory:
NB. lowercase basename, non-alphanumerics to '-'. A folder is a
NB. project, so each project resumes its own conversation and a
NB. NEW folder starts fresh. Root/empty -> 'default'.
folder_session =: monad define
  cwd =. 1!:43 ''
  name =. (cwd i: '/') }. cwd    NB. basename: after the last slash
  if. 0 = # name do. 'default' return. end.
  name =. tolower name
  name =. (name e. 'abcdefghijklmnopqrstuvwxyz0123456789-') # name
  if. 0 = # name do. 'default' return. end.
  name
)

NB. Tree rows: id ; parent ; type ; body. type is message (the
NB. stored OpenAI JSON), compaction (summary text), or note
NB. (a branch summary shown to the model). HISTORY is the
NB. active branch after compaction entries replace their ancestors.
NB. HIST_IDS is parallel to HISTORY.
SESSION_ROWS =: 0 4 $ <''
SESSION_HEAD =: ''
SESSION_LABEL =: ''
SESSION_SEQ =: 0
HIST_IDS =: 0 $ <''
JPI_RESUME_PICK =: 0
NB. 0 means --no-session: save_session and load_session do nothing.
SESSION_PERSIST =: 1
NB. Full path when the open file is not SESSION_DIR/name.jsonl.
SESSION_FILE =: ''
NB. First init_session runs while cwd is still src/. It must not
NB. exit the process. The call after the launch directory is
NB. restored is the one that reports a bad flag.
SESSION_INIT_PASS =: 0
NB. Startup --name is applied once, after the selected file is loaded.
SESSION_LABEL_APPLIED =: 0
SESSION_LABEL_HOLD =: 0
SESSION_CLI_OK =: 1

env_text =: monad define
  t =. ''
  try. t =. > 2!:5 y catch. t =. '' end.
  if. 2 ~: 3!:0 t do. '' else. deb t end.
)

session_name_ok =: monad define
  n =. deb y
  if. 0 = # n do. 0 return. end.
  if. 64 < # n do. 0 return. end.
  ok =. n e. 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-'
  if. 0 e. ok do. 0 else. 1 end.
)

session_newid =: monad define
  SESSION_SEQ =: SESSION_SEQ + 1
  'e' , ": SESSION_SEQ
)

session_row =: monad define
  if. 0 = # SESSION_ROWS do. _1 return. end.
  i =. (0 {"1 SESSION_ROWS) i. < y
  if. i < # SESSION_ROWS do. i else. _1 end.
)

session_add_row =: monad define
  'id parent type body' =. y
  SESSION_ROWS =: SESSION_ROWS , 1 4 $ id ; parent ; type ; body
  ''
)

session_set_parent =: dyad define
  i =. session_row x
  if. _1 = i do. '' return. end.
  type =. > (< i, 2) { SESSION_ROWS
  body =. > (< i, 3) { SESSION_ROWS
  row =. 1 4 $ x ; y ; type ; body
  SESSION_ROWS =: (i {. SESSION_ROWS) , row , (i + 1) }. SESSION_ROWS
  ''
)

NB. Root-first ids from y (a head id) back along parent links.
session_chain =: monad define
  ids =. 0 $ <''
  id =. y
  guard =. 0
  while. (0 < # id) *. guard < 10000 do.
    guard =. guard + 1
    i =. session_row id
    if. _1 = i do. break. end.
    ids =. (< id) , ids
    id =. > (< i, 1) { SESSION_ROWS
  end.
  ids
)

NB. Rebuild HISTORY and HIST_IDS from SESSION_HEAD.
NB. A compaction entry drops everything before it.
hist_project =: monad define
  ids =. session_chain SESSION_HEAD
  msgs =. 0 $ <''
  mids =. 0 $ <''
  for_id. ids do.
    i =. session_row > id
    if. _1 = i do. continue. end.
    type =. > (< i, 2) { SESSION_ROWS
    body =. > (< i, 3) { SESSION_ROWS
    if. type -: 'compaction' do.
      msgs =. , < 'user' mk_msg '<summary>' , LF , body , LF , '</summary>'
      mids =. , < > id
    elseif. type -: 'note' do.
      msgs =. msgs , < 'user' mk_msg body
      mids =. mids , < > id
    elseif. type -: 'message' do.
      msgs =. msgs , < fix_tool_call_content body
      mids =. mids , < > id
    end.
  end.
  HISTORY =: msgs
  HIST_IDS =: mids
  ''
)

NB. Append one OpenAI message JSON string to the active branch.
hist_append =: monad define
  id =. session_newid ''
  session_add_row id ; SESSION_HEAD ; 'message' ; y
  SESSION_HEAD =: id
  HISTORY =: HISTORY , < y
  HIST_IDS =: HIST_IDS , < id
  ''
)

NB. Point the active head at the entry for the first n model
NB. messages. Later rows stay in the file as a side branch.
hist_rewind =: monad define
  n =. y
  if. n > # HISTORY do. n =. # HISTORY end.
  if. n < 0 do. n =. 0 end.
  HISTORY =: n {. HISTORY
  HIST_IDS =: n {. HIST_IDS
  if. 0 = # HIST_IDS do.
    SESSION_HEAD =: ''
  else.
    SESSION_HEAD =: > {: HIST_IDS
  end.
  ''
)

NB. x = how many oldest model-facing messages the summary replaces.
NB. y = summary text. Original rows stay in the file.
hist_compact =: dyad define
  idx =. x
  summary =. y
  if. idx < 1 do. '' return. end.
  if. idx > # HIST_IDS do. idx =. # HIST_IDS end.
  if. idx < 1 do. '' return. end.
  lastc =. > (idx - 1) { HIST_IDS
  cid =. session_newid ''
  session_add_row cid ; lastc ; 'compaction' ; summary
  if. idx < # HIST_IDS do.
    kid =. > idx { HIST_IDS
    kid session_set_parent cid
  else.
    SESSION_HEAD =: cid
  end.
  hist_project ''
)

NB. /clear: the next message starts a new root. Old rows remain.
session_new_branch =: monad define
  SESSION_HEAD =: ''
  HISTORY =: 0 $ <''
  HIST_IDS =: 0 $ <''
  ''
)

sj_text =: dyad define
  v =. x gethash_json y
  if. _1 -: v do. '' return. end.
  v =. > v
  if. (2 = 3!:0 v) *. 'json_null' -: v do. '' return. end.
  if. 2 ~: 3!:0 v do. '' return. end.
  v
)

session_reset_tree =: monad define
  SESSION_ROWS =: 0 4 $ <''
  SESSION_HEAD =: ''
  SESSION_LABEL =: ''
  SESSION_SEQ =: 0
  HIST_IDS =: 0 $ <''
  HISTORY =: 0 $ <''
  ''
)

NB. Ensure session directory exists
ensure_session_dir =: monad define
  p1 =. (2!:5 'HOME') , '/.jpi'
  if. -. fexist p1 do. dircreate p1 end.
  if. -. fexist SESSION_DIR do. dircreate SESSION_DIR end.
)

NB. Get full file path for a session name
NB. Explicit original:
NB.   session_path =: monad define
NB.     SESSION_DIR , '/' , y , '.jsonl'
NB. )
session_path =: (SESSION_DIR"_) , '/' , ] , ('.jsonl'"_)

NB. Path used for the open session. SESSION_FILE wins when the
NB. file lives outside SESSION_DIR.
session_file =: monad define
  if. 0 < # SESSION_FILE do. SESSION_FILE return. end.
  session_path CURRENT_SESSION
)

NB. Save the tree. The meta line records the display name, the
NB. working directory, and the active head. Message bodies are
NB. JSON strings so a line stays one object.
save_session =: monad define
  if. 0 = SESSION_PERSIST do. return. end.
  ensure_session_dir ''
  NB. Load only when the verb is missing. It is class 3, and
  NB. a relative load from the project directory is a file name error.
  if. _1 = 4!:0 <'enc_json_fixed' do.
    load 'enc_json_fixed.ijs'
  end.
  path =. session_file ''
  lines =. 0 $ <''
  meta =. '{"type":"meta","name":' , (enc_json_fixed SESSION_LABEL) , ',"cwd":' , (enc_json_fixed 1!:43 '') , ',"head":' , (enc_json_fixed SESSION_HEAD) , '}'
  lines =. lines , < meta
  for_i. i. # SESSION_ROWS do.
    id =. > (< i, 0) { SESSION_ROWS
    parent =. > (< i, 1) { SESSION_ROWS
    type =. > (< i, 2) { SESSION_ROWS
    body =. > (< i, 3) { SESSION_ROWS
    line =. '{"id":' , (enc_json_fixed id) , ',"parent":' , (enc_json_fixed parent) , ',"type":' , (enc_json_fixed type) , ',"body":' , (enc_json_fixed body) , '}'
    lines =. lines , < line
  end.
  payload =. ; lines ,each <LF
  payload fwrite path
  echo 'Session [' , CURRENT_SESSION , '] saved (' , (": # HISTORY) , ' messages, head ' , SESSION_HEAD , ').'
)

NB. Give a tool-call-only assistant message an empty string
NB. content (see load_session normalization note). Matches the
NB. exact saved shape; leaves everything else untouched.
fix_tool_call_content =: monad define
  pfx =. '{"role":"assistant","tool_calls":'
  if. pfx -: (# pfx) {. y do.
    '{"role":"assistant","content":"","tool_calls":' , (# pfx) }. y
  else.
    y
  end.
)

NB. Load the tree. A file of bare message JSON (no "type") is
NB. the pre-tree format: those lines become a single chain.
load_session =: monad define
  if. 0 = SESSION_PERSIST do. return. end.
  session_reset_tree ''
  path =. session_file ''
  if. -. fexist path do.
    echo 'New session [' , CURRENT_SESSION , '] (no saved history found).'
    return.
  end.
  raw =. fread path
  if. (2 ~: 3!:0 raw) +. 0 = # raw do.
    echo 'New session [' , CURRENT_SESSION , '] (empty file).'
    return.
  end.
  if. LF ~: {: raw do. raw =. raw , LF end.
  lines =. <;._2 raw
  legacy =. 0
  head =. ''
  parent =. ''
  require 'convert/json'
  for_ln. lines do.
    line =. > ln
    if. 0 = # line do. continue. end.
    o =. ''
    try. o =. dec_json line catch. continue. end.
    if. 2 ~: #$ o do. continue. end.
    typ =. 'type' sj_text o
    if. 0 = # typ do.
      role =. 'role' sj_text o
      if. 0 = # role do. continue. end.
      legacy =. 1
      id =. session_newid ''
      session_add_row id ; parent ; 'message' ; fix_tool_call_content line
      parent =. id
      head =. id
    elseif. typ -: 'meta' do.
      SESSION_LABEL =: 'name' sj_text o
      head =. 'head' sj_text o
    elseif. do.
      id =. 'id' sj_text o
      if. 0 = # id do. id =. session_newid '' end.
      par =. 'parent' sj_text o
      body =. 'body' sj_text o
      session_add_row id ; par ; typ ; body
      if. 'e' = {. id do.
        rest =. }. id
        if. (0 < # rest) *. *./ rest e. '0123456789' do.
          n =. ". rest
          if. n > SESSION_SEQ do. SESSION_SEQ =: n end.
        end.
      end.
    end.
  end.
  if. legacy do. head =. parent end.
  if. (0 < # head) *. _1 = session_row head do.
    if. 0 < # SESSION_ROWS do.
      head =. > (< _1, 0) { SESSION_ROWS
    else.
      head =. ''
    end.
  end.
  SESSION_HEAD =: head
  hist_project ''
  if. SESSION_CLI_OK do.
    if. 0 = SESSION_LABEL_HOLD do.
      if. 0 = SESSION_LABEL_APPLIED do.
        lab =. env_text 'JPI_SESSION_LABEL'
        SESSION_LABEL_APPLIED =: 1
        if. 0 < # lab do.
          SESSION_LABEL =: lab
          if. SESSION_PERSIST do. save_session '' end.
        end.
      end.
    end.
  end.
  label =. SESSION_LABEL
  if. 0 = # label do. label =. CURRENT_SESSION end.
  echo 'Session [' , label , '] loaded (' , (": # HISTORY) , ' messages).'
)

NB. Delete saved session file
delete_session =: monad define
  path =. session_file ''
  if. -. fexist path do.
    echo 'No saved session to delete for [' , CURRENT_SESSION , ']'
    return.
  end.
  ferase path
  echo 'Session [' , CURRENT_SESSION , '] deleted.'
)

NB. List all interactive sessions
list_sessions =: monad define
  ensure_session_dir ''
  raw =. {."1 [ dir SESSION_DIR , '/*.jsonl'
  NB. drop the '.jsonl' suffix from filenames
  names =. 0 $ <''
  for_r. raw do.
    n =. > r
    if. '.jsonl' -: _6 {. n do.
      names =. names , < _6 }. n
    end.
  end.
  
  if. 0 = # names do.
    echo 'No saved sessions found.'
    return.
  end.
  
  if. 3 = 4!:0 <'tui_select_menu' do.
    sel =. 'Select a session:' tui_select_menu names
    if. sel -.@-: _1 do.
      switch_session > sel { names
    else.
      echo 'Session selection aborted.'
    end.
  else.
    echo 'Available sessions:'
    for_n. names do. echo '  ' , > n end.
  end.
)

NB. Switch into a session. y is a file name, not a path.
switch_session =: monad define
  if. 0 = SESSION_PERSIST do.
    echo 'This run is not saving a session (--no-session).'
    return.
  end.
  if. -. session_name_ok y do.
    echo 'Session name must be letters, digits, dot, underscore, or hyphen.'
    return.
  end.
  if. 0 < # SESSION_ROWS do.
    save_session ''
  end.
  SESSION_FILE =: ''
  CURRENT_SESSION =: y
  CURRENT_SESSION fwrite ACTIVE_SESSION_FILE
  load_session ''
)

NB. Display name. The file name stays the folder name.
session_set_label =: monad define
  SESSION_LABEL =: deb y
  echo 'Session name: ' , SESSION_LABEL
  save_session ''
)

NB. Copy the chain from the root through head id y into a new file.
NB. x is the new session name.
session_write_chain =: dyad define
  name =. x
  head =. y
  ids =. session_chain head
  if. _1 = 4!:0 <'enc_json_fixed' do. load 'enc_json_fixed.ijs' end.
  lines =. 0 $ <''
  meta =. '{"type":"meta","name":"","cwd":' , (enc_json_fixed 1!:43 '') , ',"head":' , (enc_json_fixed head) , '}'
  lines =. lines , < meta
  for_id. ids do.
    i =. session_row > id
    if. _1 = i do. continue. end.
    NB. Do not assign the for_id. name. That name is the loop item.
    eid =. > (< i, 0) { SESSION_ROWS
    parent =. > (< i, 1) { SESSION_ROWS
    type =. > (< i, 2) { SESSION_ROWS
    body =. > (< i, 3) { SESSION_ROWS
    line =. '{"id":' , (enc_json_fixed eid) , ',"parent":' , (enc_json_fixed parent) , ',"type":' , (enc_json_fixed type) , ',"body":' , (enc_json_fixed body) , '}'
    lines =. lines , < line
  end.
  (; lines ,each <LF) fwrite session_path name
  ''
)

NB. y = new name, or '' for a timestamped name. Copies the active
NB. branch through the current head. x, when a boxed id, stops
NB. the copy at that entry (fork from an earlier message).
fork_session =: monad define
  if. 0 = SESSION_PERSIST do.
    echo 'This run is not saving a session (--no-session).'
    return.
  end.
  name =. deb y
  if. 0 = # name do.
    name =. CURRENT_SESSION , '-fork-' , (6!:0 'YYYY-MM-DD-hhmmss') -. '-'
  end.
  if. -. session_name_ok name do.
    echo 'Session name must be letters, digits, dot, underscore, or hyphen.'
    return.
  end.
  if. fexist session_path name do.
    echo 'Session [' , name , '] already exists - choose another name.'
    return.
  end.
  if. 0 < # SESSION_ROWS do. save_session '' end.
  name session_write_chain SESSION_HEAD
  echo 'Forked [' , CURRENT_SESSION , '] -> [' , name , ']'
  switch_session name
)

NB. y = id to copy through. '' copies the current head.
fork_at =: dyad define
  if. 0 = SESSION_PERSIST do.
    echo 'This run is not saving a session (--no-session).'
    return.
  end.
  name =. x
  id =. y
  if. 0 = # id do. id =. SESSION_HEAD end.
  if. _1 = session_row id do.
    echo 'No such session entry.'
    return.
  end.
  if. -. session_name_ok name do.
    echo 'Session name must be letters, digits, dot, underscore, or hyphen.'
    return.
  end.
  if. fexist session_path name do.
    echo 'Session [' , name , '] already exists - choose another name.'
    return.
  end.
  if. 0 < # SESSION_ROWS do. save_session '' end.
  name session_write_chain id
  echo 'Forked through ' , id , ' -> [' , name , ']'
  switch_session name
)

clone_session =: fork_session

NB. User messages on the active branch: id ; preview
session_user_points =: monad define
  out =. 0 2 $ <''
  ids =. session_chain SESSION_HEAD
  for_id. ids do.
    i =. session_row > id
    if. _1 = i do. continue. end.
    type =. > (< i, 2) { SESSION_ROWS
    if. -. type -: 'message' do. continue. end.
    body =. > (< i, 3) { SESSION_ROWS
    if. -. '{"role":"user"' -: (13 <. # body) {. body do. continue. end.
    preview =. 60 {. body
    out =. out , (> id) ; preview
  end.
  out
)

NB. Move the head to an earlier entry. y = entry id.
NB. When the old head is not that entry, ask the model for a
NB. short note of the abandoned branch and hang it on the target.
session_checkout =: monad define
  target =. y
  if. _1 = session_row target do.
    echo 'No such entry.'
    return.
  end.
  if. target -: SESSION_HEAD do.
    echo 'Already at that point.'
    return.
  end.
  old =. SESSION_HEAD
  note =. ''
  if. (0 = 4!:0 <'API_KEY') *. (0 < # API_KEY) *. (3 = 4!:0 <'llm_call') do.
    ids =. session_chain old
    chunk =. ''
    seen =. 0
    for_id. ids do.
      if. (> id) -: target do. seen =. 1 continue. end.
      if. 0 = seen do. continue. end.
      i =. session_row > id
      body =. > (< i, 3) { SESSION_ROWS
      chunk =. chunk , LF , (200 {. body)
    end.
    if. 0 < # chunk do.
      try.
        sys =. 'system' mk_msg 'Summarize this abandoned branch in one short paragraph so a later turn can use it. Output only the summary.'
        usr =. 'user' mk_msg 4000 {. chunk
        api_model =. model_for_api MODEL
        payload =. '{"model":"' , api_model , '","messages":[' , sys , ',' , usr , ']}'
        resp =. llm_call payload
        if. (2 = 3!:0 resp) *. 0 < # resp do.
          note =. 500 {. resp
        elseif. 2 = #$ resp do.
          note =. get_or_content resp
        end.
      catch.
        note =. ''
      end.
    end.
  end.
  if. 0 < # note do.
    nid =. session_newid ''
    session_add_row nid ; target ; 'note' ; ('Branch note: ' , note)
    SESSION_HEAD =: nid
  else.
    SESSION_HEAD =: target
  end.
  hist_project ''
  echo 'Now at ' , SESSION_HEAD , ' (' , (": # HISTORY) , ' messages).'
)

NB. Newest session whose saved cwd is the current directory.
session_continue_name =: monad define
  ensure_session_dir ''
  raw =. ''
  try.
    raw =. 2!:0 'ls -t ' , (squote SESSION_DIR) , '/*.jsonl 2>/dev/null'
  catch.
    raw =. ''
  end.
  if. 0 = # raw do. '' return. end.
  if. LF ~: {: raw do. raw =. raw , LF end.
  cwd =. 1!:43 ''
  require 'convert/json'
  for_p. <;._2 raw do.
    path =. > p
    if. 0 = # path do. continue. end.
    line =. ''
    try.
      txt =. fread path
      if. LF e. txt do. line =. (txt i. LF) {. txt else. line =. txt end.
    catch. continue. end.
    o =. ''
    try. o =. dec_json line catch. continue. end.
    if. 2 ~: #$ o do. continue. end.
    if. -. 'meta' -: 'type' sj_text o do. continue. end.
    if. cwd -: 'cwd' sj_text o do.
      name =. (>: path i: '/') }. path
      if. '.jsonl' -: _6 {. name do. name =. _6 }. name end.
      name return.
    end.
  end.
  ''
)

NB. File stems in SESSION_DIR. Empty when the directory has none.
session_names =: monad define
  ensure_session_dir ''
  raw =. ''
  try. raw =. {."1 [ 1!:0 < SESSION_DIR , '/*.jsonl' catch. raw =. '' end.
  names =. 0 $ <''
  if. 0 = # raw do. names return. end.
  for_r. raw do.
    n =. > r
    if. '.jsonl' -: _6 {. n do.
      names =. names , < _6 }. n
    end.
  end.
  names
)

NB. cwd recorded on the first meta line, or '' when the file has none.
session_file_cwd =: monad define
  raw =. ''
  try. raw =. fread y catch. '' return. end.
  if. (2 ~: 3!:0 raw) +. 0 = # raw do. '' return. end.
  if. LF e. raw do. line =. (raw i. LF) {. raw else. line =. raw end.
  require 'convert/json'
  o =. ''
  try. o =. dec_json line catch. '' return. end.
  if. 2 ~: #$ o do. '' return. end.
  'cwd' sj_text o
)

NB. y = --session or --fork argument.
NB. Returns path ; name, or '' when the argument does not resolve.
session_resolve =: monad define
  arg =. deb y
  if. 0 = # arg do.
    echo 'Session argument is empty.'
    '' return.
  end.
  ispath =. 0
  if. '/' e. arg do. ispath =. 1 end.
  if. '~' = {. arg do. ispath =. 1 end.
  if. '.jsonl' -: _6 {. arg do. ispath =. 1 end.
  if. ispath do.
    path =. arg
    if. '~' = {. path do.
      home =. > 2!:5 'HOME'
      if. 1 = # path do.
        path =. home
      elseif. '~/' -: 2 {. path do.
        path =. home , }. path
      end.
    end.
    if. -. fexist path do.
      echo 'No session file: ' , path
      '' return.
    end.
    name =. (>: path i: '/') }. path
    if. '.jsonl' -: _6 {. name do. name =. _6 }. name end.
    if. 0 = # name do. name =. 'external' end.
    path ; name return.
  end.
  if. -. session_name_ok arg do.
    echo 'Session name must be letters, digits, dot, underscore, or hyphen.'
    '' return.
  end.
  names =. session_names ''
  exact =. 0 $ <''
  pref =. 0 $ <''
  for_n. names do.
    nm =. > n
    if. nm -: arg do.
      exact =. exact , < nm
    elseif. (# arg) <: # nm do.
      if. arg -: (# arg) {. nm do.
        pref =. pref , < nm
      end.
    end.
  end.
  if. 1 = # exact do.
    nm =. > {. exact
    (session_path nm) ; nm return.
  end.
  if. 0 = # pref do.
    echo 'No session matches ' , arg
    '' return.
  end.
  if. 1 < # pref do.
    echo 'Several sessions match ' , arg , ':'
    for_h. pref do. echo '  ' , > h end.
    '' return.
  end.
  nm =. > {. pref
  (session_path nm) ; nm
)

NB. Open path ; name. A file inside SESSION_DIR uses the stem.
session_use =: monad define
  'path name' =. y
  if. (session_name_ok name) *. path -: session_path name do.
    SESSION_FILE =: ''
    CURRENT_SESSION =: name
  else.
    SESSION_FILE =: path
    if. session_name_ok name do.
      CURRENT_SESSION =: name
    else.
      CURRENT_SESSION =: 'external'
    end.
  end.
  ''
)

NB. y = pass number. A later pass exits 2. The first pass falls
NB. back to the folder session so a relative path can be tried
NB. again after the launch directory is restored.
session_cli_fail =: monad define
  SESSION_LABEL_HOLD =: 0
  if. 0 < y do. 2!:55 (2) end.
  SESSION_FILE =: ''
  CURRENT_SESSION =: folder_session ''
  0
)

NB. y = label. Sets the display name. Saves only when this run
NB. persists. Does not echo; startup is quiet.
session_apply_label =: monad define
  if. 0 = # y do. '' return. end.
  SESSION_LABEL =: y
  if. SESSION_PERSIST do. save_session '' end.
  ''
)

NB. y = source ; newid ; pass. Copies the source branch into a
NB. new file under SESSION_DIR and opens that file.
session_cli_fork =: monad define
  'from id pass' =. y
  got =. session_resolve from
  if. 0 = # got do. session_cli_fail pass return. end.
  'path name' =. got
  session_use path ; name
  SESSION_LABEL_HOLD =: 1
  load_session ''
  new =. id
  if. 0 = # new do. new =. folder_session '' end.
  if. -. session_name_ok new do.
    echo 'Session id is not a valid name.'
    session_cli_fail pass return.
  end.
  if. fexist session_path new do.
    echo 'Session [' , new , '] already exists.'
    session_cli_fail pass return.
  end.
  SESSION_FILE =: ''
  new session_write_chain SESSION_HEAD
  CURRENT_SESSION =: new
  load_session ''
  SESSION_LABEL_HOLD =: 0
  echo 'Forked [' , name , '] -> [' , new , ']'
  1
)

NB. y = argument ; pass ; foreign flag (1 forks when the saved
NB. cwd is not the launch directory, and only on a later pass).
session_cli_open =: monad define
  'arg pass foreign' =. y
  got =. session_resolve arg
  if. 0 = # got do. session_cli_fail pass return. end.
  'path name' =. got
  if. foreign do.
    if. pass > 0 do.
      cwd =. session_file_cwd path
      here =. 1!:43 ''
      if. 0 < # cwd do.
        if. -. cwd -: here do.
          echo 'Session belongs to ' , cwd , '; forking into this directory.'
          session_cli_fork path ; '' ; pass return.
        end.
      end.
    end.
  end.
  session_use path ; name
  1
)

NB. y = exact id. Opens it, or leaves an empty session to be
NB. created on the first save. Does not fork on a foreign cwd.
session_cli_id =: monad define
  'id pass' =. y
  if. -. session_name_ok id do.
    echo 'Session name must be letters, digits, dot, underscore, or hyphen.'
    session_cli_fail pass return.
  end.
  SESSION_FILE =: ''
  CURRENT_SESSION =: id
  1
)

init_session =: monad define
  mode =. env_text 'JPI_SESSION_MODE'
  arg =. env_text 'JPI_SESSION_ARG'
  forkfrom =. env_text 'JPI_FORK_FROM'
  sid =. env_text 'JPI_SESSION_ID'
  label =. env_text 'JPI_SESSION_LABEL'
  pass =. SESSION_INIT_PASS
  SESSION_INIT_PASS =: pass + 1
  JPI_RESUME_PICK =: 0
  SESSION_PERSIST =: 1
  SESSION_FILE =: ''
  ok =. 1
  if. mode -: 'none' do.
    SESSION_PERSIST =: 0
    SESSION_FILE =: ''
    session_reset_tree ''
    CURRENT_SESSION =: 'scratch'
    if. 0 < # label do. SESSION_LABEL =: label end.
    SESSION_LABEL_APPLIED =: 1
  elseif. 0 < # forkfrom do.
    ok =. session_cli_fork forkfrom ; sid ; pass
  elseif. mode -: 'session' do.
    ok =. session_cli_open arg ; pass ; 1
  elseif. mode -: 'session-id' do.
    ok =. session_cli_id sid ; pass
  elseif. mode -: 'continue' do.
    name =. session_continue_name ''
    if. 0 < # name do.
      CURRENT_SESSION =: name
    else.
      CURRENT_SESSION =: folder_session ''
    end.
  elseif. mode -: 'resume' do.
    CURRENT_SESSION =: folder_session ''
    JPI_RESUME_PICK =: 1
  else.
    CURRENT_SESSION =: folder_session ''
  end.
  SESSION_CLI_OK =: ok
  ''
)

NB. Startup. tui.ijs calls init_session and load_session again
NB. after it restores the launch directory.
ensure_session_dir ''
init_session ''
load_session ''

echo 'session loaded.'
