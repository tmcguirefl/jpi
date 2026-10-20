# J-PI — A J-Language Agentic Coding Assistant

J-PI is a terminal-based agentic coding assistant written entirely in the
[J programming language](https://www.jsoftware.com). It provides an
interactive TUI (Text User Interface) for conversing with LLMs, executing
tools (file read/write, shell commands, code editing), and working within
a project directory — similar in spirit to the
[pi coding agent](https://github.com/earendil-works/pi/tree/main/packages/coding-agent).

## Quick Start

```bash
./jpi
```

### Run Modes

| Mode | Command | Use |
|------|---------|-----|
| Interactive TUI (default) | `jpi` | Conversational sessions |
| Print | `jpi -p "prompt"` | One-shot: run the prompt through the full agent loop, print only the reply on stdout, exit. Fresh context — sessions are untouched |
| RPC | `jpi rpc` | Interactive JSONL: command objects on stdin, event objects on stdout, one per line. Commands process as they arrive (the peer may hold the pipe open); runs until `{"cmd":"exit"}` or EOF. Drives sessions (`ask`, `session`, `fork`, `clear`, `model`, `exit`; any `/`-command name works). Protocol in `src/pi_rpc.ijs` |
| Serve | `jpi serve` | The same JSONL protocol over a localhost TCP socket (port 8765, `JPI_SERVE_PORT` to change). The service owns the session: clients **attach**, send commands, and **detach** without killing anything — the next client reconnects to the live session. One client at a time (phase 1). Adds `sessions` (list saved sessions) and `attach <name>` (switch session + replay its messages as `history` events) on top of the rpc command set; `{"cmd":"exit"}` closes only that client. Protocol in `src/pi_serve.ijs` |

Example — a one-shot exchange, exit at EOF:

```bash
printf '%s\n' '{"cmd":"ask","prompt":"what is +/ i. 5"}' | ./jpi rpc
```

### Prerequisites checklist

- [J 9.x](https://www.jsoftware.com/download.htm) on PATH or at a
  common install location (`/Applications/j9.8/` on macOS, `~/j9.8/`,
  `/usr/local/bin/` on Linux). `ijconsole` is tried before `jconsole`,
  so a renamed J install is not confused with Java's `jconsole`. If
  jpi cannot find it, set `JBIN` — copy `local/env.example` to
  `local/env.sh` (untracked) and export `JBIN=/path/to/jconsole` there.
  Startup then ensures `local/jconsole` and `local/ijconsole` are
  symlinks to that binary. Tool shells search `local/` first.
- `bash` and `curl` (all request traffic goes through curl).
- `perl` — the launcher uses one `perl -e 'alarm ...'` call to
  time-box its is-this-J's-jconsole validation. Present by default on
  macOS and most Linux; missing on minimal containers.
- Terminal-size helper (optional but recommended for the TUI):
  `src/vendor/winsize.c` must be compiled for your platform — the repo
  ships source only:

  ```bash
  cd src/vendor
  cc -shared -fPIC -o winsize.so winsize.c      # Linux
  cc -dynamiclib -o winsize.so winsize.c        # macOS
  ```

  Without it the TUI still runs; window-size detection falls back and
  resize handling just won't be exact.

Put your provider API keys in `~/.jpi_providers`, one per line, as
`NAME=VALUE`:

```bash
cat >> ~/.jpi_providers <<'EOF'
OPENROUTER_API_KEY=sk-or-...
ANTHROPIC_API_KEY=sk-ant-...
EOF
chmod 600 ~/.jpi_providers
```

Optional: the j tool's error hints and escalation ladder reference a
J grammar manual (J-CORE). Export `JPI_JCORE=/path/to/J-CORE.md` in
`local/env.sh` to enable it; unset, those features degrade cleanly.

### Directory trust

Plugin packages and `.ijs` extensions are executable code: plugin
`mcp.json` entries spawn server processes, and extension files run at
startup. jpi loads its own shipped plugins plus `~/.jpi/plugins`
(yours), and — only in directories you have trusted — any
`plugins/` directory in the project you launched from. The first
time jpi meets a project that carries its own `plugins/`, it asks
once at the terminal:

```
jpi: first time in /path/to/project: load its local jpi plugins? [y/N]
```

`y` is remembered in `~/.jpi/trusted`; any other answer skips them
(that project) for that launch. Headless runs (`-p`, `rpc`) never
prompt: project-local plugins are skipped unless the directory is
already trusted.

Keys are read from this file only — never from environment variables — so
the bash tool's child processes cannot exfiltrate them. Keys are passed to
curl via `-K` (header config file), so they do not appear in `ps aux`. The
model is stored in `~/.jpi_model` (set it inside jpi with `/model`).

Thinking configuration for reasoning models (on/off, optional token budget)
is stored in `~/.jpi_think` and managed with `/think`. Providers whose API
has no thinking parameter ignore it; Cohere maps it to
`thinking {type, token_budget}` on the v2 chat endpoint.

## Providers

Nine providers are supported, inferred from the model string prefix:

| Prefix / pattern | Provider | Endpoint |
|------------------|----------|----------|
| *(default)* | openrouter | openrouter.ai |
| `claude-*` | anthropic | api.anthropic.com |
| `command-*`, `north-*` | cohere | api.cohere.com |
| `gemini*` | google | googleapis.com |
| `hyai/*` | hyai | hostyourai.com |
| `tcm/*` | tcm | tcmcguire.servehttp.com |
| `mistral/*` | mistral | api.mistral.ai |
| `local/*` | local | localhost:8080 |
| `ollama/*` | ollama | localhost:11434 |

Routing prefixes (`hyai/`, `tcm/`, `local/`, `ollama/`) are stripped before
the API call. Anthropic uses `input_schema` in tool definitions; all other
providers use the OpenAI `{"type":"function","function":...}` form.

## Features

- **Pure escape-code TUI** — no ncurses dependency, runs in any modern terminal
- **Mid-run steering** — type while the agent is working: your message
  composes in the input box exactly like a normal prompt, and Enter steers
  it into the run in progress (injected at the next turn boundary, so the
  model sees it alongside the tool results). An uncommitted draft simply
  stays in the input box; anything queued when a reply completes carries
  into your next prompt, so nothing typed is dropped.
- **Markdown rendering** — LLM responses are parsed and rendered with ANSI
  styles (bold, italic, code blocks with box drawing, colored headers, bullets)
- **Spinner** — a rotating spinner displays during LLM inference so you know
  the agent is working
- **Scrollable output** — Ctrl-U / Ctrl-D / PageUp / PageDown; output is
  stored unwrapped and re-wrapped at render time (UTF-8 and ANSI colors are
  never split), so a resize reflows the screen; the in-TUI buffer is capped
  at 2000 lines — use `/less` for older history
- **Input history** — arrow keys cycle through previous inputs, persisted
  across sessions in `~/.jpi_history`
- **Dynamic input area** — grows to accommodate long/multi-line input
- **Mouse wheel scrolling** — toggle with Ctrl-W
- **Tool execution** — read files, run shell commands, edit code, write files,
  evaluate J code live
- **MCP server integration** — connect to Model Context Protocol servers
  (stdio or HTTP transport); their tools are discovered and dispatched
  alongside built-in tools
- **Agent Skills** — SKILL.md files (agent-plugins.org standard) discovered
  from `./skills/`, `~/.jpi/skills/`, and plugin roots; descriptions injected
  into the system prompt
- **Plugin system** — extensible via `plugins/` directory
- **Pager / editor** — `/less` opens the last response in `$PAGER` for
  scroll/search/copy; `/nvim` composes a prompt in nvim

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Enter | Submit input |
| Up / Down | Cycle input history |
| Left / Right | Move cursor |
| Ctrl-U / PageUp | Scroll output up |
| Ctrl-D / PageDown | Scroll output down |
| Ctrl-W | Toggle mouse wheel scrolling vs. text selection |
| Ctrl-C | Exit |
| Home / End | Jump to start/end of input |
| Delete | Delete character at cursor |

## Mouse Operations

J-PI starts with **mouse wheel scrolling enabled**, so you can scroll the
output pane with your trackpad or scroll wheel right away. Because the
TUI is capturing those mouse events to scroll, your terminal emulator
does **not** receive them — which means click + drag will *not* select
text in the output pane while wheel scrolling is on.

### Switching between scroll mode and selection mode

Use **`Ctrl-W`** to toggle the two modes:

- **Wheel scrolling ON (default).** The status footer shows `[wheel]`.
  Mouse wheel / trackpad scroll moves the output pane up and down.
  Click-drag selection is captured by J-PI and ignored.
- **Wheel scrolling OFF.** Press `Ctrl-W` once to disable mouse capture.
  The `[wheel]` indicator disappears from the footer. Mouse wheel events
  go back to the terminal emulator (which means the terminal will scroll
  *its* scrollback rather than the J-PI output pane), and **click + drag
  selects text** the way it does in any normal shell. Use Cmd-C (macOS)
  or Ctrl-Shift-C (most Linux terminals) to copy.

When you are done copying, press `Ctrl-W` again to restore wheel
scrolling. The keyboard scroll bindings (`Ctrl-U`, `Ctrl-D`, `PageUp`,
`PageDown`) work the same in both modes, so you never lose the ability
to navigate the output pane.

### Terminal emulator escape hatch

Most terminal emulators also offer a modifier key that temporarily
bypasses mouse capture without changing the application's state:

- **macOS Terminal / iTerm2** — hold **Option (⌥)** while click-dragging
  to select text even when wheel scrolling is on.
- **GNOME Terminal / Konsole / xterm** — hold **Shift** while
  click-dragging.
- **Windows Terminal / WSL** — hold **Shift** while click-dragging.

This is handy for one-off copies when you don't want to toggle modes.

## Commands

| Command | Action |
|---------|--------|
| (plain text) | Ask the LLM |
| `!command` | Run a shell command |
| `/less [N]` | Open the last LLM response (or message N) in `$PAGER` |
| `/nvim` | Compose a prompt in nvim |
| `/retry` | Recall the last prompt into the input box for editing (Enter resubmits it) |
| `/model` | Set or change the LLM model |
| `/think` | View or set thinking config: `on`, `off`, `unlimited`, or a token budget |
| `/help [word]` | List all commands grouped; a word filters to matching entries |
| `/read` | Read a file into context |
| `/run` | Run a shell command |
| `/edit` | Edit a file (find/replace) |
| `/write` | Write a file |
| `/ask` | Ask a one-off question |
| `/clear` | Clear conversation history |
| `/session [name]` | Switch to a session (no name: pick from a list); sessions auto-load on start, autosave on switch |
| `/fork [name]` | Copy the current session under a new name and switch to it — the conversation branches here; no name gets `<current>-fork-<timestamp>` |
| `/compact [N]` | Compact the oldest N messages into an LLM summary (default: half) |
| `/context [N\|auto]` | View or set the context budget — the money knob. A lower limit fires compaction earlier and keeps requests small; `/model` reports the model's advertised window so you can see what you're trading. `auto` resets to the provider default |
| `exit` | Quit J-PI |

## Project Structure

```
jpi                     # launcher script (sets JBIN, exports it for the agent)
src/
  tui.ijs               # TUI — pure escape-code terminal interface
  tui_run.ijs           # boot script (default entry point)
  md.ijs                # Markdown → ANSI renderer
  vendor/vt.ijs         # vendored & patched j-kvm/vt.ijs (macOS fixes)
  agent.ijs             # agent dispatcher (tool loop)
  llm.ijs               # LLM API client + tool schema/payload builders
  config.ijs            # provider config, key/model management
  theme.ijs             # color theme
  tool_exec.ijs         # tool execution + dispatch (built-in, ext, MCP)
  read_file.ijs         # file reading tool
  write_file.ijs        # file writing tool
  edit_file.ijs         # code editing tool
  run_cmd.ijs           # shell command tool
  extensions.ijs        # plugin loader + extension tool dispatch
  mcp.ijs               # MCP client (stdio + HTTP transports)
  skills.ijs            # Agent Skills discovery + frontmatter parsing
  plugins.ijs           # MCP server plugin registration
  http.ijs              # HTTP client via curl (sync + async)
  enc_json_fixed.ijs    # JSON encoder (handles rank>2 boxed arrays)
  context.ijs           # conversation trimming + compaction
  usage.ijs             # token and cost tracking
  system_prompt.ijs     # dynamic system prompt builder
  git.ijs               # git context helper
  session.ijs           # session save/load (JSONL)
  confirm.ijs           # edit/write confirmation prompts
  safety.ijs            # bash command blocklist
  log.ijs               # logging
  image.ijs             # image handling
plugins/                # extension plugins (.ijs) + MCP server configs
skills/                 # project-local Agent Skills (SKILL.md)
attic/                  # archived ncurses TUI (see attic/README.md)
tests/                  # regression tests (load via jconsole)
docs/                   # design specs, plans, handoff notes
```

## Contributors

- **Tom McGuire** ([@tmcguirefl](https://github.com/tmcguirefl)) — project creator
- **Pi Coding Agent** ([pi](https://github.com/earendil-works/pi)) — AI pair-programming partner; co-developed the TUI, markdown renderer, escape-code architecture, and project structure

## Acknowledgments & Credits

### Pi Coding Agent — Inspiration & Architecture

J-PI is inspired by and modeled after the
[**Pi Coding Agent**](https://github.com/earendil-works/pi) by
[Earendil Works](https://github.com/earendil-works), an agentic coding
assistant harness that provides tool-use capabilities (file read/write,
shell execution, code editing) through a terminal UI.

The overall architecture of J-PI — the agent loop, tool dispatch,
LLM integration, TUI layout with scrollable output and status footer,
input history, and plugin system — follows the patterns established
by Pi. J-PI reimplements these concepts from scratch in the J programming
language, leveraging J's array-oriented primitives and concise notation.

### j-kvm / vt.ijs — Terminal I/O Library

The TUI is built on top of
[**j-kvm**](https://github.com/tangentstorm/j-kvm) by
[tangentstorm](https://github.com/tangentstorm), a keyboard/video/mouse
driver for terminal applications in J.

Specifically, `vt.ijs` provides the low-level terminal primitives used
throughout the TUI:

- **Raw mode** (`raw`) — switches the terminal between raw and cooked mode
  via `stty`
- **Keyboard input** (`rkey`, `keyp`) — blocking key reads and key-available
  polling via libc `read(2)` and `poll(2)`
- **Cursor control** (`goxy`, `curs`, `curxy`) — ANSI cursor positioning
  and show/hide
- **Screen control** (`cscr`, `ceol`, `puts`) — clear screen, clear to
  end-of-line, raw string output via libc `write(2)`
- **Color** (`fgc`, `bgc`, `fg`, `bg`, `reset`) — 256-color and 24-bit
  ANSI color codes
- **Terminal size** (`gethw`) — query terminal dimensions via `stty size`

#### macOS Modifications

The upstream `vt.ijs` targets Linux primarily. The following changes were
made for macOS (Darwin) compatibility:

- **`UNAME` detection** — added a `Darwin` branch alongside `Linux` and
  `FreeBSD` in the `init` verb, setting the correct `fcntl` constants
  (`F_SETFL=4`, `O_NONBLOCK=4`, `POLLIN=1`) for macOS
- **`poll` struct layout** — verified the `struct pollfd` layout matches
  macOS's little-endian ABI (same as Linux on ARM64)
- **`stty` flags** — macOS `stty` uses the same `raw -echo` / `-raw echo`
  flags as Linux, so no changes were needed there

These changes are minimal and the library works reliably on both
macOS (Apple Silicon) and Linux.

### TermMark — Markdown Renderer Reference

The markdown-to-ANSI renderer (`src/md.ijs`) was ported from
[**TermMark**](https://github.com/ishanawal/TermMark) by
[Ishan Awal](https://github.com/ishanawal), a C++ terminal markdown
renderer.

TermMark's clean two-phase architecture was adapted to J:

1. **Block parser** (`parse_md`) — splits markdown into typed tokens
   (headings, bullets, ordered lists, code blocks, blockquotes,
   horizontal rules, paragraphs) by examining each line's prefix
2. **Inline parser** (`parse_inline`) — walks each line character by
   character, matching delimiter pairs (`**bold**`, `` `code` ``,
   `*italic*`, `_italic_`, `***bold italic***`) without ever touching
   non-markup characters (preserving content like `NB.` in J code)
3. **Renderer** (`render_md`) — walks the token stream and emits ANSI
   escape sequences with proper resets

Key adaptations for the J port:

- **No regex** — J's `rplc` (string replace) is too aggressive for
  markdown (it mangles content). The character-by-character inline
  parser from TermMark solved this cleanly
- **UTF-8 box drawing** — code blocks use `┌`, `│`, `└`, `─` via a
  custom `utf8` encoder and `repstr` (multi-byte-safe string repeat)
- **Bullet characters** — Unicode bullet `•` (U+2022) rendered via
  the same UTF-8 encoder
- **Safe line splitting** — `<;._2` (J's cut primitive) requires
  careful handling to avoid dropping trailing characters

## License

MIT License — see [LICENSE](LICENSE) for details.

Dependency licenses:

- [Pi Coding Agent](https://github.com/earendil-works/pi) — MIT
- [j-kvm](https://github.com/tangentstorm/j-kvm) — MIT
- [TermMark](https://github.com/ishanawal/TermMark) — MIT
- [J Software](https://www.jsoftware.com) — GPL3 (the interpreter; not bundled)
