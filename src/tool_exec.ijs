NB. Tool executor - handles LLM tool-call responses
NB. tool_exec.ijs

load 'safety.ijs'

NB. Tool name lookup (same pattern as agent.ijs)
TOOLS =: 'read';'bash';'edit';'write'

NB. Execute a single tool call
NB. y = tool_name ; input_object (parsed JSON)
exec_tool =: monad define
  'name input' =. y
  log 'tool_exec: ' , name
  idx =. TOOLS i. < name
  (exec_read`exec_bash`exec_edit`exec_write`exec_unknown) @. idx input
)

exec_read =: monad define
  path =. > 'path' gethash_json y
  read_file_str path
)

exec_bash =: monad define
  cmd =. > 'command' gethash_json y
  if. -. is_safe cmd do.
    'ERROR: command blocked for safety'
    return.
  end.
  run_cmd_str cmd
)

exec_edit =: monad define
  path =. > 'path' gethash_json y
  old =. > 'old_text' gethash_json y
  new =. > 'new_text' gethash_json y
  if. edit_file path ; old ; new do.
    'Edit successful.'
  else.
    'ERROR: edit failed (text not found).'
  end.
)

exec_write =: monad define
  path =. > 'path' gethash_json y
  content =. > 'content' gethash_json y
  if. write_file path ; content do.
    'Write successful.'
  else.
    'ERROR: write failed.'
  end.
)

exec_unknown =: monad define
  'ERROR: unknown tool'
)

echo 'tool_exec loaded.'
