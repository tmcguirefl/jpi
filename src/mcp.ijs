NB. MCP client — stdio + HTTP transports
NB. mcp.ijs
NB.
NB. Connects to MCP servers via two transports:
NB.   stdio — spawn subprocess, communicate via pipes (JSON-RPC over stdin/stdout)
NB.   http  — POST JSON-RPC to a URL (Streamable HTTP transport)
NB.
NB. Implements: initialize, tools/list, tools/call, shutdown.
NB.
NB. stdio transport uses J's cd foreign (15!:0) for libc syscalls:
NB.   pipe, fork, dup2, close, read, write, system, poll, kill
NB.
NB. http transport uses curl (via 2!:0) to POST JSON-RPC requests.
NB. Handles both plain JSON and SSE (text/event-stream) responses.
NB. Manages Mcp-Session-Id header for stateful servers.
NB.
NB. Spec references:
NB.   Agent Plugins: https://agent-plugins.org/specification (§7.2)
NB.   MCP: https://modelcontextprotocol.io/specification

require 'files'
require 'convert/json'

NB. ================================================================
NB. libc access (stdio transport only)
u_libc =: unxlib 'c'

NB. ================================================================
NB. Global registry of MCP servers
NB. Each row (7 columns):
NB.   0: server_id (integer)
NB.   1: name (string)
NB.   2: transport ('stdio' or 'http')
NB.   3: stdin_write_fd (stdio) or url (http)
NB.   4: stdout_read_fd (stdio) or session_id (http)
NB.   5: pid (stdio) or auth_header (http)
NB.   6: tools (boxed list, unused — tools stored in MCP_TOOLS)
MCP_SERVERS =: 0 7 $ <''

NB. Global registry of MCP tools (for get_tools / exec_tool)
NB. Each row: tool_name ; description ; input_schema_json ; server_id
MCP_TOOLS =: 0 4 $ <''

NB. JSON-RPC request ID counter
MCP_REQ_ID =: 0

NB. Temp files for HTTP transport (avoids shell quoting).
NB. Names carry the per-process suffix defined in http.ijs so
NB. concurrent jpi instances don't overwrite each other's requests.
NB. mcp.ijs may be loaded without http.ijs, so compute locally.
mcp_tmp_suffix =: monad define
  try.
    '_' , _1 }. 2!:0 'echo $PPID'
  catch.
    '_' , ": ? 1e6
  end.
)
MCP_TMP_SUFFIX   =: mcp_tmp_suffix ''
MCP_HTTP_BODY    =: jpath '~temp/mcp_http_body' , MCP_TMP_SUFFIX , '.json'
MCP_HTTP_RESP    =: jpath '~temp/mcp_http_resp' , MCP_TMP_SUFFIX , '.txt'
MCP_HTTP_HDRS    =: jpath '~temp/mcp_http_hdrs' , MCP_TMP_SUFFIX , '.txt'
MCP_HTTP_HDRS_OUT=: jpath '~temp/mcp_http_resp_hdrs' , MCP_TMP_SUFFIX , '.txt'
MCP_HTTP_ERR     =: jpath '~temp/mcp_http_err' , MCP_TMP_SUFFIX , '.txt'

NB. ================================================================
NB. Low-level syscall wrappers

NB. Create a pipe, return (read_fd ; write_fd)
sys_pipe =: monad define
  res =. (u_libc , ' pipe i *i')&cd <0 0
  > 1 { res
)

NB. Fork, return child pid (0 in child)
NB. Explicit original:
NB.   sys_fork =: monad define
NB.     0 ". ": > (u_libc , ' fork i')&cd ''
NB. )
sys_fork =: 0&". @ ": @ > @ ((u_libc , ' fork i')&cd)

NB. dup2(oldfd, newfd) -> rc
sys_dup2 =: dyad define
  > 0 { (u_libc , ' dup2 i i i')&cd x ; y
)

NB. close(fd)
NB. Explicit original:
NB.   sys_close =: monad define
NB.     (u_libc , ' close i i')&cd y
NB. )
sys_close =: (u_libc , ' close i i')&cd

