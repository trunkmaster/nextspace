# Unicode, CJK and emoji in Terminal

The FreeBSD Ghostty backend supports UTF-8 input/output, full Unicode scalars,
complete grapheme clusters and two-column glyphs. Keith remains the primary
font. Missing glyphs are selected with Fontconfig, shaped with HarfBuzz, and
rasterized with FreeType into images composited by GNUstep/back-art. No Apple
SDK, framework, font or Mac-built binary is used.

## Fonts and dependencies

The FreeBSD application dependency list supplies `fontconfig`, `freetype2`,
`harfbuzz`, `noto-sans-jp`, `noto-sans-kr`, `noto-sans-sc` and `noto-emoji`.
Use the normal Packaging application build to compile/link Terminal. Installing
additional fonts alone does not remove Terminal's need for this Unicode build.

Fallback does not require repackaging system fonts as GNUstep `.nfont` bundles.
Fontconfig locates their installed files directly. Only missing primary glyphs,
supplementary scalars and multi-codepoint clusters use the new raster path;
ordinary primary-font characters retain their existing drawing path.

Color glyphs preserve FreeType BGRA pixels, with premultiplied-alpha filtering
and conversion to AppKit RGBA. Large bitmap strikes fit within the glyph's
allocated cells. Explicit VS15 text presentation remains grayscale. Color
support was tested with the open Noto Color Emoji bitmap font; SVG/COLRv1 color
fonts have not been validated. Font coverage determines which sequences have
a designed glyph.

## Text integrity and widths

Cells store a Unicode scalar and an optional grapheme handle. Text handles
remain valid across POD cell copies, scrollback and resize; periodic collection
removes strings no longer referenced by active/history cells. The glyph image
cache is capped at 256 entries per view. Cells occupy more memory than the
original four-byte representation; history allocation is capped in bytes.

New Ghostty terminals enable DEC mode 2027 (grapheme-cluster widths). Applications
can change terminal modes, and a full engine reset restores its own defaults;
`printf '\033[?2027h'` enables clustering again if needed. Applications that
calculate legacy character widths can disagree with a terminal's clustered
widths; enabling emoji does not make every text UI grapheme-aware.

Selection expands partial wide glyphs to whole cells. Clipboard/search text
uses complete clusters, and search translates UTF-16 string ranges into cell
coordinates rather than assuming one string unit equals one terminal column.
Input conversion combines surrogate pairs before encoding. Split Shift-JIS
input and Japanese output were tested, but emoji requires a charset capable
of representing it, normally UTF-8.

Ghostty history transfer uses a final grid snapshot. Terminal invalidates the
visible grid when that transfer scrolls, rather than compositing intermediate
legacy pixels; this prevents stale text after leaving a full-screen program.
The legacy parser keeps its existing scroll optimization.

## Native acceptance

With the built libraries, open fonts and a running X display:

```sh
. /Developer/Makefiles/GNUstep.sh
gmake -C Applications/Terminal/Tests/Unicode
env DISPLAY=:0 XAUTHORITY=/root/.Xauthority LANG=C.UTF-8 \
    NEXTSPACE_USER_ROOT=/root/Library \
    LD_LIBRARY_PATH=/usr/local/NextSpace/lib:/Library/Libraries \
    Applications/Terminal/Tests/Unicode/obj/unicode-view-test
```

The display and authority values above are the development jail's; substitute
the actual user's session values elsewhere. Passing `preview` shows a temporary
native TerminalView window after the assertions.

The test verifies:

- Chinese/Japanese/Korean rasterization and two-column copying.
- Split UTF-8, supplementary scalars, accents, skin tones, ZWJ sequences,
  flags, variation selectors and a 41-codepoint combining cluster.
- Clipboard text, Unicode key/paste conversion, search-range mapping and
  selecting only the second column of a joined emoji.
- History growth, shrink and resize, snapshot invalidation, and collection
  after 15,000 unique text handles.
- Color pixels at 12/20/32 points, joined versus standalone emoji, VS15 text
  presentation, and a split Shift-JIS round trip for 日.

The existing `Tests/ghostty-adapter-test` separately covers terminal controls,
application keys and history pruning after 12,050 output lines. Both default
and explicit legacy builds compile. Installed Terminal was also checked with
a mixed-script/color fixture, a read-only vi session, and subsequent output;
the stale-pixel failure found in that check was corrected and rechecked.

## Remaining boundaries

This does not install/configure a CJK input method, implement full bidirectional
layout or shape entire runs across terminal cells. ANSI true-color/256-color
text now retains RGB in the Ghostty backend and software renderer; see
[FULL-COLOR.md](FULL-COLOR.md). Emoji images retain RGB.
GPU rendering, sixel/Kitty graphics, interactive hyperlinks and full Kitty
keyboard/mouse integration remain separate work. The older idle black-screen
problem is tracked independently and is not fixed by these changes.
