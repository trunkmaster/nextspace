# Terminal VT engine on FreeBSD

Terminal uses libghostty-vt for the terminal state machine while retaining
its GNUstep/back-art view, PTY handling, selection, scrollbar and font preferences.
The Linux parser remains available for comparison and builds without Ghostty.

## Build

The FreeBSD Packaging application stage builds the dependency before Terminal.
`freebsd/build.sh SOURCE_DIRECTORY PREFIX` can also build it independently.
It pins Ghostty to `74d0c72fd9318ad3ab95bfb56f6c2d995e267e2e`, the last
revision before the Zig 0.16 transition, and requires Zig **0.15.2** (`zig015`).
The helper verifies the revision and compiler instead of following `main`.
It produces the C headers, static archive and shared library under PREFIX.
The only Zig build artifact enabled is libghostty-vt; SIMD is disabled for
this portable FreeBSD build.

The terminal-state C API is not in the v1.3.1 application release. Current
Ghostty main uses a newer compiler and has a different API. Updating this pin
requires checking both the C API and the adapter tests.

For an explicit legacy build, use `gmake USE_GHOSTTY_VT=no` after cleaning.
For runtime comparison with a Ghostty-enabled build, set the Terminal defaults
domain's `TerminalParserBackend` to `linux` and restart Terminal. Removing that
key restores the default Ghostty backend. A runtime comparison still requires
the linked Ghostty shared library; the compile-time option removes that dependency.
An engine allocation failure falls back to the Linux parser.

## Behavior

PTY reads enter the engine in batches. The adapter snapshots cells only after
each batch, forwards changed cells to TerminalView, and preserves scrollback
with a tracked reference to the previous first active row. This works even
after Ghostty's history starts pruning. Alternate-screen content is not saved
as primary scrollback. Cursor position/visibility, title changes, terminal
status replies and application cursor/function keys come from Ghostty.
Existing charset preferences convert output to UTF-8 and retain incomplete
encoded characters across reads; normal typed text and paste use the existing
Terminal input conversion. Ghostty-backed children advertise `TERM=xterm`;
legacy children retain `TERM=linux`.

Terminal now preserves Unicode scalars and complete grapheme clusters, uses
Fontconfig/FreeType/HarfBuzz for missing glyphs, and renders Noto Color Emoji
through back-art bitmap compositing. See `Applications/Terminal/UNICODE.md`
for the three implementation milestones, fonts, tests and remaining limits.
ANSI text colors still use the existing 16-color cell palette, while emoji
bitmaps retain their source RGB colors. This does not add GPU rendering,
images via terminal graphics protocols, clickable links, IME configuration,
or complete Kitty keyboard/mouse integration.

## Tests

With the NextSpace GNUstep environment and library paths configured:

```sh
. /Developer/Makefiles/GNUstep.sh
gmake -C Applications/Terminal/Tests
LD_LIBRARY_PATH=/usr/local/NextSpace/lib:/Library/Libraries \
    Applications/Terminal/Tests/obj/ghostty-adapter-test
```

The native test uses a fake TerminalScreen to verify cells/styles, styled blank
backgrounds, cursor visibility, OSC titles, fragmented UTF-8, wide cells,
alternate-screen restoration, multi-screen scrolling, status replies,
application cursor keys, resize and Latin-1 conversion. It sends 12,050 lines
to verify history retention across the engine's 10,000-line pruning boundary.

Also verified in the physical `nextspace-prefix-verify` jail: shell commands,
`printenv TERM`, directory listings, read-only vi navigation and return to the
shell. Both Ghostty-enabled and legacy builds compiled. This bounded acceptance
does not replace a long soak or test all terminal applications.

API reference: [pinned C headers](https://github.com/ghostty-org/ghostty/tree/74d0c72fd9318ad3ab95bfb56f6c2d995e267e2e/include/ghostty/vt).
