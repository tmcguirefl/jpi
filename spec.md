# J-PI Agent Project Specification

## Overview
This project aims to create a J-language implementation of agentic software similar to the pi coding agent harness. The J-PI agent will utilize J's array processing capabilities and host interface to simulate the functionality of the original pi agent, allowing for file operations, command execution, code editing, and file creation/writing.

## Key Components
- **Tool Emulation**: Replicate pi's tools (read, bash, edit, write) using J primitives and host functions.
- **Agent Loop**: A main loop that interprets user queries, decides on actions, and executes them.
- **Safety and Constraints**: Incorporate basic safety checks (e.g., no arbitrary code execution in J context).

## Development Phases
To ensure incremental progress and testability, development will be broken into phases:

### Phase 1: Project Setup and Basic Structure
- Create directory structure: `jpi/` with subdirs like `src/`, `tests/`, `docs/`.
- Implement basic load script (e.g., `main.ijs`) that loads all necessary components.
- Set up a simple echo-based loop for input/output.
- **Testing**: Verify J environment setup, run a basic "hello world" script.

### Phase 2: File Reading Tool
- Implement a function to read file contents using J's file I/O.
- Handle text files, with considerations for large files (e.g., line limits).
- Add image support if feasible (though J may not have native image reading; use external calls if needed).
- **Testing**: Create test files, read them, and verify content output.

### Phase 3: Command Execution Tool
- Use J's host interface (`!:0` or `2!:0`) to execute bash commands.
- Capture stdout/stderr, handle timeouts (simulate with J's mechanisms).
- **Testing**: Execute simple commands like `ls`, `pwd`, and check outputs.

### Phase 4: Code Editing Tool
- Implement precise file editing: locate text sections, replace exactly.
- Use J's string manipulation for find/replace operations.
- **Testing**: Create test files with known content, perform edits, verify changes.

### Phase 5: File Writing Tool
- Implement file writing/creation, including parent directory creation if needed.
- **Testing**: Write new files, overwrite existing ones, check creation.

### Phase 6: Agent Framework and Decision Loop
- Build a parser for user input (simulate function calls or queries).
- Implement a simple agent loop that maps actions to tool calls (e.g., based on keywords).
- Add basic reasoning (in J, perhaps using conditions or scripts).
- **Testing**: Provide mock inputs, verify correct tool invocation and responses.

### Phase 7: Integration and Advanced Features
- Combine tools into a cohesive agent.
- Add persistence, logging, or self-modification if applicable.
- Refine error handling, add safety measures against harmful inputs.
- **Testing**: Run end-to-end scenarios like reading a file, editing it, then writing back.

## Technologies and Dependencies
- **J Language**: Core language for implementation.
- External tools: Leverage J's ability to call system commands for bash emulation.
- No additional libraries assumed initially; build with standard J features.

## Metrics for Success
- Each phase should be independently testable.
- End product allows scripting file ops and command execution in J.
- Documentation in `jdocs/` can be referenced for J-specific programming questions.

## Next Steps
Begin with Phase 1. Review `jdocs/` for J programming references during development.