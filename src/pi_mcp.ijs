NB. jpi mcp list|add|remove
NB. Does not load the TUI or plugin directories. list connects
NB. only the servers in the user and project mcp.json files.
NB. pi_mcp.ijs

3 : 0 ''
  src =. > 2!:5 'JPI_SRC'
  if. (2 = 3!:0 src) *. 0 < # src do.
    1!:44 src
  end.
  load 'mcp_cfg.ijs'
  mcp_dispatch 2 }. ARGV
  i. 0 0
)
exit 0
