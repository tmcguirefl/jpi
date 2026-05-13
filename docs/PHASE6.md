# Phase 6: Agent Framework and Decision Loop

## Status
✅ Completed

## Core Components
- `src/agent.ijs`
  - Loads all previous tools
  - Simple keyword parser (`parse_action`)
  - `agent` verb that reacts to a sentence

## Testing
- `tests/test_phase6.ijs` tests the parser and runs a live demo

## How to use
```j
load 'jpi/src/agent.ijs'
agent 'run ls'
agent 'read the file'
```