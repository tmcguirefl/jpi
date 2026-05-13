# Phase 5: File Writing Tool

## Status
✅ Completed

## Implementation
- `src/write_file.ijs`
  - `write_file` – writes text file (uses `fwrites`)
  - `write_file_raw` – binary write (uses `fwrite`)
  - One-liner wrappers with basic try/catch

## Testing
- `tests/test_phase5.ijs` writes a file, verifies content, cleans up

## How to run
```j
load 'jpi/src/write_file.ijs'
write_file 'newfile.txt' ; 'data'

load 'jpi/tests/test_phase5.ijs'
```