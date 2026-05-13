# Phase 3: Command Execution Tool

## Status
✅ Completed

## Implementation
- `src/run_cmd.ijs`
  - Uses `2!:0` (host command foreign)
  - `run_cmd` returns boxed output or error
  - `run_cmd_str` returns raw string

## Testing
- `tests/test_phase3.ijs` runs a couple of basic shell commands

## How to run
```j
load 'jpi/src/run_cmd.ijs'
run_cmd 'ls'
run_cmd_str 'pwd'

load 'jpi/tests/test_phase3.ijs'
```