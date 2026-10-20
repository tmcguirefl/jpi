NB. System prompt for the LLM
NB. system_prompt.ijs

load 'git.ijs'

NB. Instruction files read from the working directory up to the
NB. repo root. Nearer files are listed after the root file.
PROJECT_CONTEXT_NAMES =: 'AGENTS.md';'JPILOT.md';'CLAUDE.md'

NB. Root first, then each child down to the working directory.
context_dirs =: monad define
  d =. 1!:43 ''
  dirs =. 0 $ <''
  for_i. i. 8 do.
    dirs =. dirs , < d
    if. fexist d , '/.git' do. break. end.
    parent =. (d i: '/') {. d
    if. (0 = # parent) +. parent -: d do. break. end.
    d =. parent
  end.
  |. dirs
)

NB. Project instructions, after the trust answer. A "no" yields
NB. an empty string and does not ask again.
load_project_context =: monad define
  ok =. 1
  if. 3 = 4!:0 <'project_trusted' do. ok =. project_trusted '' end.
  if. -. ok do. '' return. end.
  out =. ''
  for_d. context_dirs '' do.
    d =. > d
    for_n. PROJECT_CONTEXT_NAMES do.
      p =. d , '/' , > n
      if. -. fexist p do. continue. end.
      raw =. ''
      try. raw =. fread p catch. raw =. '' end.
      if. (2 = 3!:0 raw) *. 0 < # raw do.
        out =. out , LF , '--- ' , p , ' ---' , LF , raw
      end.
    end.
  end.
  out
)

NB. Get a compact directory listing for context (top-level files only)
NB. Explicit original:
NB.   get_dir_listing =: monad define
NB.     try.
NB.       listing =. 2!:0 'ls -1 2>/dev/null | head -30'
NB.       _1 }. listing                  NB. drop trailing newline
NB.     catch.
NB.       ''
NB.     end.
NB. )
get_dir_listing =: (_1&}. @ (2!:0) @ ('ls -1 2>/dev/null | head -30'"_)) :: (''"_)

NB. Get a shallow project tree (depth 2, filtering noise dirs).
NB. Works in any directory — shows what's actually there.
NB. If cwd is a src/ subdirectory of a larger project, also shows the
NB. parent directory so the model can discover docs/, plugins/, etc.
NB. If not in a git repo or find fails, falls back to dir listing.
get_project_tree =: monad define
  try.
    tree =. 2!:0 'find . -maxdepth 2 -not -path "./.git/*" -not -path "./.git" -not -path "./node_modules/*" -not -path "./node_modules" -not -path "./.svn/*" -not -path "./.hg/*" 2>/dev/null | sort | head -80'
    if. 0 < #tree do.
      NB. If cwd looks like a src/ subdirectory, append parent tree too
      cwd =. _1 }. 2!:0 'pwd'
      if. ('/src' -: _4 {. cwd) +. ('src' -: cwd) do.
        parent_tree =. 2!:0 'find .. -maxdepth 1 -not -path "../.git/*" -not -path "../.git" -not -path "../node_modules/*" -not -path "../node_modules" 2>/dev/null | sort | head -30'
        if. 0 < #parent_tree do.
          tree =. tree , (10{a.) , parent_tree
        end.
      end.
      _1 }. tree return.
    end.
  catch.
  end.
  get_dir_listing ''
)

