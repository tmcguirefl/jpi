NB. User and project mcp.json. Add, remove, and list do not
NB. require a plugin directory. A project file is read only
NB. after project trust, and its names replace the user file.
NB. mcp_cfg.ijs

require 'files'
require 'convert/json'
require 'utils.ijs'

NB. Control words at script top level are an invalid inflection
NB. in this J, so the load guard stays inside a verb.
3 : 0 ''
  if. 0 > 4!:0 <'MCP_SERVERS' do.
    load 'mcp.ijs'
  end.
  i. 0 0
)

NB. y = env name. The value comes from the environment, then
NB. from ~/.jpi_providers. The value is never echoed.
mcp_lookup_secret =: monad define
  t =. ''
  try. t =. > 2!:5 y catch. t =. '' end.
  if. (2 = 3!:0 t) *. 0 < # t do. t return. end.
  path =. ''
  if. 0 = 4!:0 <'CONFIG_PROVIDERS_FILE' do.
    path =. CONFIG_PROVIDERS_FILE
  else.
    path =. (> 2!:5 'HOME') , '/.jpi_providers'
  end.
  if. -. fexist path do. '' return. end.
  raw =. fread path
  if. (2 ~: 3!:0 raw) +. 0 = # raw do. '' return. end.
  if. LF ~: {: raw do. raw =. raw , LF end.
  for_l. <;._2 raw do.
    line =. > l
    i =. line i. '='
    if. i < # line do.
      if. y -: i {. line do.
        (i + 1) }. line return.
      end.
    end.
  end.
  ''
)

NB. Replace ${NAME} with mcp_lookup_secret. A missing name
NB. becomes an empty string.
mcp_expand_refs =: monad define
  s =. y
  out =. ''
  i =. 0
  while. i < # s do.
    if. (i + 1) < # s do.
      if. '${' -: 2 {. (i }. s) do.
        rest =. (i + 2) }. s
        k =. rest i. '}'
        if. k < # rest do.
          out =. out , mcp_lookup_secret k {. rest
          i =. i + k + 3
          continue.
        end.
      end.
    end.
    out =. out , i { s
    i =. i + 1
  end.
  out
)

mcp_user_path =: monad define
  t =. ''
  try. t =. > 2!:5 'JPI_MCP_FILE' catch. t =. '' end.
  if. (2 = 3!:0 t) *. 0 < # t do. t return. end.
  (> 2!:5 'HOME') , '/.jpi/mcp.json'
)

mcp_project_path =: monad define
  t =. ''
  try. t =. > 2!:5 'JPI_MCP_PROJECT' catch. t =. '' end.
  if. (2 = 3!:0 t) *. 0 < # t do. t return. end.
  './.jpi/mcp.json'
)

NB. User path ; project path. The project path is '' when
NB. this directory is not trusted.
mcp_load_paths =: monad define
  u =. mcp_user_path ''
  p =. ''
  ok =. 1
  if. 3 = 4!:0 <'project_trusted' do.
    ok =. project_trusted ''
  end.
  if. ok do. p =. mcp_project_path '' end.
  u ; p
)

NB. A missing enabled key leaves the server on. JSON false
NB. (the string json_false), a boolean 0, and the strings
NB. false / 0 turn it off.
mcp_is_enabled =: monad define
  en =. 'enabled' gethash_json y
  if. en -: _1 do. 1 return. end.
  v =. > en
  if. 1 = 3!:0 v do.
    if. 0 = v do. 0 return. end.
  end.
  if. 2 = 3!:0 v do.
    if. 'json_false' -: v do. 0 return. end.
    if. 'false' -: tolower v do. 0 return. end.
    if. '0' -: v do. 0 return. end.
  end.
  1
)

mcp_already =: monad define
  if. 0 = # MCP_SERVERS do. 0 return. end.
  if. (< y) e. 1 {"1 MCP_SERVERS do. 1 else. 0 end.
)

NB. y = name ; config. 0 skips a disabled, duplicate, or
NB. project-replaced server.
mcp_should_load =: monad define
  'name cfg' =. y
  if. 0 = 4!:0 <'MCP_SKIP' do.
    if. (< name) e. MCP_SKIP do. 0 return. end.
  end.
  if. mcp_already name do. 0 return. end.
  mcp_is_enabled cfg
)

