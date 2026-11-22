# Full-color Terminal rendering (FreeBSD, 2026-11-17)

The Ghostty backend preserves explicit foreground/background RGB values and
resolves all 256 palette entries using Ghostty's effective palette. Terminal
default colors have their own tag, so explicit black/white are never mistaken
for a user preference. The legacy packed color byte remains for the Linux
parser; its writes explicitly clear the new fields.

TerminalView draws full-color background runs and text through the existing
software back-art renderer. Selection uses user selection/default text colors;
inverse swaps explicit colors, while default/default inverse retains the
user's inverse preferences. Faint dims the foreground, and bold does not
replace an explicit RGB color. Underlined spaces set their foreground too.
The Unicode glyph-image path receives the same resolved foreground color.

Cell appearance comparisons include both full-color fields and ignore only
selection/dirty bookkeeping bits. Existing cell copies preserve these fields
through scrollback, resize and alternate-screen restoration. Active-grid OSC
palette/default changes are resolved again and invalidate affected cells.
Scrollback stores the RGB snapshot captured when rows entered its buffer.

New Ghostty-backed shells receive TERM=xterm-256color and COLORTERM=truecolor.
Legacy-parser shells retain TERM=linux without a truecolor claim. An already
running process keeps its old renderer: fully quit/reopen Terminal to load
an installed update, rather than opening another window in the old process.

## Verification

From an existing FreeBSD desktop:

```sh
Applications/Terminal/Tests/run-color-tests.sh
```

The script builds the application and fake-screen adapter test, then links a
pixel test against the actual Terminal application objects. The small temporary
test window uses the installed Keith font; it launches no user shell. AppKit
exceptions print to stderr and exit; a kill-after timeout bounds failures.

Adapter checks cover exact RGB values, every palette entry, explicit white and
black, OSC default/palette changes, color-only damage, RGB across scrollback,
alternate screen and resize, and prior Unicode/terminal behavior.

The integration test samples real back-art RGB pixels for background runs,
text, inverse, selection/unselection, all 256 palette fills, and bold/faint
RGB. Readback uses RGB bytes directly because this backend's focused-view
snapshot has valid RGB with zero alpha; colorAtX: would unpremultiply those
pixels incorrectly. The legacy-parser rendering translation unit also passed
a syntax-only build without USE_GHOSTTY_VT.

Installed-binary smoke testing confirmed startup and the new shell environment.
The user's interactive local/remote applications still need personal visual
acceptance. The tests establish RGB preservation/drawing, not exhaustive
compatibility with every terminal application or performance under long runs.
