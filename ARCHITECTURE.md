# jpi Architecture

jpi is an LLM coding agent written in J: a multi-provider chat client with
tool use (read/bash/edit/write/j), an interactive TUI, headless RPC/serve
frontends, Agent-Plugins v1.0.0 support (skills + MCP), and a safety and
escalation-ladder layer around tool execution.

Everything below `src/` runs inside one long-lived `jconsole` process; J
locale isolation, the `echo` stderr/stdout split, and a 2-row-table JSON
convention are the load-bearing idioms throughout.

## Entry point and run modes

`jpi` (bash launcher) resolves its own directory, sources the untracked
`local/env.sh` (JBIN, JPI_JCORE — see `local/env.example`), finds and
validates J's `jconsole` (rejecting Java's homonym by evaluating `i. 3`),
exports `JPI_SRC`, and dispatches:

| Mode      | Command            | Entry script        | Shape |
|-----------|--------------------|---------------------|-------|
| TUI       | `jpi`              | `src/tui_run.ijs`   | Full-screen VT terminal UI |
| Print     | `jpi -p "prompt"`  | `src/pi_print.ijs`  | One ask, reply only on stdout, no session |
| RPC       | `jpi rpc`          | `src/pi_rpc.ijs`    | Interactive JSONL on stdin/stdout |
| Serve     | `jpi serve`        | `src/pi_serve.ijs`  | Same JSONL over TCP (default port 8765) |

Print/RPC/Serve share one protocol module, `pi_proto.ijs` (command objects
in, event objects out, one JSON per line). Serve owns the session(s):
clients attach, drive it, and detach without killing state.

## Module map (`src/`)

Foundation (no agent knowledge):

- `config.ijs` — provider table (URL, env key, routing prefix per
  provider: openrouter/anthropic/cohere/google/mistral/hyai/local/ollama/
  tcm), model→provider inference, context-window limits, dynamic window
  probe. Loaded first; must not touch the network at load time.
- `enc_json_fixed.ijs` — JSON encoder; fixes over `convert/json` for
  nested boxed structures, with a UTF-8-safe escaper (byte-identical
  round-trips). JSON objects are represented as 2-row tables
  (row 0 keys, row 1 values); this convention is everywhere.
- `utils.ijs` — shared string utilities. `lineio.ijs` — line-by-line
  stdin via libc `read(2)` (J has no portable line reader for pipes).
- `log.ijs`, `usage.ijs` — logging, token/cost tracking.

Agent core:

- `agent.ijs` — integrated dispatcher; loads and links the whole stack,
  runs plugin discovery, handles commands (direct and LLM-backed), model
  listing/selection.
- `llm.ijs` — HTTP client + tool loop: payload build, provider-switched
  response parsing, tool-call extraction, history management and replay
  hardening, steering (mid-run user input), `/think` budgets, transient
  retry budget.
- `tool_exec.ijs` — tool-call dispatcher (read/bash/edit/write/j plus
  MCP-sourced tools), error classification, and the **escalation
  ladder** for repeated failures (error hints → manual pointer →
  J-CORE excerpt → thrash verdict at rung 6 via `jev.ijs`).
- `session.ijs` — save/load conversation history under `~/.jpi/sessions`.
- `safety.ijs` + `confirm.ijs` — blocked-command list (normalized
  prefix matching) and interactive confirmation for writes/deletes
  (auto-approved in headless/bench contexts via `CONFIRM_ENABLED`).

Tools themselves: `read_file.ijs`, `run_cmd.ijs` (timeout + kill),
`edit_file.ijs`, `write_file.ijs`, `git.ijs`, `image.ijs`, `md.ijs`
(markdown→ANSI), `context.ijs`.

Extensibility:

- `plugins.ijs` — Agent Plugins v1.0.0 discovery (`plugin.json`,
  jpi-shipped + `~/.jpi/plugins` + project-local, gated by directory
  trust).
- `skills.ijs` — Agent Skills: `SKILL.md` frontmatter parsed and
  injected into the system prompt (skills are instructions, not code).
- `extensions.ijs` — project-local `.ijs` extensions adding tools.
- `mcp.ijs` — MCP client, stdio (libc pipe/fork via `15!:0`) and HTTP
  transports; initialize / tools/list / tools/call / shutdown.

