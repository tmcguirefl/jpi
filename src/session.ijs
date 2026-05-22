NB. Session persistence — save/load conversation history
NB. session.ijs

require 'files'
require 'dir'

SESSION_DIR =: (2!:5 'HOME') , '/.jpi/sessions'
ACTIVE_SESSION_FILE =: (2!:5 'HOME') , '/.jpi_active_session'

CURRENT_SESSION =: 'default'
init_session =: 3 : 0
  try.
    if. fexist ACTIVE_SESSION_FILE do.
      s =. fread ACTIVE_SESSION_FILE
      if. 0 < #s do. CURRENT_SESSION =: s -. 10 13 { a. end.
    end.
  catch. end.
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
session_path =: monad define
  SESSION_DIR , '/' , y , '.jsonl'
)

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

NB. Load HISTORY from jsonl file
load_session =: monad define
  path =. session_path CURRENT_SESSION
  if. -. fexist path do.
    echo 'New session [' , CURRENT_SESSION , '] (no saved history found).'
    return.
  end.
  
  raw =. fread path
  if. 0 = #raw do.
    HISTORY =: 0 $ <''
  else.
    if. LF ~: {: raw do. raw =. raw , LF end.
    HISTORY =: <;._2 raw
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