NB. write(fd, data) -> nwritten
sys_write =: dyad define
  > 0 { (u_libc , ' write l i &c l')&cd x ; y ; #y
)

NB. read(fd, bufsize) -> data string (empty on EOF or error)
sys_read =: dyad define
  buf =. y # ' '
  rres =. (u_libc , ' read l i *c l')&cd x ; buf ; y
  nread =. > 0 { rres
  if. nread < 0 do. '' return. end.
  nread {. > 2 { rres
)

NB. system(command_string) -> rc
sys_system =: monad define
  > 0 { (u_libc , ' system i *c')&cd <y
)

NB. _exit(status)
NB. Explicit original:
NB.   sys_exit =: monad define
NB.     (u_libc , ' _exit i i')&cd y
NB. )
sys_exit =: (u_libc , ' _exit i i')&cd

NB. kill(pid, signal) -> rc
sys_kill =: dyad define
  > 0 { (u_libc , ' kill i i i')&cd x ; y
)

NB. poll(fd, timeout_ms) -> 1 if data ready, 0 if timeout/error
NB. Uses mema/memw to build the struct pollfd in allocated memory.
NB. On 64-bit J, type 4 (int) is 8 bytes; the struct is 8 bytes total,
NB. so writing two 8-byte ints at offsets 0 and 4 lands the low bytes
NB. in the right positions (fd, events=POLLIN, revents=0).
NB. 16 bytes allocated to avoid overflow from the 8-byte writes.
sys_poll =: dyad define
  p =. mema 16
  y memw p, 0 1 4        NB. fd (int at offset 0)
  1 memw p, 4 1 4        NB. events=POLLIN=1, revents=0 (int at offset 4)
  res =. (u_libc , ' poll i x i i')&cd p;1;x
  memf p
  rc =. > 0 { res
  rc > 0
)

NB. ================================================================
NB. Spawn an MCP server subprocess (stdio transport)
NB. y = command string (e.g. 'npx -y @modelcontextprotocol/server-everything')
NB. Returns: server_id (index into MCP_SERVERS)
mcp_spawn =: monad define
  NB. Create two pipes: stdin (parent->child) and stdout (child->parent)
  stdin_pipe =. sys_pipe ''
  stdout_pipe =. sys_pipe ''
  
  stdin_read =. 0 { stdin_pipe
  stdin_write =. 1 { stdin_pipe
  stdout_read =. 0 { stdout_pipe
  stdout_write =. 1 { stdout_pipe
  
  NB. Fork
  pid =. sys_fork ''
  
  if. 0 = pid do.
    NB. Child: redirect stdin/stdout
    stdin_read sys_dup2 0
    stdout_write sys_dup2 1
    NB. Close all pipe fds
    sys_close stdin_read
    sys_close stdin_write
    sys_close stdout_read
    sys_close stdout_write
    NB. Run the command
    sys_system y
    sys_exit 0
  end.
  
  NB. Parent: close child-side ends
  sys_close stdin_read
  sys_close stdout_write
  
  NB. Register server: id ; name ; transport ; stdin_write ; stdout_read ; pid ; ''
  server_id =. # MCP_SERVERS
  server_name =. y  NB. use command as name for now
  MCP_SERVERS =: MCP_SERVERS , server_id ; server_name ; 'stdio' ; stdin_write ; stdout_read ; pid ; <''
  server_id
)

NB. ================================================================
NB. Connect to an MCP server via HTTP (Streamable HTTP transport)
NB. y = url ; auth_header (auth_header is '' for no auth)
NB. Returns: server_id (index into MCP_SERVERS)
mcp_http_connect =: monad define
  'url auth' =. 2 {. (boxopen y) , <''
  server_id =. # MCP_SERVERS
  server_name =. url  NB. use url as name
  MCP_SERVERS =: MCP_SERVERS , server_id ; server_name ; 'http' ; url ; '' ; auth ; <''
  server_id
)

NB. ================================================================
NB. Send a JSON-RPC request to a server, read response
NB. x = server_id, y = JSON string (the request, without trailing LF)
NB. Returns: JSON string (the response)
mcp_request =: dyad define
  row =. x { MCP_SERVERS
  transport =. > 2 { row
  if. transport -: 'http' do.
    x mcp_http_request y
  else.
    x mcp_stdio_request y
  end.
)

NB. ================================================================
NB. stdio transport: write JSON to stdin, read response from stdout
NB. x = server_id, y = JSON string
mcp_stdio_request =: dyad define
  row =. x { MCP_SERVERS
  stdin_write =. > 3 { row
  stdout_read =. > 4 { row
  NB. Write request + LF to server's stdin
  msg =. y , LF
  stdin_write sys_write msg
  NB. Read response (line-delimited, accumulate until LF)
  mcp_read_response stdout_read
)

NB. ================================================================
NB. http transport: POST JSON-RPC, parse SSE or plain JSON response
NB. x = server_id, y = JSON string
NB. Returns: JSON string (the response body)
mcp_http_request =: dyad define
  row =. x { MCP_SERVERS
  url =. > 3 { row
  session_id =. > 4 { row
  auth =. > 5 { row

  NB. Write body to temp file (avoid shell quoting)
  y fwrite MCP_HTTP_BODY

  NB. Build curl header config file
  h =. 'header = "Content-Type: application/json"' , LF
  h =. h , 'header = "Accept: application/json, text/event-stream"' , LF
  if. 0 < # auth do.
    h =. h , 'header = "Authorization: ' , auth , '"' , LF
  end.
  if. 0 < # session_id do.
    h =. h , 'header = "Mcp-Session-Id: ' , session_id , '"' , LF
  end.
  h fwrite MCP_HTTP_HDRS

  NB. POST: capture response body, headers, stderr separately
  cmd =. 'curl -s -X POST -K ' , MCP_HTTP_HDRS , ' -d @' , MCP_HTTP_BODY
  cmd =. cmd , ' -o ' , MCP_HTTP_RESP
  cmd =. cmd , ' -D ' , MCP_HTTP_HDRS_OUT
  cmd =. cmd , ' ' , url , ' 2>' , MCP_HTTP_ERR
  try. 2!:0 cmd catch. end.

  NB. Extract session ID from response headers (if present)
  mcp_extract_session x

  NB. Read response body
  body =. ''
  if. fexist MCP_HTTP_RESP do. body =. fread MCP_HTTP_RESP end.
  if. 0 = # body do. '' return. end.

  NB. Parse SSE if needed: response may be plain JSON or SSE format
  mcp_parse_response body
)

NB. Extract Mcp-Session-Id from response headers, store in server row
NB. y = server_id
mcp_extract_session =: monad define
  if. -. fexist MCP_HTTP_HDRS_OUT do. return. end.
  hdrs =. fread MCP_HTTP_HDRS_OUT
  NB. Look for "mcp-session-id:" (case-insensitive)
  lines =. <;._2 hdrs , LF
  found =. 0
  for_i. i. # lines do.
    line =. > i { lines
    lower =. tolower line
    if. 'mcp-session-id:' -: 15 {. lower do.
      sid =. (dlb 15 }. line) -. CR
      MCP_SERVERS =: (< sid) (< y, 4) } MCP_SERVERS
      found =. 1
    end.
  end.
  found
)

NB. Parse MCP HTTP response: handle both plain JSON and SSE
NB. y = response body string
NB. Returns: JSON string (extracted from SSE if needed)
mcp_parse_response =: monad define
  NB. If response starts with { it's plain JSON
  if. '{' = {. dlb y do. y return. end.
  NB. SSE format: lines starting with "data: " contain JSON
  NB. Split on LF (handle CRLF by stripping CR from each line)
  lines =. <;._2 y , LF
  for_l. lines do.
    line =. (dlb > l) -. CR
    if. 'data: ' -: 6 {. line do.
      6 }. line return.
    end.
  end.
  NB. Unknown format, return as-is
  y
)

NB. ================================================================
NB. Read a line from an MCP server's stdout
NB. Polls before each read with a 30s timeout to avoid hanging forever
NB. if a server crashes or sends partial output without LF.
NB. y = stdout_read fd
NB. Returns: the line without LF, or '' on timeout/EOF
mcp_read_response =: monad define
  buf =. ''
  while. 1 do.
    NB. Wait up to 30s for data to be available
    if. 0 = 30000 sys_poll y do.
      echo 'MCP: read timeout (30s), returning partial response'
      buf return.
    end.
    chunk =. y sys_read 4096
    if. 0 = #chunk do. buf return. end.
    buf =. buf , chunk
    if. LF e. buf do.
      NB. Return everything up to the first LF
      line_end =. buf i. LF
      line_end {. buf return.
    end.
  end.
)

NB. ================================================================
NB. Send initialize request to a server
NB. y = server_id
NB. Returns: 1 if initialized, 0 if failed
mcp_init =: monad define
  MCP_REQ_ID =: MCP_REQ_ID + 1
  req =. '{"jsonrpc":"2.0","id":' , (": MCP_REQ_ID) , ',"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"jpi","version":"1.0"}}}'
  response =. y mcp_request req
  if. 0 = #response do. 0 return. end.
  NB. Check for error
  parsed =. dec_json response
  if. 1 = $$ parsed do. parsed =. ,parsed end.
  err =. 'error' gethash_json parsed
  if. err -.@-: _1 do.
    err_msg =. > 'message' gethash_json > err
    echo 'MCP: initialize error: ' , err_msg
    0 return.
  end.
  NB. Send initialized notification (no response expected)
  notif =. '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  row =. y { MCP_SERVERS
  transport =. > 2 { row
  if. transport -: 'http' do.
    NB. HTTP: POST the notification (response ignored)
    y mcp_http_request notif
  else.
    NB. stdio: write to stdin
    stdin_write =. > 3 { row
    stdin_write sys_write notif , LF
  end.
  1
)

NB. ================================================================
NB. Sanitize a JSON schema string for provider compatibility.
NB. Removes keys not universally supported by LLM providers (Cohere,
NB. Anthropic, etc.): anyOf, additionalProperties, default, title, $schema.
NB. Replaces anyOf with the first non-null type alternative.
NB. Pure J — uses dec_json/enc_json_fixed with a recursive walker.
NB. y = JSON schema string, returns sanitized JSON schema string.

NB. Keys to strip from schemas
SCHEMA_UNWANTED =: 'additionalProperties';'default';'title';'$schema'

NB. Find first non-null type object from an anyOf array.
NB. y = rank-1 boxed list of 2-row type tables
first_non_null =: monad define
  for_t. y do.
    obj =. > t
    tval =. > ('type' gethash_json obj)
    if. tval -.@-: 'null' do. obj return. end.
  end.
  > 0 { y
)

NB. Recursive node sanitizer.
NB. Walks dec_json output: objects (2-row tables), arrays (rank-1),
NB. scalar boxes. Removes unwanted keys, handles anyOf, recurses.
sanitize_node =: monad define
  if. 32 ~: 3!:0 y do. y return. end.
  select. #@$ y
  case. 0 do.
    NB. scalar box — recurse into contents
    < sanitize_node > y
  case. 1 do.
    NB. array — recurse into each element (each boxes results)
    sanitize_node each y
  case. 2 do.
    if. 2 = {. $ y do.
      NB. object (2-row table: row 0 = keys, row 1 = values)
      keys =. 0 { y
      vals =. 1 { y
      n =. # keys

      NB. Step 1: handle anyOf — merge first non-null type into object
      ao_idx =. (, > each keys) i. <'anyOf'
      if. ao_idx < n do.
        ao_val =. > ao_idx { vals
        repl =. first_non_null ao_val
        rkeys =. 0 { repl
        rvals =. 1 { repl
        for_ri. i. # rkeys do.
          rk =. > ri { rkeys
          rv =. > ri { rvals
          ei =. (, > each keys) i. < rk
          if. ei < n do.
            vals =. (< rv) ei } vals
          else.
            keys =. keys , < rk
            vals =. vals , < rv
            n =. n + 1
          end.
        end.
        NB. Remove the anyOf entry
        mask =. -. (i. n) = ao_idx
        keys =. mask # keys
        vals =. mask # vals
        n =. # keys
      end.

      NB. Step 2: remove unwanted keys, recurse into values
      new_keys =. 0 $ <''
      new_vals =. 0 $ <''
      for_i. i. n do.
        key =. > i { keys
        NB. Must box key for e. to match against boxed list
        if. -. (<key) e. SCHEMA_UNWANTED do.
          new_keys =. new_keys , < key
          new_vals =. new_vals , < sanitize_node > i { vals
        end.
      end.

      new_keys ,: new_vals
    else.
      NB. array of arrays — recurse into each row
      sanitize_node each y
    end.
  case. do.
    y
  end.
)

sanitize_schema =: monad define
  if. 0 = #y do. '{"type":"object","properties":{}}' return. end.
  try.
    parsed =. dec_json y
    if. 1 = #@$ parsed do. parsed =. ,parsed end.
    if. 3 = #@$ parsed do. parsed =. (2 , {: $ parsed) $ , parsed end.
    enc_json_fixed sanitize_node parsed
  catch.
    y
  end.
)

NB. ================================================================
NB. List tools from a server
NB. y = server_id
NB. Returns: 1 if successful, 0 if failed
NB. Populates MCP_TOOLS with tool entries
mcp_list_tools =: monad define
  MCP_REQ_ID =: MCP_REQ_ID + 1
  req =. '{"jsonrpc":"2.0","id":' , (": MCP_REQ_ID) , ',"method":"tools/list","params":{}}'
  response =. y mcp_request req
  if. 0 = #response do. 0 return. end.
  parsed =. dec_json response
  NB. Guard: if parsed is rank 1, wrap it
  if. 1 = $$ parsed do. parsed =. ,parsed end.
  result =. 'result' gethash_json parsed
  if. result -: _1 do. 0 return. end.
  result =. > result
  if. 1 = $$ result do. result =. ,result end.
  tools_arr =. 'tools' gethash_json result
  if. tools_arr -: _1 do. 0 return. end.
  tools_arr =. > tools_arr
  if. 1 = $$ tools_arr do. tools_arr =. ,tools_arr end.
  
  for_t. tools_arr do.
    tool =. > t
    if. 1 = $$ tool do. tool =. ,tool end.
    name =. > 'name' gethash_json tool
    desc =. > 'description' gethash_json tool
    schema =. 'inputSchema' gethash_json tool
    if. schema -: _1 do. schema =. '{}' end.
    schema_str =. schema
    if. 2 ~: 3!:0 schema_str do. schema_str =. enc_json_fixed schema_str end.
    NB. Sanitize schema for provider compatibility (remove anyOf,
    NB. additionalProperties, default, title — not universally supported).
    schema_str =. sanitize_schema schema_str
    MCP_TOOLS =: MCP_TOOLS , name ; desc ; schema_str ; <y
  end.
  
  1
)

NB. ================================================================
NB. Call a tool on a server
NB. x = server_id, y = tool_name ; arguments_json
NB. Returns: result text string
mcp_call =: dyad define
  'tool_name args_json' =. y
  MCP_REQ_ID =: MCP_REQ_ID + 1
  req =. '{"jsonrpc":"2.0","id":' , (": MCP_REQ_ID) , ',"method":"tools/call","params":{"name":"' , tool_name , '","arguments":' , args_json , '}}'
  response =. x mcp_request req
  if. 0 = #response do. 'ERROR: no response from MCP server' return. end.
  parsed =. dec_json response
  if. 1 = $$ parsed do. parsed =. ,parsed end.
  result =. 'result' gethash_json parsed
  if. result -: _1 do.
    err =. 'error' gethash_json parsed
    if. err -.@-: _1 do.
      err_msg =. > 'message' gethash_json > err
      'ERROR: ' , err_msg return.
    end.
    'ERROR: malformed response' return.
  end.
  NB. Extract text from content array
  result =. > result
  if. 1 = $$ result do. result =. ,result end.
  content =. 'content' gethash_json result
  if. content -: _1 do. '' return. end.
  content =. > content
  if. 1 = $$ content do. content =. ,content end.
  texts =. 0 $ <''
  for_c. content do.
    item =. > c
    ctype =. > 'type' gethash_json item
    if. ctype -: 'text' do.
      text =. > 'text' gethash_json item
      if. text -.@-: _1 do. texts =. texts , < > text end.
    end.
  end.
  ; texts ,each <LF
)

NB. ================================================================
NB. Execute an MCP tool by name
NB. y = tool_name ; arguments_json
NB. Returns: result text
mcp_exec_tool =: monad define
  'name args' =. y
  if. 0 = # MCP_TOOLS do. 'ERROR: no MCP tools loaded' return. end.
  NB. Find the tool
  idx =. (0 {"1 MCP_TOOLS) i. < name
  if. idx >: # MCP_TOOLS do. 'ERROR: unknown MCP tool: ' , name return. end.
  sid =. > 3 { idx { MCP_TOOLS
  sid mcp_call name ; args
)

NB. ================================================================
NB. Build tool JSON for MCP tools (for LLM payload)
NB. Mirrors get_ext_tools_json
get_mcp_tools_json =: monad define
  if. 0 = # MCP_TOOLS do. '' return. end.
  r =. ''
  for_i. i. # MCP_TOOLS do.
    name =. > (< i, 0) { MCP_TOOLS
    desc =. > (< i, 1) { MCP_TOOLS
    schema =. > (< i, 2) { MCP_TOOLS
    sid =. > (< i, 3) { MCP_TOOLS
    t_json =. (schema_key '') mk_tool name ; desc ; schema
    if. uses_openai_tools '' do.
      r =. r , ',{"type":"function","function":' , t_json , '}'
    else.
      r =. r , ',' , t_json
    end.
  end.
  r
)

NB. ================================================================
NB. Shutdown an MCP server
NB. y = server_id
NB.
NB. For stdio: send shutdown request, close stdin (EOF), SIGTERM fallback.
NB. For http: send shutdown request via HTTP POST (no subprocess to kill).
mcp_shutdown =: monad define
  row =. y { MCP_SERVERS
  transport =. > 2 { row

  if. transport -: 'http' do.
    NB. HTTP: send shutdown request (best effort, ignore response)
    try.
      MCP_REQ_ID =: MCP_REQ_ID + 1
      req =. '{"jsonrpc":"2.0","id":' , (": MCP_REQ_ID) , ',"method":"shutdown"}'
      y mcp_http_request req
    catch. end.
    NB. Mark server as shut down
    MCP_SERVERS =: ((< '') (< y, 4) } MCP_SERVERS)
    return.
  end.

  NB. stdio transport shutdown
  stdin_write =. > 3 { row
  stdout_read =. > 4 { row
  pid =. > 5 { row

  NB. Step 1: send graceful shutdown request (ignore response/errors)
  try.
    MCP_REQ_ID =: MCP_REQ_ID + 1
    req =. '{"jsonrpc":"2.0","id":' , (": MCP_REQ_ID) , ',"method":"shutdown"}'
    stdin_write sys_write req , LF
    NB. Give the server a moment to process (poll stdout, 2s timeout)
    2000 sys_poll stdout_read
    try. stdout_read sys_read 4096 catch. end.
  catch. end.

  NB. Step 2: close stdin (EOF signals server to exit)
  try. sys_close stdin_write catch. end.

  NB. Step 3: SIGTERM fallback if still alive
  try. pid sys_kill 15 catch. end.
  try. sys_close stdout_read catch. end.

  NB. Mark server as shut down (clear fds)
  MCP_SERVERS =: ((< _1) (< y, 3) } MCP_SERVERS)
  MCP_SERVERS =: ((< _1) (< y, 4) } MCP_SERVERS)
)

NB. ================================================================
NB. Shutdown all MCP servers (for cleanup on exit)
mcp_shutdown_all =: monad define
  for_i. i. # MCP_SERVERS do.
    try. i mcp_shutdown '' catch. end.
  end.
)

echo 'mcp loaded.'
