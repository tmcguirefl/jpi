# Phase 2: File Reading Tool

## Status
✅ Completed (revised)

## Key Point
J already provides the library verb `fread` which reads an entire file as a character string.
We now wrap it cleanly for:
- line-limited reads
- boxed line list output

## Implementation
- `src/read_file.ijs`
  - Uses built-in `fread`
  - `read_file` – returns boxed list of lines (optional max lines)
  - `read_file_str` – returns full string

## Testing
- `tests/test_phase2.ijs` uses `fread` indirectly and passes

## How to run
```j
load 'jpi/src/read_file.ijs'
read_file 'somefile.txt'
read_file_str 'somefile.txt'

load 'jpi/tests/test_phase2.ijs'
```