NB. Build a compact listing of MCP server tools for the system prompt.
NB. Returns a string like: "recoll (search_filesystem, get_document_content), jmail (search_email)"
NB. Returns '' if no MCP tools are loaded. MCP_TOOLS is defined in mcp.ijs,
NB. which is loaded before system_prompt.ijs in the agent load chain.
get_mcp_tool_listing =: monad define
  if. _1 = 4!:0 <'MCP_TOOLS' do. '' return. end.
  if. 0 = # MCP_TOOLS do. '' return. end.
  NB. Group tool names by server_id, then build "server (tool1, tool2), ..."
  sids =. 0 $ ''
  names =. 0 $ <''
  tool_lists =. 0 $ <''
  for_i. i. # MCP_TOOLS do.
    sid =. > (< i, 3) { MCP_TOOLS
    tname =. > (< i, 0) { MCP_TOOLS
    idx =. sids i. sid
    if. idx < # sids do.
      tool_lists =. (< (> idx { tool_lists) , ', ' , tname) idx } tool_lists
    else.
      sids =. sids , sid
      sname =. ''
      if. _1 ~: 4!:0 <'MCP_SERVERS' do.
        if. sid < # MCP_SERVERS do.
          sname =. > 1 { sid { MCP_SERVERS
        end.
      end.
      names =. names , < sname
      tool_lists =. tool_lists , < tname
    end.
  end.
  parts =. 0 $ <''
  for_i. i. # names do.
    sname =. > i { names
    tools =. > i { tool_lists
    parts =. parts , < sname , ' (' , tools , ')'
  end.
  _2 }. ; parts ,each <', '
)

get_system_prompt =: monad define
  cwd =. _1 }. 2!:0 'pwd'          NB. drop trailing newline
  NB. Build prompt as a boxed list, then raze once (single concatenation).
  parts =. (0$<'') , <'You are J-PI, a coding agent built in the J programming language.'
  parts =. parts , <' You help users by reading files, executing commands, editing code, and writing files.'
  parts =. parts , <' You have access to the following tools:'
  parts =. parts , <' read (read file contents with optional offset/limit; image files come back as images),'
  parts =. parts , <' bash (execute shell commands),'
  parts =. parts , <' edit (precise find/replace in files, old text must be unique),'
  parts =. parts , <' write (create/overwrite files, auto-creates directories),'
  parts =. parts , <' j (evaluate J code directly in the J-PI interpreter session),'
  parts =. parts , <' grep (search file contents),'
  parts =. parts , <' find (find files by name),'
  parts =. parts , <' ls (list a directory).'
  parts =. parts , <' You are working in the J language: if a task asks for the VALUE of a J expression, always evaluate it with the j tool before answering - never answer a value question from memory.'
  NB. JCORE_PATH is set in utils.ijs from the JPI_JCORE env var;
  NB. try/catch guards exotic load orders where utils is absent.
  jcore =. ''
  try. jcore =. JCORE_PATH catch. end.
  if. 0 < # jcore do.
    parts =. parts , <' The full oracle-pinned grammar manual lives at ' , jcore , ' - read it before writing nontrivial J.'
  end.
  parts =. parts , <' Quick checks: name every two-glyph token before you use it (one dot or colon changes the primitive); juxtaposed verbs form hooks and forks, never pipelines - compose with @:; `{` takes the index on the LEFT, `i.` is its mirror; masks reduce with +. (OR), not +/ (counts); in explicit definitions every quote must close and a tacit phrase cannot mention y.'
  parts =. parts , <' When a j tool call fails, read the J-CORE hint in the error - it names the manual section that fixes that error.'
  parts =. parts , <' Current working directory: ' , cwd , '.'
  parts =. parts , <' Be concise. Use tools when asked to perform file or system operations.'
  parts =. parts , <' Plan before acting when a task needs it. Do not wrap reasoning in XML tags inside your reply - replies should carry the answer or result itself; use your native reasoning channel if you have one.'
  parts =. parts , <' To evaluate J, ALWAYS use the j tool - it runs in this live session and keeps state. Do NOT spawn jconsole or other J interpreters via bash (each launch is slow and opens a window on the host desktop); bash+interpreter is only for scripts that must run in a fresh isolated session.'
  parts =. parts , <' When multiple shell commands are independent of one another, combine them into a single bash tool call using shell backgrounding (e.g. `cmd1 & cmd2 & wait`, or `xargs -P`) so they run in parallel rather than issuing separate bash calls.'
  parts =. parts , <' When editing, provide exact text that matches uniquely in the file.'
  p =. ; parts
  NB. include project tree (depth 2, works in any directory)
  tree =. get_project_tree ''
  if. 0 < #tree do.
    p =. p , ' Project structure: ' , tree
  end.
  NB. append git context if in a repo
  gc =. git_context ''
  if. 0 < #gc do. p =. p , gc end.
  NB. append project context if available
  ctx =. load_project_context ''
  if. 0 < #ctx do.
    p =. p , ' Project context: ' , ctx
  end.
  NB. append skill descriptions if any skills are loaded
  skills_desc =. get_skill_descriptions ''
  if. 0 < #skills_desc do.
    p =. p , ' Available skills: ' , skills_desc
    p =. p , ' To use a skill, read its SKILL.md file with the read tool.'
  end.
  NB. append MCP tool listing if any MCP servers are connected
  mcp_desc =. get_mcp_tool_listing ''
  if. 0 < #mcp_desc do.
    p =. p , ' MCP server tools available: ' , mcp_desc
  end.
  p
)

NB. system_prompt loaded. The system prompt is built fresh on each LLM
NB. call via get_system_prompt '' (called from build_payload in llm.ijs),
NB. so cwd changes in the TUI are reflected without a reload.
echo 'system_prompt loaded.'
