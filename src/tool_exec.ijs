NB. Tool executor - handles LLM tool-call responses
NB. tool_exec.ijs

load 'safety.ijs'
load 'confirm.ijs'

NB. Tool name lookup
TOOLS =: 'read';'bash';'edit';'write'

NB. Execute a single tool call
NB. y = tool_name ; input_object (parsed JSON, boxed)
exec_tool =: monad define
  'name input' =. y
  log 'tool_exec: ' , name
  idx =. TOOLS i. < name
  if. idx < #TOOLS do.
    NB. built-in tool
    (exec_read`exec_bash`exec_edit`exec_write) @. idx input
  else.
    NB. try extension tools
    ext_exec_tool name ; input
  end.
)

exec_read =: monad define
  path =. > 'path' gethash_json y
  NB. optional offset and limit parameters
  offset =. 'offset' gethash_json y
  limit =. 'limit' gethash_json y
  if. _1 -: offset do. offset =. 1 end.
  if. _1 -: limit do. limit =. 2000 end.
  offset =. > offset
  limit =. > limit
  read_file_auto path ; offset ; limit
)

exec_bash =: monad define
  cmd =. > 'command' gethash_json y
  if. -. is_safe cmd do.
    'ERROR: command blocked for safety'
    return.
  end.
  NB. optional timeout parameter
  timeout =. 'timeout' gethash_json y
  if. _1 -: timeout do. timeout =. DEFAULT_TIMEOUT end.
  timeout =. > timeout
  run_cmd_str cmd ; timeout
)

exec_edit =: monad define
  path =. > 'path' gethash_json y
  if. -. confirm_edit path do.
    'Cancelled by user.' return.
  end.
  old =. > 'old_text' gethash_json y
  new =. > 'new_text' gethash_json y
  if. edit_file path ; old ; new do.
    'Edit successful.'
  else.
    'ERROR: edit failed (text not found or not unique).'
  end.
)

exec_write =: monad define
  path =. > 'path' gethash_json y
  if. -. confirm_write path do.
    'Cancelled by user.' return.
  end.
  content =. > 'content' gethash_json y
  if. write_file path ; content do.
    'Write successful.'
  else.
    'ERROR: write failed.'
  end.
)

exec_unknown =: monad define
  NB. check extension tools before giving up
  NB. y is the parsed JSON args, but we need the tool name
  NB. tool name was already dispatched — this only fires if not found
  'ERROR: unknown tool'
)

echo 'tool_exec loaded.'
