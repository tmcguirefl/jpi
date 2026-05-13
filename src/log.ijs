NB. Phase 7: Logging
NB. log.ijs

LOGFILE =: 'jpi.log'

NB. Append a timestamped line to the log file
log =: monad define
  ts =. 6!:0 ''
  stamp =. ": <. 3 {. ts
  entry =. stamp , ' ', y , LF
  entry fappend LOGFILE
)

echo 'Phase 7: log loaded.'
