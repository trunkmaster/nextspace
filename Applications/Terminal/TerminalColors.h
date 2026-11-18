/* GPL-2.0-or-later, like Terminal.app. */
#ifndef TerminalColors_h
#define TerminalColors_h
#import "Terminal.h"

typedef struct {
  uint32_t fg, bg, selection, bold, blink;
  uint32_t inverseForeground, inverseBackground;
} TerminalColorDefaults;

typedef struct { uint32_t fg, bg; } TerminalDrawColors;

// Resolve the same colors for bg fills and glyphs. Explicit RGB black
// and white never acquire the special meaning of a legacy palette slot.
static inline TerminalDrawColors TerminalResolveColors(screen_char_t cell,
                                                       TerminalColorDefaults defaults)
{
  TerminalDrawColors result;
  result.fg = cell.foregroundColor == TERMINAL_COLOR_DEFAULT
      ? ((cell.attr & 3) == 2 ? defaults.bold : defaults.fg)
      : cell.foregroundColor;
  result.bg = cell.backgroundColor == TERMINAL_COLOR_DEFAULT
      ? defaults.bg : cell.backgroundColor;
  if ((cell.attr & 3) == 0) {
    uint32_t rgb = result.fg;
    result.fg = TerminalRGB(((rgb >> 16) & 255) / 2,
        ((rgb >> 8) & 255) / 2, (rgb & 255) / 2);
  }
  if ((cell.attr & 0x10) && cell.foregroundColor == TERMINAL_COLOR_DEFAULT)
    result.fg = defaults.blink;
  if (cell.attr & 8) {
    if (cell.foregroundColor == TERMINAL_COLOR_DEFAULT &&
        cell.backgroundColor == TERMINAL_COLOR_DEFAULT) {
      result.fg = defaults.inverseForeground;
      result.bg = defaults.inverseBackground;
    } else {
      uint32_t swap = result.fg;
      result.fg = result.bg;
      result.bg = swap;
    }
  }
  if (cell.attr & 0x40) {
    result.fg = defaults.fg;
    result.bg = defaults.selection;
  }
  return result;
}
#endif
