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
| 5 | **Parallel Tool Execution**    | LLM can request multiple tools; executed concurrently | Serial execution (parallel attempt shelved — see §4) | Low | J's `convert/json` and `2!:0` are not thread-safe; ROI is low |
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
| **Parallel Tools**      | Not currently viable in stock J — see §4 *J Threading Limitations*. If revisited, replace `2!:0` with a `posix_spawn` binding or tempfile + sentinel pattern, and either serialize all `dec_json` calls in the main thread or swap to a re-entrant JSON parser. |
| **Compaction**          | Create `compaction.ijs` that summarizes the last N turns when the token budget is exceeded |
| **Syntax Highlighting** | Extend `md.ijs` or shell out to an external highlighter (e.g., `highlight`, `bat`) |
| **Diff Rendering**      | Shell out to `git diff --no-color` or implement a simple unified diff renderer in J |
| **Schema Validation**   | Build a lightweight JSON Schema validator (or use a restricted safe subset) |

---

## 4. J Threading Limitations (Learned from the v0.x Parallel-Tools Spike)

During an attempt to implement Feature 5 (Parallel Tool Execution) using J's
native threading primitives (`T.` / `t.`), we discovered two hard blockers in
the J 9.x ecosystem that make parallel tool execution far less attractive
than it appears on paper. The work was reverted but the findings are recorded
here so anyone picking this up later doesn't have to re-discover them.

### 4.1 The threading model itself works fine for pure J

J has a clean, lock-free worker-thread model:

- `{{0 T. 0}}^:N ''` adds `N` worker threads to the pool. `0 T. ''` reports
  the current pool size, and `8 T. ''` reports the number of CPU cores.
- A verb modified with `t.` runs asynchronously when applied; the call returns
  a *pyx* (a placeholder “promise”) immediately.
- Reading the pyx with `>` (or anything that needs its value) blocks the
  calling thread until the worker finishes.
- `f t. '' each boxed_list` is the idiomatic way to fan a verb out across a
  list with one worker per item.

For pure J computation (e.g. mapping a CPU-bound verb over an array) we
measured the expected ~2× speed-up on a 2-element parallel fan-out on M-series
hardware. So J's threading itself is sound; the problem is what we want to
call *from inside* a worker.

### 4.2 `convert/json` is not thread-safe

The stock J JSON library (`/Applications/j9.8/addons/convert/json/json.ijs`)
implements `dec_json` using **two module-level globals**:

```j
token=: 3 : 0
(_1+I=: I+1){::T
)

dec_json=: 3 : 0
T=: words (LF,' ') charsub y-.CR   NB. mutates global T
I=: 0                                 NB. mutates global I
>getVal token''
)
```

When two worker threads call `dec_json` concurrently, they race on `T` and
`I`, producing corrupted token streams that trip the assertions inside
`gethash_json`, `getPair`, etc. The symptoms we saw in practice were:

- `|assertion failure: assert`
- `|assertion failure in gethash_json_json_`
- `|domain error: process_tool_calls (from pyx)`
  `incompatible: character, numeric, and boxed`

The “incompatible” errors are downstream of the assertion failure: one thread’s
half-parsed result trickles back into `HISTORY` and then `,&','` chokes on the
mixed types in a later `build_payload` call.

**Workarounds, in order of effort:**

1. **Parse serially in the main thread, dispatch only execution to workers.**
   This is what we tried as a last fix: `parse_or_tool_call each calls` runs in
   the main thread (single-threaded, safe), and only `exec_tool` is sent to the
   worker pool. This eliminates the JSON race but doesn't solve the next problem
   (§4.3) so the overall speed-up is negligible.
2. **Wrap `dec_json` in a mutex.** J has no built-in mutex primitive; you would
   need a file-lock or sentinel + spin pattern, which is awkward and slow.
3. **Use a re-entrant JSON parser.** Either:
   - A hand-written J parser that takes the token state as an explicit parameter
     instead of using globals, or
   - A `cd` binding to a C library like `json-c` or `cJSON` whose context is
     passed in by the caller.
   This is the only “clean” fix but it's a substantial undertaking that
   touches every place we currently call `dec_json` / `gethash_json`.

### 4.3 `2!:0` (shell escape) holds a global lock

Even once JSON is out of the way, the `bash` tool ultimately calls `2!:0` to
spawn a shell and capture its stdout. Measurements on macOS showed:

