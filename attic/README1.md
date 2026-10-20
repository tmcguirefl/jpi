# J-PI — A J-Language Agentic Coding Assistant

J-PI is a terminal-based agentic coding assistant written entirely in the
[J programming language](https://www.jsoftware.com). It provides an
interactive TUI (Text User Interface) for conversing with LLMs, executing
tools (file read/write, shell commands, code editing), and working within
a project directory — similar in spirit to the
[pi coding agent](https://github.com/earendil-works/pi-coding-agent).

## Quick Start

```bash
./jpi
```

Requires [J 9.x](https://www.jsoftware.com/download.htm) installed at
`/Applications/j9.8/` (macOS) or adjust the path in `jpi`.

Set one of these environment variables for LLM access:

```bash
export OPENROUTER_API_KEY="sk-or-..."
# or
export ANTHROPIC_API_KEY="sk-ant-..."
```

## Features

- **Pure escape-code TUI** — no ncurses dependency, runs in any modern terminal
- **Markdown rendering** — LLM responses are parsed and rendered with ANSI
  styles (bold, italic, code blocks with box drawing, colored headers, bullets)
- **Scrollable output** — Ctrl-U / Ctrl-D / PageUp / PageDown
- **Input history** — arrow keys cycle through previous inputs, persisted
  across sessions in `~/.jpi_history`
- **Dynamic input area** — grows to accommodate long/multi-line input
- **Mouse wheel scrolling** — toggle with Ctrl-W
- **Tool execution** — read files, run shell commands, edit code, write files
- **Plugin system** — extensible via `plugins/` directory

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Enter | Submit input |
| Up / Down | Cycle input history |
| Left / Right | Move cursor |
| Ctrl-U / PageUp | Scroll output up |
| Ctrl-D / PageDown | Scroll output down |
| Ctrl-W | Toggle mouse wheel scrolling |
| Ctrl-C | Exit |
| Home / End | Jump to start/end of input |
| Delete | Delete character at cursor |

## Commands

| Prefix | Action |
|--------|--------|
| (plain text) | Ask the LLM |
| `!command` | Run a shell command |
| `/command` | Agent command |
| `exit` | Quit J-PI |

## Project Structure

```
jpi                  # launcher script
src/
  tui.ijs            # TUI — pure escape-code terminal interface
  tui_run.ijs        # boot script
  md.ijs             # Markdown → ANSI renderer
  vendor/vt.ijs        # vendored & patched j-kvm/vt.ijs (macOS fixes)
  agent.ijs          # agent dispatcher
  llm.ijs            # LLM API client
  config.ijs         # configuration
  theme.ijs          # color theme
  tool_exec.ijs      # tool execution loop
  read_file.ijs      # file reading tool
  write_file.ijs     # file writing tool
  edit_file.ijs      # code editing tool
  run_cmd.ijs        # shell command tool
  extensions.ijs     # plugin loader
  ...
plugins/             # extension plugins
attic/               # archived ncurses TUI (see attic/README.md)
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
