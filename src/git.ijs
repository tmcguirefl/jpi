NB. Git awareness
NB. git.ijs

NB. Check if cwd is inside a git repo
NB. Tacit: 'true' found in command output, fallback 0 via :: (adverse)
NB. Explicit original:
NB.   is_git_repo =: monad define
NB.     try.
NB.       r =. 2!:0 'git rev-parse --is-inside-work-tree 2>/dev/null'
NB.       'true' +./@E. r
NB.     catch.
NB.       0
NB.     end.
NB.   )
is_git_repo =: (('true'&(+./@E.)) @ (2!:0) @ ('git rev-parse --is-inside-work-tree 2>/dev/null'"_)) :: 0:

NB. Get current branch name
NB. Tacit: drop trailing newline from command output, fallback ''
NB. Explicit original:
NB.   git_branch =: monad define
NB.     try.
NB.       _1 }. 2!:0 'git branch --show-current 2>/dev/null'
NB.     catch.
NB.       ''
NB.     end.
NB.   )
git_branch =: (_1&}. @ (2!:0) @ ('git branch --show-current 2>/dev/null'"_)) :: ''":

NB. Get short git status (modified/untracked files)
NB. Tacit: command output, fallback ''
NB. Explicit original:
NB.   git_status =: monad define
NB.     try.
NB.       2!:0 'git status --short 2>/dev/null'
NB.     catch.
NB.       ''
NB.     end.
NB.   )
git_status =: (2!:0 @ ('git status --short 2>/dev/null'"_)) :: ''":

NB. Get recent git log (last N commits, one line each)
NB. y = number of commits (default 5)
NB. Left explicit: dynamic string building with default count doesn't
NB. compose cleanly in tacit — the agenda + string concat + 2!:0 chain
NB. creates parsing ambiguity. Not worth forcing.
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
NB. Tacit: command output, fallback ''
NB. Explicit original:
NB.   git_diff =: monad define
NB.     try.
NB.       2!:0 'git diff --stat 2>/dev/null'
NB.     catch.
NB.       ''
NB.     end.
NB.   )
git_diff =: (2!:0 @ ('git diff --stat 2>/dev/null'"_)) :: ''":

NB. List files tracked by git (respects .gitignore)
NB. Tacit: command output, fallback ''
NB. Explicit original:
NB.   git_ls_files =: monad define
NB.     try.
NB.       2!:0 'git ls-files 2>/dev/null'
NB.     catch.
NB.       ''
NB.     end.
NB.   )
git_ls_files =: (2!:0 @ ('git ls-files 2>/dev/null'"_)) :: ''":

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
