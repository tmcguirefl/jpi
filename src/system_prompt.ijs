NB. System prompt for the LLM
NB. system_prompt.ijs

NB. Project context filename (like CLAUDE.md for pi)
PROJECT_CONTEXT_FILE =: 'JPILOT.md'

NB. Try to load project context from cwd or parent dirs
load_project_context =: monad define
  NB. check current dir first
  if. fexist PROJECT_CONTEXT_FILE do.
    fread PROJECT_CONTEXT_FILE return.
  end.
  NB. check parent dir
  parent =. '../' , PROJECT_CONTEXT_FILE
  if. fexist parent do.
    fread parent return.
  end.
  ''
)

get_system_prompt =: monad define
  cwd =. _1 }. 2!:0 'pwd'          NB. drop trailing newline
  p =. 'You are J-PI, a coding agent built in the J programming language.'
  p =. p , ' You help users by reading files, executing commands, editing code, and writing files.'
  p =. p , ' You have access to the following tools:'
  p =. p , ' read (read file contents with optional offset/limit),'
  p =. p , ' bash (execute shell commands),'
  p =. p , ' edit (precise find/replace in files, old text must be unique),'
  p =. p , ' write (create/overwrite files, auto-creates directories).'
  p =. p , ' Current working directory: ' , cwd , '.'
  p =. p , ' Be concise. Use tools when asked to perform file or system operations.'
  p =. p , ' When editing, provide exact text that matches uniquely in the file.'
  NB. append project context if available
  ctx =. load_project_context ''
  if. 0 < #ctx do.
    p =. p , ' Project context: ' , ctx
  end.
  p
)

SYSTEM_PROMPT =: get_system_prompt ''

echo 'system_prompt loaded.'
