Updated: 2026-10-20

Local `jconsole` / `ijconsole` links and review items 2–5 are committed on `main`. Item 1 is deferred.

## Done

- Startup creates gitignored `local/jconsole` and `local/ijconsole` and puts that directory first on the tool-shell `PATH`.
- A non-numeric bash timeout is rejected. `mkdir`, `base64`, `sips`, `open`, and `/git` `/grep` `/find` quote their arguments. `/git` uses `is_safe`.
- JSON `null` content is empty text. Esc and the 120s wait kill the background curl and drop that ask's messages.
- A `claude-` model id uses the Anthropic Messages shape. The reply is normalized to `choices` / `tool_calls`.
- Tests: `test_run_cmd.ijs` 28 passed, `test_shell_quote.ijs`, `test_http_cancel.ijs`, `test_stream_null.ijs`.

## Next / blocked

- Item 1 is on hold: the `j` tool stays in-process in `jpiagws` so the session and the escalation ladder keep working. Study that before changing it.
- Still open: blocklist false positives, confirm in the raw TUI, compaction role pairing, `fwrites` adding a linefeed, `run_hooks`, session-name traversal.
- Re-run `./jpi -p` from a shell where `OPENROUTER_API_KEY` is set. Do not commit `src/mva.ijs` or the root experiment scripts.

## Key paths

- `main` tracks `origin/main`. This commit is local until pushed.
- `jpi`, `src/run_cmd.ijs`, `src/llm.ijs`, `src/http.ijs`, `src/tui.ijs`, `src/agent.ijs`.
- Links (gitignored): `local/jconsole`, `local/ijconsole`.
