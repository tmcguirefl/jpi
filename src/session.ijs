NB. Session persistence — save/load conversation history
NB. session.ijs

require 'files'
require 'dir'

SESSION_DIR =: (2!:5 'HOME') , '/.jpi/sessions'
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

init_session =: monad define
  NB. PER-FOLDER default session: startup resumes the
  NB. conversation of THIS directory, not a global pointer.
  NB. (Auto-save on exit made sessions persist; a global
  NB. pointer meant every folder resumed the same chat.)
  NB. An explicit /session switch still overrides, per run.
  CURRENT_SESSION =: folder_session ''
  ''
)
init_session ''

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

NB. Save current HISTORY to file using JSONL format
save_session =: monad define
  ensure_session_dir ''
  path =. session_path CURRENT_SESSION
  payload =. ''
  if. 0 < #HISTORY do.
    payload =. ; (,&LF) each HISTORY
  end.
  payload fwrite path
  echo 'Session [' , CURRENT_SESSION , '] saved (' , (": #HISTORY) , ' messages).'
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

NB. Load HISTORY from jsonl file
load_session =: monad define
  path =. session_path CURRENT_SESSION
  if. -. fexist path do.
    NB. no file: HISTORY must become empty, not keep the session
    NB. we switched away from (it would be saved under the new name)
    HISTORY =: 0 $ <''
    echo 'New session [' , CURRENT_SESSION , '] (no saved history found).'
    return.
  end.
  
  raw =. fread path
  if. 0 = #raw do.
    HISTORY =: 0 $ <''
  else.
    if. LF ~: {: raw do. raw =. raw , LF end.
    HISTORY =: <;._2 raw
    NB. old tool-call-only turns were saved as
    NB. {"role":"assistant","tool_calls":[...]} with NO content
    NB. field - strict deserializers (hyai/zai GLM) 400 on replay.
    NB. Normalize on load: give them an empty string content.
    HISTORY =: fix_tool_call_content each HISTORY
  end.
  echo 'Session [' , CURRENT_SESSION , '] loaded (' , (": #HISTORY) , ' messages).'
)

NB. Delete saved session file
delete_session =: monad define
  path =. session_path CURRENT_SESSION
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

NB. Switch into a session
switch_session =: monad define
  NB. Auto-save current session before switching
  if. 0 < #HISTORY do.
    save_session ''
  end.
  
  CURRENT_SESSION =: y
  CURRENT_SESSION fwrite ACTIVE_SESSION_FILE
  
  HISTORY =: 0$<''  NB. clear current active history
  load_session ''
)

NB. Automatically load current session on startup
ensure_session_dir ''
load_session ''

echo 'session loaded.'

NB. Fork: copy the current session to a new name and switch to it.
NB. The original file stays untouched - the conversation branches
NB. here. y = new name, or '' for <current>-fork-<timestamp>.
fork_session =: monad define
  name =. deb y
  if. 0 = # name do.
    name =. CURRENT_SESSION , '-fork-' , (6!:0 'YYYY-MM-DD-hhmmss') -. '-'
  end.
  if. fexist session_path name do.
    echo 'Session [' , name , '] already exists - choose another name.'
    '' return.
  end.
  NB. persist current history first (same convention as switching)
  if. 0 < # HISTORY do.
    save_session ''
  end.
  src =. fread session_path CURRENT_SESSION
  if. 2 ~: 3!:0 src do. src =. '' end.
  src fwrite session_path name
  echo 'Forked [' , CURRENT_SESSION , '] -> [' , name , ']'
  switch_session name
)
