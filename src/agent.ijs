NB. Phase 6: Agent Framework and Decision Loop
NB. agent.ijs

load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'

NB. Simple keyword parser
parse_action =: 3 : 0
  s =. tolower y
  if. 'read'  +./@E. s do. 'read'  return. end.
  if. 'run'   +./@E. s do. 'run'   return. end.
  if. 'edit'  +./@E. s do. 'edit'  return. end.
  if. 'write' +./@E. s do. 'write' return. end.
  if. 'ls' +./@E. s do. 'run' return. end.
  'unknown'
)

tolower =: 96&+&.(65&+&-)&.('ABCDEFGHIJKLMNOPQRSTUVWXYZ'&i.)

NB. Light-weight agent
agent =: 3 : 0
  a =. parse_action y
  select. a
  case. 'read'  do. echo 'Reading file...'; read_file_str 'README.md'
  case. 'run'   do. echo 'Running command...'; run_cmd_str 'ls'
  case. 'edit'  do. echo 'Editing...'
  case. 'write' do. echo 'Writing...'
  case. do. echo 'Unknown action'
  end.
)

echo 'Phase 6: agent loaded.'