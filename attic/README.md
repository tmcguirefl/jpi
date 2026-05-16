# Attic

Archived code from earlier development phases.

## ncurses TUI (`tui.ijs`)

The original TUI implementation used ncurses via J's DLL interface.
It was replaced by the pure escape-code TUI (`src/tui.ijs`) which uses
only ANSI/VT escape codes via the `j-kvm/vt.ijs` library.

The escape-code version is simpler, more portable, and doesn't require
ncurses to be installed.

### macOS ncurses notes

If you want to experiment with the ncurses TUI on macOS, you may need
to adjust the dynamic library paths on the `jconsole` binary. The
Homebrew ncurses libraries install to `/opt/homebrew/opt/ncurses/lib/`
which is not on the default search path.

Use `otool` and `install_name_tool` to patch `jconsole`:

```bash
# Check current dylib references
otool -L /Applications/j9.8/bin/jconsole

# Repoint to Homebrew ncurses if needed
install_name_tool -change \
  /usr/lib/libncurses.5.4.dylib \
  /opt/homebrew/opt/ncurses/lib/libncurses.dylib \
  /Applications/j9.8/bin/jconsole
```

You may need to make a copy of the binary first (`jconsole_arm64` etc.)
since modifying the original may require disabling SIP or re-signing.

## vt test files (`test_vt*.ijs`)

Development test scripts used while building the escape-code TUI.
