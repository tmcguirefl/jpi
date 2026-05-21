NB. Session persistence — save/load conversation history
NB. session.ijs

SESSION_DIR =: (2!:5 'HOME') , '/.jpi/sessions'
ACTIVE_SESSION_FILE =: (2!:5 'HOME') , '/.jpi_active_session'

CURRENT_SESSION =: 'default'
try.
  if. 1!:4 :: 0: < ACTIVE_SESSION_FILE do.
    s =. 1!:1 < ACTIVE_SESSION_FILE
    if. 0 < #s do. CURRENT_SESSION =: s -. 10 13 { a. end.
  end.
catch. end.

NB. Ensure session directory exists
ensure_session_dir =: monad define
  p1 =. (2!:5 'HOME') , '/.jpi'
  if. (1!:4 :: _1: < p1) -: _1 do. 1!:5 < p1 end.
  if. (1!:4 :: _1: < SESSION_DIR) -: _1 do. 1!:5 < SESSION_DIR end.
)

NB. Get full file path for a session name
session_path =: monad define
  SESSION_DIR , '/' , y , '.dat'
)

NB. Save current HISTORY to file using J's binary representation
save_session =: monad define
  ensure_session_dir ''
  path =. session_path CURRENT_SESSION
  (3!:1 HISTORY) 1!:2 < path
  echo 'Session [' , CURRENT_SESSION , '] saved (' , (": #HISTORY) , ' messages).'
)

NB. Load HISTORY from file
load_session =: monad define
  path =. session_path CURRENT_SESSION
  if. -. (1!:4 :: _1: < path) -.@-: _1 do.
    echo 'New session [' , CURRENT_SESSION , '] (no saved history found).'
    return.
  end.
  HISTORY =: 3!:2 (1!:1 < path)
  echo 'Session [' , CURRENT_SESSION , '] loaded (' , (": #HISTORY) , ' messages).'
)

NB. Delete saved session file
delete_session =: monad define
  path =. session_path CURRENT_SESSION
  if. -. (1!:4 :: _1: < path) -.@-: _1 do.
    echo 'No saved session to delete for [' , CURRENT_SESSION , ']'
    return.
  end.
  1!:55 < path
  echo 'Session [' , CURRENT_SESSION , '] deleted.'
)

NB. List all interactive sessions
list_sessions =: monad define
  ensure_session_dir ''
  raw =. {."1 [ 1!:0 < SESSION_DIR , '/*.dat'
  NB. drop the '.dat' suffix from filenames
  names =. 0 $ <''
  for_r. raw do.
    n =. > r
    if. '.dat' -: _4 {. n do.
      names =. names , < _4 }. n
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
  CURRENT_SESSION 1!:2 < ACTIVE_SESSION_FILE
  
  HISTORY =: 0$<''  NB. clear current active history
  load_session ''
)

NB. Automatically load current session on startup
ensure_session_dir ''
load_session ''

echo 'session loaded.'