Frontends:

- `tui.ijs` — full-screen UI on vendored `vendor/vt.ijs` escape codes;
  scrollback, render-time UTF-8/ANSI-safe wrapping in `lineio`-style
  rows, spinner during inference; window size via
  `vendor/winsize.c` dlopen (`_1` fallback when absent — Linux/macOS
  need a locally compiled `.so`/`.dylib`).
- `pi_proto.ijs`, `pi_rpc.ijs`, `pi_serve.ijs` — headless frontends
  (see above). `pi_print.ijs` for one-shots.

## Key flows

LLM turn (all modes):
```
user input → HISTORY (user msg)
  → build_payload (system prompt + sanitized history [+ tools])
  → llm_call (vendor HTTP, transient 4xx/5xx same-body retry)
  → is_tool_call? → tool_exec (safety → confirm → tool; errors feed
    the escalation ladder) → tool results appended → loop
  → text reply → strip <thinking> spans → HISTORY → display
```

The **echo chokepoint**: `echo` is the single console-printer in the
codebase. The TUI redefines it to route into its render buffer (~log
events); `pi_proto` redefines it to emit JSONL `log` events; print mode
suppresses it — this is how one tool loop serves every frontend without
printf surgery.

**History replay hardening** (`llm.ijs`): strict chat deserializers
(hyai) reject assistant messages missing a string `content`;
`fix_assistant_content` enforces it on every request. The no-tools
fallback additionally runs `strip_tool_msgs`: replaying tool_calls with
no tools declared is what cohere flags as
`HALLUCINATED_ALL_TOOL_CALLS`.

## The j tool escalation ladder

The j tool lets the model *run* J instead of only predicting it —
but models get stuck: bench runs showed repeated same-error spirals
burning ~220k tokens before giving up. The ladder (`tool_exec.ijs`
`jfail_text`, verdicts in `jev.ijs`) attaches graduated help to
each failure, tracked per **error signature** (normalized error
text), not per attempt — fixing one bug doesn't reset another's
count. Resubmitting identical code is detected separately and met
with a "run the PIECES separately" nudge. Rungs, by same-signature
failure count:

1. **one-line J-CORE hint** for the observed error family.
2. **the full manual section** behind that hint.
3. **permission to retreat from tacit to explicit** — "a working
   explicit answer beats a broken tacit one."
4. **search-the-manual pointer** plus the explicit fail count.
5. **J wiki/forum search via MCP tools** — only offered when MCP
   tools are actually loaded; the manual covers observed failure
   families, the wiki documents everything.
6. **thrash verdict** (`jev_verdict`): a decision-model reviews the
   recent turns and returns PROGRESS or THRASH; THRASH appends an
   explicit-retreat nudge, PROGRESS a change-one-thing line. Any
   engine failure (no key, no network) adds nothing — the rung
   degrades silently and never blocks the run.
7. **escalated one-shot solver** — on a THRASH verdict the stuck
   fragment is handed to a stronger model (`LADDER_MODEL`, unset
   degrades silently); its proposal returns to the *main* model,
   which must verify it with the j tool before adopting it.

`.ijs` writes via the write tool enter the same ladder (a load check
feeds failures into the shared signature counter), so file-write
spirals get the same treatment as j spirals. The thresholds
(healthy models converge by attempt 3; thrashers hit 25+) come from
benchmark observation, not intuition.

## Conventions worth knowing before touching code

- **JSON objects** = 2-row boxed tables; `gethash_json` returns `_1`
  for a missing key (not boxed, not an error) — test with `_1 -: y`.
- **Errors as strings**: tools return `ERROR: ...` strings rather than
  throwing; `is_error` checks the prefix.
- **No network at load**: `config.ijs` and friends load in headless
  bench drivers; provider network calls happen only at call time.
- **API keys** come only from `~/.jpi_providers` (`NAME=VALUE`, 0600)
  via `curl -K` config files, so keys never appear in `ps aux`.
- **Tests**: `jconsole tests/run_all.ijs` from the repo root — spawns
  each `tests/test_*.ijs` as a subprocess; 24 suites at submission time.
