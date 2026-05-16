NB. Diagnose terminal size detection
require 'tangentstorm/j-kvm/vt'

NB. Check what stty size returns
raw_stty =: 2!:0 'stty size'
echo 'stty size raw: ' , raw_stty

NB. Check tput
lines =: 2!:0 'tput lines'
cols  =: 2!:0 'tput cols'
echo 'tput lines: ' , lines
echo 'tput cols: ' , cols

NB. Check what gethw returns
hw =: gethw_vt_''
echo 'gethw_vt_: ' , ": hw

echo ''
echo 'Now entering raw mode and checking again...'
raw_vt_ 1

raw_stty2 =: 2!:0 'stty size'
echo 'stty size raw (after raw): ' , raw_stty2

hw2 =: gethw_vt_''
echo 'gethw_vt_ (after raw): ' , ": hw2

raw_vt_ 0
echo 'Done.'
