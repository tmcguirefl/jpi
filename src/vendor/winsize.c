/* winsize.c - TIOCGWINSZ helper for J-PI's vt.ijs gethw.
 *
 * Why this exists: J's cd FFI cannot reliably return the kernel's
 * write into an out-buffer for variadic ioctl(2) on this platform
 * (the *i/*s/c buffers round-trip unchanged - verified empirically).
 * Compiling this tiny .so at first use gives jpi a subprocess-free,
 * microsecond-cost gethw, which lets the TUI re-read the terminal
 * size on every keystroke (self-healing after resize races).
 *
 * jgetwinsize(fd) returns:
 *   rc | (row << 16) | col    when ioctl succeeds  (rc = 0, so the
 *                          packed value is a positive number)
 *   _1                      on failure (non-tty fd, etc.)
 * The row/col fields are each 16-bit inside a long, so packing is
 * lossless for all real terminal sizes.
 *
 * Build: gcc -shared -fPIC -o winsize.so winsize.c
 */
#include <sys/ioctl.h>

long jgetwinsize(int fd) {
    struct winsize w;
    if (ioctl(fd, TIOCGWINSZ, &w) != 0)
        return -1;
    if (w.ws_row == 0 || w.ws_col == 0)
        return -1;              /* some ptys report 0x0 before attach */
    return ((long)w.ws_col << 16) | w.ws_row;
}
