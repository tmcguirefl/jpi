NB. Confirmation prompts for destructive operations
NB. confirm.ijs

NB. Whether confirmations are enabled (1=on, 0=off)
CONFIRM_ENABLED =: 1

NB. Patterns that trigger confirmation for write/edit
PROTECTED_PATTERNS =: '/etc';'/usr';'/bin';'/sbin';'/System';'/Library'

NB. Ask user for y/n confirmation. Returns 1 if confirmed.
NB. y = prompt string
confirm =: monad define
  if. -. CONFIRM_ENABLED do. 1 return. end.
  echo y , ' [y/n] '
  resp =. tolower 1!:1 ] 1
  'y' -: resp
)

NB. Check if a path is in a protected location
is_protected =: monad define
  prot =. 0
  for_p. PROTECTED_PATTERNS do.
    if. (> p) +./@E. y do. prot =. 1 end.
  end.
  prot
)

NB. Confirm before writing to a path. Returns 1 if OK to proceed.
confirm_write =: monad define
  if. -. CONFIRM_ENABLED do. 1 return. end.
  if. is_protected y do.
    confirm 'Write to protected path ' , y , '?'
  elseif. fexist y do.
    confirm 'Overwrite existing file ' , y , '?'
  elseif. do.
    1                                NB. new file in non-protected path, no confirm
  end.
)

NB. Confirm before editing a file. Returns 1 if OK to proceed.
confirm_edit =: monad define
  if. -. CONFIRM_ENABLED do. 1 return. end.
  if. is_protected y do.
    confirm 'Edit file in protected path ' , y , '?'
  else.
    1                                NB. normal file, no confirm needed
  end.
)

echo 'confirm loaded.'
