NB. Phase 7: Safety checks
NB. safety.ijs

NB. Blocked commands (dangerous shell operations)
BLOCKED =: 'rm -rf';'mkfs';'dd if=';':(){';'> /dev'

NB. Check if a command string contains any blocked pattern
is_safe =: monad define
  cmd =. tolower y
  safe =. 1
  for_b. BLOCKED do.
    if. (> b) +./@E. cmd do. safe =. 0 end.
  end.
  safe
)

echo 'Phase 7: safety loaded.'