| Workload                              | Serial | Parallel | Ratio |
|---------------------------------------|--------|----------|-------|
| Pure J `+/ 1 p: i. 200000` ×2         | 4.3 ms | 2.0 ms   | 2.15× |
| `2!:0 'sleep 2 && echo done'` ×2      | 4.02 s | 4.02 s   | 1.00× |

Dispatching the threads via `t. ''` returns immediately (< 20 ms), so the
workers really are running concurrently — but `2!:0` itself serialises behind
a global mutex inside the J runtime (it has to capture stdout into a thread-
safe buffer). The kernel never gets a chance to run the two `sleep`s in
parallel.

**Workarounds, in order of effort:**

1. **Tempfile + sentinel.** `2!:1` (foreground, no capture) returns the moment
   the child is forked into the background, so:

   ```j
   2!:1 '( ' , cmd , ' >' , out , ' 2>&1 ; touch ' , done , ' ) &'
   ```

   Each worker writes its command to its own `/tmp/jpi_out_<uniq>`, polls the
   sentinel file, and reads the captured output once it appears. The kernel
   runs the children genuinely in parallel; J is doing nothing but polling.
   This is the pattern already prototyped in `attic/test_pipe2.ijs`. About
   30–40 lines in `src/run_cmd.ijs`.
2. **`cd` binding to `posix_spawn(3)`.** The canonical thread-safe POSIX way
   to launch a child process. Available on Linux glibc and macOS libc. About
   150 lines of `cd` plumbing (pipes, file actions, `waitpid`), but no temp
   files and no polling. Pi's Rust implementation uses the equivalent via
   `tokio::process::Command`, which is built on top of `posix_spawn` (or
   `clone3` / `pidfd_spawn` on modern Linux).
3. **Replace `run_cmd.ijs` with a small helper binary** (e.g. a Go program) and
   shell out to *that* once per worker. Avoids `2!:0` entirely but adds a
   build step.

### 4.4 Why we shelved Feature 5

Even assuming both blockers above are addressed, the wall-clock benefit on a
realistic LLM workload is small:

- `read` / `edit` / `write` tools take 1–50 ms each. Parallelising ten of them
  saves a few hundred milliseconds at most — imperceptible.
- Long-running `bash` calls (the case where parallel matters) almost never
  appear *in pairs* in a single LLM turn. A typical turn is many small reads
  plus zero or one long shell call.

Meanwhile the cost is non-trivial: a re-entrant JSON parser **and** a
thread-safe shell primitive, plus ongoing maintenance to keep both paths in
sync with the rest of the codebase. The trade-off lands clearly on the side
of staying serial until we have a concrete user-visible need (e.g. an LLM
benchmark that systematically emits many parallel long-running tool calls).

The earlier-than-threading work from the spike was kept because it stands on
its own merits:

- `<thinking>` / `<think>` block instructions in `system_prompt.ijs`
  (real ReAct loop nudge).
- Per-tool required-parameter validation in `tool_exec.ijs`
  (Feature 4 — partially done).
- `try/catch` error reporting around `exec_tool` so a single tool failure
  no longer kills the loop.

### 4.5 If someone revisits this

The shortest path back to a working parallel implementation is:

1. Parse the entire `tool_calls` array in the main thread (already done in
   `process_tool_calls` of the reverted branch — see git history for commit
   `1590d07` and onward).
2. Implement `run_cmd_parallel` in `src/run_cmd.ijs` using the tempfile +
   sentinel pattern from `attic/test_pipe2.ijs`. **Do this first — it's the
   change that actually buys speed-up.**
3. Re-enable the `t. '' each` dispatch in `process_tool_calls` once
   `run_cmd_parallel` exists.
4. Add an integration test that fans out two long-running `bash` calls and
   asserts the wall-clock time is < 1.5× the single-call time.

Do not attempt step 3 before step 2 — you will spend a lot of time chasing
pyx unboxing edge cases for no measurable benefit.

---

## 5. Open Questions & Next Steps

- Should we keep the pure escape-code TUI as the only interface, or also revive (or modernize) the ncurses version for users who prefer it?
- What is the preferred JSON library going forward (`enc_json_fixed.ijs` vs a new binding)?
- How aggressively should we pursue image rendering support (Kitty graphics protocol vs iTerm2 inline images)?
- Do we want to maintain compatibility with both OpenRouter and Anthropic APIs, or focus on one primary provider?

---

**Last updated:** 2026-05-22  
**Maintainer:** Tom McGuire (with contributions from the Pi Agent)