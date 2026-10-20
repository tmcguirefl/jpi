Updated: 2026-10-19

J-PI is on `origin/main` at `a19fae3` plus local edits. SSE null content is ignored and tool-call fragments are reassembled. Not committed.

## Done

- Reviewed the harness (safety, tool loop, TUI, providers).
- Fast-forwarded `main` from `7c78317` to `a19fae3`. Discarded executable-bit-only dirt.
- Kept local work: bracketed paste and vt spinner in `src/tui.ijs`, `</dev/null` in `src/http.ijs` and `src/run_cmd.ijs`, `MAX_TOOL_LOOPS =: 15` and TUI redraws in `src/llm.ijs`.
- Ignored `.jpi_providers`. Wrote development notes in `AGENTS.md`.
- Confirmed `jconsole` J9.8 and `load 'api/curl'`.
- Fixed the NVIDIA/OpenRouter `jsonnull` flood. `src/http_stream.ijs` drops JSON null content and rebuilds `tool_calls`. `src/llm.ijs` treats null content as empty. `tests/test_stream_null.ijs` passes.

## Next / blocked

- Retry the moving-average prompt from `../jpitest`. The system prompt is rebuilt on each request, so the model sees that directory. `src/mva.ijs` is the earlier write into the wrong directory.
- Then the review list: in-process `j` tool, timeout string injected into `perl -e`, unquoted `mkdir` / image / `git` / `grep` / `find`, Esc does not cancel `curl_easy_perform`.
- Not blocked. No Claude Code session exists for this directory.

## Key paths

- `jpi`, `src/tui_run.ijs`, `src/tui.ijs`, `src/llm.ijs`, `src/http_stream.ijs`, `src/tool_exec.ijs`
- Uncommitted: `.gitignore`, `AGENTS.md`, `STATUS.md`, `src/http.ijs`, `src/http_stream.ijs`, `src/llm.ijs`, `src/run_cmd.ijs`, `src/tui.ijs`, `tests/test_stream_null.ijs`
- Keys stay in the environment or `~/.jpi_providers`. Do not print them.
