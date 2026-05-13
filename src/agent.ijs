NB. Phase 6 (final): Agent using standard tolower, boxed strings, and inline agenda
NB. agent.ijs

load 'read_file.ijs'
load 'run_cmd.ijs'
load 'edit_file.ijs'
load 'write_file.ijs'

NB. ----------------------------------------------------------------
NB. Verb definitions first (so they exist when the agenda line runs)
read_verb   =: 3 : 'echo ''Reading file...''; read_file_str ''README.md'''
run_verb    =: 3 : 'echo ''Running command...''; run_cmd_str ''ls'''
edit_verb   =: 3 : 'echo ''Editing file...'''
write_verb  =: 3 : 'echo ''Writing file...'''
unknown_verb =: 3 : 'echo ''Unknown command'''

NB. Boxed action names (semicolon literal style)
ACTIONS =: 'read';'run';'edit';'write'

NB. Fast lookup (i. uses hash internally)
get_action_index =: ACTIONS&i.@:(tolower)

NB. Agent verb – inline agenda @.
agent =: read_verb`run_verb`edit_verb`write_verb`unknown_verb @. get_action_index

echo 'Phase 6: agent loaded (tolower + boxed strings + inline agenda)'