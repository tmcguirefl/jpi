Updated: 2026-10-19

`main` is Jared Nicholson's contribution, fast-forwarded and pushed. Build on `main` from here.

## Done

- `git am --3way` of `/tmp/jpi-contribution.patch` (4 commits, author Jared Nicholson).
- Conflicts in commit 1 resolved: Jared's `llm.ijs`, `tool_exec.ijs`, and `tui.ijs`; `http_stream.ijs` deleted; `.gitignore` keeps his ignores and `.jpi_providers`; `run_cmd.ijs` uses his `JBIN_PATH` plus `</dev/null`.
- `perl` is `/usr/bin/perl` 5.34.1.
- Built `src/vendor/winsize.so` (gitignored): `cd src/vendor && cc -dynamiclib -o winsize.so winsize.c`. One comment warning. Mach-O arm64.
- J tool `+/ i.10` returned 45.
- `./jpi -p` starts with `/Users/tomdevel/j9.8/bin/jconsole` and returns an empty reply: HTTP 401, missing auth. `~/.jpi_providers` still has a one-character placeholder.

## Next / blocked

- Next change: if `local/jconsole` and `local/ijconsole` are missing, create those symlinks to J's binary and put `local/` first on the tool-shell `PATH`.
- Re-run `./jpi -p` from a shell where `OPENROUTER_API_KEY` is set.
- Untracked local experiments and `src/mva.ijs` were not part of the patch.

## Key paths

- `main` at `6aaa58b`. `jared-contrib` points at the same commit.
- `ARCHITECTURE.md`, `src/pi_print.ijs`, `src/mcp.ijs`, `src/vendor/winsize.c`, `jpi`, `src/run_cmd.ijs`
