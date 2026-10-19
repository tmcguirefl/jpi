NB. Phase 7: Safety checks
NB. safety.ijs

load 'utils.ijs'

NB. Blocked commands (dangerous shell operations)
NB. Patterns are checked against the NORMALIZED command (lowercase,
NB. whitespace collapsed to single spaces).
BLOCKED =: 'rm -rf';'rm -fr';'rm -r -f';'rm -f -r'
BLOCKED =: BLOCKED , 'dd if=';'dd of='
BLOCKED =: BLOCKED , 'mkfs';'shred';'wipe'
BLOCKED =: BLOCKED , ':(){';':() {'
BLOCKED =: BLOCKED , '> /dev';'>> /dev'
BLOCKED =: BLOCKED , '| sh';'|sh';'| bash';'|bash';'| zsh';'|zsh'
BLOCKED =: BLOCKED , 'chmod -r 777 /';'chmod -R 777 /'

NB. Normalize a command for safety checking:
NB. lowercase, tabs to spaces, collapse multiple spaces to single
norm_cmd =: monad define
  cmd =. tolower y
  cmd =. cmd rplc (9{a.);' '
  parts =. <;._2 cmd , ' '
  nonempty =. parts #~ 0 < #&> parts
  if. 0 = # nonempty do. '' return. end.
  ; _1 }. ; (,&' ')&.> nonempty
)

NB. Check if a command string contains any blocked pattern
NB. y = command string
NB. Returns 1 if safe, 0 if blocked
is_safe =: monad define
  cmd =. norm_cmd y
  safe =. 1
  for_b. BLOCKED do.
    if. (> b) +./@E. cmd do. safe =. 0 end.
  end.
  safe
)

echo 'Phase 7: safety loaded.'
