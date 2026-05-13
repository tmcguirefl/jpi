# Phase 2: File Reading Tool

## Status
✅ Completed

## Implementation
- `src/read_file.ijs`
  - `read_file` – returns boxed list of lines (with optional max lines)
  - `read_file_str` – convenience wrapper returning a single string

## Testing
- `tests/test_phase2.ijs` creates a temp file, runs basic/limited/string reads, then cleans up

## How to run
```j
load 'jpi/src/read_file.ijs'
read_file 'somefile.txt'
read_file_str 'somefile.txt'

load 'jpi/tests/test_phase2.ijs'
```