NB. y = the mcpServers object from dec_json.
NB. dec_json stores an object as 2 rows (keys, values). A table
NB. that is already one row per server (name ; config) is kept.
NB. Returns a table of name ; boxed config.
mcp_collect =: monad define
  servers =. y
  out =. 0 2 $ <''
  if. 0 = # servers do. out return. end.
  if. 3 = # $ servers do.
    servers =. (2 , {: $ servers) $ , servers
  end.
  if. 2 = {. $ servers do.
    flat =. 1
    for_c. 0 { servers do.
      if. 2 ~: 3!:0 > c do. flat =. 0 end.
    end.
    if. flat do. servers =. |: servers end.
  end.
  for_i. i. # servers do.
    nm =. > (< i, 0) { servers
    cfg =. > (< i, 1) { servers
    if. 3 = # $ cfg do. cfg =. (2 , {: $ cfg) $ , cfg end.
    if. 1 = $$ cfg do. cfg =. 1 ,: cfg end.
    out =. out , 1 2 $ nm ; < cfg
  end.
  out
)

mcp_entries =: monad define
  empty =. 0 2 $ <''
  if. -. fexist y do. empty return. end.
  raw =. fread y
  if. (2 ~: 3!:0 raw) +. 0 = # raw do. empty return. end.
  parsed =. ''
  try. parsed =. dec_json raw catch. empty return. end.
  if. 1 = $$ parsed do. parsed =. , parsed end.
  servers =. 'mcpServers' gethash_json parsed
  if. servers -: _1 do. empty return. end.
  mcp_collect > servers
)

NB. y = rows ; path. Writes mode 600. Headers can hold tokens.
mcp_write =: monad define
  'rows path' =. y
  if. 0 = # rows do.
    text =. '{"mcpServers":{}}'
  else.
    names =. {."1 rows
    cfgs =. {:"1 rows
    servers =. names ,: cfgs
    obj =. (<'mcpServers') ,: < servers
    text =. enc_json obj
  end.
  parent =. (path i: '/') {. path
  if. 0 < # parent do.
    try. 2!:0 'mkdir -p ' , squote parent catch. end.
  end.
  text fwrite path
  try. 2!:0 'chmod 600 ' , squote path catch. end.
  ''
)

NB. y = path ; name ; config object (2-row table).
mcp_put =: monad define
  'path name cfg' =. y
  rows =. mcp_entries path
  out =. 0 2 $ <''
  found =. 0
  for_i. i. # rows do.
    n =. > (< i, 0) { rows
    c =. > (< i, 1) { rows
    if. n -: name do.
      out =. out , 1 2 $ name ; < cfg
      found =. 1
    else.
      out =. out , 1 2 $ n ; < c
    end.
  end.
  if. -. found do.
    out =. out , 1 2 $ name ; < cfg
  end.
  mcp_write out ; path
)

NB. y = path ; name
mcp_drop =: monad define
  'path name' =. y
  rows =. mcp_entries path
  out =. 0 2 $ <''
  for_i. i. # rows do.
    n =. > (< i, 0) { rows
    c =. > (< i, 1) { rows
    if. -. n -: name do.
      out =. out , 1 2 $ n ; < c
    end.
  end.
  mcp_write out ; path
)

NB. y = command ; args ; env lines ; cwd
mcp_stdio_cfg =: monad define
  'command args envp cwd' =. y
  keys =. 'type' ; 'command'
  vals =. 'stdio' ; command
  if. 0 < # args do.
    keys =. keys , < 'args'
    vals =. vals , < args
  end.
  if. 0 < # envp do.
    ek =. 0 $ <''
    ev =. 0 $ <''
    for_p. envp do.
      line =. > p
      i =. line i. '='
      ek =. ek , < i {. line
      ev =. ev , < (i + 1) }. line
    end.
    keys =. keys , < 'env'
    vals =. vals , < ek ,: ev
  end.
  if. 0 < # cwd do.
    keys =. keys , < 'cwd'
    vals =. vals , < cwd
  end.
  keys ,: vals
)

NB. y = url ; header lines ; bearer env name
mcp_http_cfg =: monad define
  'url hdrs bearer' =. y
  hk =. 0 $ <''
  hv =. 0 $ <''
  if. 0 < # bearer do.
    hk =. hk , < 'Authorization'
    hv =. hv , < 'Bearer ${' , bearer , '}'
  end.
  for_p. hdrs do.
    line =. > p
    i =. line i. '='
    hk =. hk , < i {. line
    hv =. hv , < (i + 1) }. line
  end.
  keys =. 'type' ; 'url'
  vals =. 'http' ; url
  if. 0 < # hk do.
    keys =. keys , < 'headers'
    vals =. vals , < hk ,: hv
  end.
  keys ,: vals
)

load_user_and_project_mcp =: monad define
  'u p' =. mcp_load_paths ''
  skip =. 0 $ <''
  if. 0 < # p do.
    if. fexist p do.
      rows =. mcp_entries p
      if. 0 < # rows do. skip =. {."1 rows end.
    end.
  end.
  MCP_SKIP =: skip
  if. fexist u do.
    dir =. (u i: '/') {. u
    if. 3 = 4!:0 <'load_mcp_json' do.
      load_mcp_json dir ; 'user'
    end.
  end.
  MCP_SKIP =: 0 $ <''
  if. 0 < # p do.
    if. fexist p do.
      dir =. (p i: '/') {. p
      if. 3 = 4!:0 <'load_mcp_json' do.
        load_mcp_json dir ; 'project'
      end.
    end.
  end.
  ''
)

mcp_status_lines =: monad define
  if. 0 = # MCP_SERVERS do. 'No MCP servers.' return. end.
  lines =. 0 $ <''
  for_i. i. # MCP_SERVERS do.
    name =. > (< i, 1) { MCP_SERVERS
    kind =. > (< i, 2) { MCP_SERVERS
    sid =. > (< i, 0) { MCP_SERVERS
    n =. 0
    if. 0 < # MCP_TOOLS do.
      for_t. i. # MCP_TOOLS do.
        if. sid -: > (< t, 3) { MCP_TOOLS do. n =. n + 1 end.
      end.
    end.
    lines =. lines , < name , '  ' , kind , '  ' , (": n) , ' tools'
  end.
  ; lines ,each <LF
)

mcp_usage =: monad define
  echo 'usage: jpi mcp list'
  echo '       jpi mcp add <name> [--local] -- <command> [args...]'
  echo '       jpi mcp add <name> [--local] --url <url> [--bearer-env NAME]'
  echo '       jpi mcp remove <name> [--local]'
  ''
)

NB. y = path ; remaining boxed words after the name.
mcp_cli_add =: monad define
  'path words' =. y
  if. 0 = # words do.
    echo 'jpi mcp add needs a server name'
    0 return.
  end.
  name =. > {. words
  rest =. }. words
  url =. ''
  bearer =. ''
  cwd =. ''
  hdrs =. 0 $ <''
  envp =. 0 $ <''
  cmd =. 0 $ <''
  i =. 0
  while. i < # rest do.
    w =. > i { rest
    if. '--' -: w do.
      cmd =. (i + 1) }. rest
      break.
    elseif. '--url' -: w do.
      i =. i + 1
      if. i = # rest do.
        echo 'jpi mcp add --url needs a value'
        0 return.
      end.
      url =. > i { rest
    elseif. '--bearer-env' -: w do.
      i =. i + 1
      if. i = # rest do.
        echo 'jpi mcp add --bearer-env needs a name'
        0 return.
      end.
      bearer =. > i { rest
    elseif. '--cwd' -: w do.
      i =. i + 1
      if. i = # rest do.
        echo 'jpi mcp add --cwd needs a path'
        0 return.
      end.
      cwd =. > i { rest
    elseif. '--header' -: w do.
      i =. i + 1
      if. i = # rest do.
        echo 'jpi mcp add --header needs KEY=VALUE'
        0 return.
      end.
      hdrs =. hdrs , i { rest
    elseif. '--env' -: w do.
      i =. i + 1
      if. i = # rest do.
        echo 'jpi mcp add --env needs KEY=VALUE'
        0 return.
      end.
      envp =. envp , i { rest
    else.
      echo 'jpi mcp add: unknown option ' , w
      0 return.
    end.
    i =. i + 1
  end.
  if. 0 < # url do.
    cfg =. mcp_http_cfg url ; hdrs ; bearer
  else.
    if. 0 = # cmd do.
      echo 'jpi mcp add needs -- <command> or --url'
      0 return.
    end.
    command =. > {. cmd
    args =. }. cmd
    cfg =. mcp_stdio_cfg command ; args ; envp ; cwd
  end.
  mcp_put path ; name ; < cfg
  echo 'Added MCP server ' , name
  1
)

NB. y = boxed argument list (the words after "jpi mcp").
mcp_dispatch =: monad define
  args =. y
  local =. 0
  rest =. 0 $ <''
  for_a. args do.
    w =. > a
    if. '--local' -: w do.
      local =. 1
    elseif. '-l' -: w do.
      local =. 1
    else.
      rest =. rest , < w
    end.
  end.
  if. 0 = # rest do.
    mcp_usage ''
    2!:55 (2) return.
  end.
  cmd =. > {. rest
  tail =. }. rest
  if. local do.
    path =. mcp_project_path ''
  else.
    path =. mcp_user_path ''
  end.
  if. 'list' -: cmd do.
    if. 3 ~: 4!:0 <'load_mcp_json' do.
      load 'plugins.ijs'
    end.
    MCP_LOAD_FAIL =: 0
    load_user_and_project_mcp ''
    echo mcp_status_lines ''
    if. MCP_LOAD_FAIL do. 2!:55 (1) end.
  elseif. 'remove' -: cmd do.
    if. 0 = # tail do.
      echo 'jpi mcp remove needs a server name'
      2!:55 (2) return.
    end.
    mcp_drop path ; > {. tail
    echo 'Removed MCP server ' , > {. tail
  elseif. 'add' -: cmd do.
    if. 0 = mcp_cli_add path ; < tail do.
      2!:55 (2)
    end.
  else.
    mcp_usage ''
    2!:55 (2)
  end.
  ''
)
