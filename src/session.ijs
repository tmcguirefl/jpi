NB. Session persistence — save/load conversation history
NB. session.ijs

SESSION_FILE =: jpath '~temp/jpi_session.dat'

NB. Save current HISTORY to file using J's binary representation
save_session =: monad define
  (3!:1 HISTORY) fwrite SESSION_FILE
  echo 'Session saved (' , (": #HISTORY) , ' messages) to ' , SESSION_FILE
)

NB. Load HISTORY from file
load_session =: monad define
  if. -. fexist SESSION_FILE do.
    echo 'No saved session found.'
    return.
  end.
  raw =. fread SESSION_FILE
  HISTORY =: 3!:2 raw
  echo 'Session loaded (' , (": #HISTORY) , ' messages) from ' , SESSION_FILE
)

NB. Delete saved session file
delete_session =: monad define
  if. fexist SESSION_FILE do.
    ferase SESSION_FILE
    echo 'Saved session deleted.'
  else.
    echo 'No saved session to delete.'
  end.
)

echo 'session loaded.'
