NB. Git awareness
NB. git.ijs

NB. Check if cwd is inside a git repo
is_git_repo =: monad define
  try.
    r =. 2!:0 'git rev-parse --is-inside-work-tree 2>/dev/null'
    'true' +./@E. r
  catch.
    0
  end.
)

NB. Get current branch name
git_branch =: monad define
  try.
    _1 }. 2!:0 'git branch --show-current 2>/dev/null'
  catch.
    ''
  end.
)

NB. Get short git status (modified/untracked files)
git_status =: monad define
  try.
    2!:0 'git status --short 2>/dev/null'
  catch.
    ''
  end.
)

NB. Get recent git log (last N commits, one line each)
NB. y = number of commits (default 5)
git_log =: monad define
  n =. 5
  if. 0 < #y do. n =. ". y end.
  try.
    2!:0 'git log --oneline -' , (": n) , ' 2>/dev/null'
  catch.
    ''
  end.
)

NB. Get git diff summary (files changed, not full diff)
git_diff =: monad define
  try.
    2!:0 'git diff --stat 2>/dev/null'
  catch.
    ''
  end.
)

NB. List files tracked by git (respects .gitignore)
git_ls_files =: monad define
  try.
    2!:0 'git ls-files 2>/dev/null'
  catch.
    ''
  end.
)

NB. Build a git context string for the system prompt
git_context =: monad define
  if. -. is_git_repo '' do. '' return. end.
  branch =. git_branch ''
  status =. git_status ''
  ctx =. ' Git repo, branch: ' , branch , '.'
  if. 0 < #status do.
    NB. count changed/untracked files by counting lines
    lines =. <;._2 status , LF -. {: status
    ctx =. ctx , ' ' , (": #lines) , ' changed/untracked files.'
  end.
  ctx
)

echo 'git loaded.'
