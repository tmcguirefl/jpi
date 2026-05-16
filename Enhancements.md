# J-PI — Enhancements & Future Roadmap

This document captures the gap between the current J-PI implementation and the
more advanced capabilities present in the reference Rust implementation
(`pi_agent_rust` by Dicklesworthstone). The goal is to reach feature parity
while respecting J’s strengths (array processing, conciseness, and the
existing `j-kvm` / escape-code TUI architecture).

---

## 1. Feature Parity Matrix

| # | Area                        | Feature in `pi_agent_rust`                          | Current J-PI Status          | Priority | Notes / J-Specific Challenges |
|---|-----------------------------|-----------------------------------------------------|------------------------------|----------|-------------------------------|
| 1 | **Reasoning Loop**             | Full ReAct + self-critique with multiple iterations | Basic single-turn tool loop  | High     | Need explicit “think → tool → observe” cycle |
| 2 | **Streaming LLM Responses**    | Full token streaming with live rendering            | Blocking HTTP only           | High     | Requires async HTTP + incremental TUI render |
| 3 | **Thinking / Reasoning Blocks**| `<think>` / `<thinking>` rendered as collapsible sections | No support                | High     | Easy to add in `md.ijs` |
| 4 | **Tool System**                | Strongly typed tools + JSON schema validation       | Simple string dispatch       | High     | Need schema validation layer |
| 5 | **Parallel Tool Execution**    | LLM can request multiple tools; executed concurrently | Serial execution only     | High     | Requires threading or cooperative multitasking |
| 6 | **Context Compaction**         | Hierarchical summarization with budget control      | Basic token counting         | High     | Complex but feasible with J primitives |
| 7 | **Session Management**         | Full session tree, branching, renaming              | Single chat + input history  | Medium   | Need session file format + selector |
| 8 | **Model Router & Switching**   | Dynamic model selection + fallback                  | Hardcoded single model       | Medium   | Add `/model` command + routing |
| 9 | **Rich Cost & Usage Display**  | Real-time cost, token, cache bar                    | Basic numeric counters       | Medium   | Enhance footer with visual progress |
|10 | **Code Block Actions**         | Copy / Apply diff / Run in shell                    | Markdown only                | Medium   | Requires TUI hotkeys + diff engine |
|11 | **Diff Highlighting**          | Visual unified diffs on file edits                  | No visual diffs              | Medium   | Can shell out to `git diff` or implement |
|12 | **Tool Sandboxing**            | Commands run in restricted environments             | Direct `2!:0`                | Medium   | Hard in J; wrapper script possible |
|13 | **Plugin / Extension System**  | Dynamic tool + UI overlay loading                   | Basic extension loader       | Low-Med  | Extend `extensions.ijs` |
|14 | **Observability**              | Structured logging, tracing, export                 | Minimal logging              | Low      | Improve `log.ijs` |
|15 | **TUI Polish**                 | Multi-pane, images, per-language syntax highlighting, smooth paging | Single-pane + basic markdown | Medium   | Syntax highlighting is a big win |
|16 | **Auto-compaction**            | Automatic summary when context exceeds threshold    | None                         | Medium   | Critical for long sessions |
|17 | **Keybinding Customization**   | Configurable keybindings                            | Hardcoded                    | Low      | Load from `config.ijs` |

---

## 2. Recommended Phased Roadmap

### Phase 1 – Reasoning & Streaming (v0.3)
- Implement proper ReAct loop with explicit thinking steps
- Add LLM streaming support (`http_post_stream`)
- Render `<thinking>` blocks as dimmed, collapsible sections

### Phase 2 – Robust Tooling (v0.4)
- JSON Schema validation for tool arguments
- Parallel tool execution (via `fork` or cooperative job queue)
- Improved error recovery and retry logic with backoff

### Phase 3 – Context Intelligence (v0.5)
- Hierarchical compaction (short-term + long-term memory)
- Auto-compaction trigger with user-configurable budget
- Session tree / branching support with naming and persistence

### Phase 4 – Developer Experience (v0.6)
- Per-language syntax highlighting inside code blocks
- Inline unified diff viewer for file edits
- Code block actions: Apply, Run, Copy

### Phase 5 – Full Parity (v1.0)
- Model routing with cost/performance heuristics
- Plugin system with overlay UI components
- Sandboxed command execution
- Rich multi-pane TUI with inline images

---

## 3. Technical Recommendations for J

| Goal                    | Recommendation |
|-------------------------|----------------|
| **Streaming**           | Use `curl --no-buffer` or a lightweight libcurl binding; yield tokens incrementally into the TUI |
| **Parallel Tools**      | Implement a simple job queue using `2!:0` background processes |
| **Compaction**          | Create `compaction.ijs` that summarizes the last N turns when the token budget is exceeded |
| **Syntax Highlighting** | Extend `md.ijs` or shell out to an external highlighter (e.g., `highlight`, `bat`) |
| **Diff Rendering**      | Shell out to `git diff --no-color` or implement a simple unified diff renderer in J |
| **Schema Validation**   | Build a lightweight JSON Schema validator (or use a restricted safe subset) |

---

## 4. Open Questions & Next Steps

- Should we keep the pure escape-code TUI as the only interface, or also revive (or modernize) the ncurses version for users who prefer it?
- What is the preferred JSON library going forward (`enc_json_fixed.ijs` vs a new binding)?
- How aggressively should we pursue image rendering support (Kitty graphics protocol vs iTerm2 inline images)?
- Do we want to maintain compatibility with both OpenRouter and Anthropic APIs, or focus on one primary provider?

---

**Last updated:** 2025-05-16  
**Maintainer:** Tom McGuire (with contributions from the Pi Agent)