# Phase 4: Code Editing Tool

## Status
✅ Completed

## Implementation
- `src/edit_file.ijs`
  - `edit_file` takes `filename ; oldstring ; newstring`
  - Replaces the **first** exact occurrence
  - Returns `1` on success, `0` otherwise

## Testing
- `tests/test_phase4.ijs` creates a test file, performs a precise edit, verifies result

## How to run
```j
load 'jpi/src/edit_file.ijs'
edit_file 'file.txt' ; 'old line' ; 'new line'

load 'jpi/tests/test_phase4.ijs'
```