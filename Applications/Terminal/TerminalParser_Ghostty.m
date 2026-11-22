/* GPL-2.0-or-later, like Terminal.app. */
#import <AppKit/AppKit.h>
#import "TerminalParser_Ghostty.h"
#include <limits.h>
#include <errno.h>

static void writePty(GhosttyTerminal terminal, void *userdata,
                     const uint8_t *bytes, size_t length)
{
  [(id<TerminalScreen>)userdata ts_sendCString:(const char *)bytes length:(int)length];
}

static void titleChanged(GhosttyTerminal terminal, void *userdata)
{
  GhosttyString title;
  if (ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_TITLE, &title) == GHOSTTY_SUCCESS) {
    NSString *text = [[NSString alloc] initWithBytes:title.ptr length:title.len
                                          encoding:NSUTF8StringEncoding];
    if (text) [(id<TerminalScreen>)userdata ts_setTitle:text type:0];
    [text release];
  }
}

static void bell(GhosttyTerminal terminal, void *userdata) { NSBeep(); }

// Preserve the effective Ghostty palette instead of quantizing to legacy slots.
static uint32_t fullColor(GhosttyStyleColor color, const GhosttyColorRgb *palette,
                          uint32_t defaultColor)
{
  if (color.tag == GHOSTTY_STYLE_COLOR_NONE) return defaultColor;
  GhosttyColorRgb rgb = color.tag == GHOSTTY_STYLE_COLOR_RGB
      ? color.value.rgb : palette[color.value.palette];
  return TerminalRGB(rgb.r, rgb.g, rgb.b);
}

@implementation TerminalParser_Ghostty

- initWithTerminalScreen:(id<TerminalScreen>)screen width:(int)w height:(int)h
{
  if (!(self = [super initWithTerminalScreen:screen width:w height:h])) return nil;
  GhosttyTerminalOptions options = {.cols = w, .rows = h, .max_scrollback = 10000};
  if (ghostty_terminal_new(NULL, &terminal, options) != GHOSTTY_SUCCESS ||
      ghostty_key_encoder_new(NULL, &keyEncoder) != GHOSTTY_SUCCESS) {
    [self release];
    return nil;
  }
  // Modern terminal widths: keep ZWJ emoji, modifiers and flags in one cluster.
  ghostty_terminal_mode_set(terminal, GHOSTTY_MODE_GRAPHEME_CLUSTER, true);
  ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_USERDATA, ts);
  ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_WRITE_PTY, writePty);
  ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_TITLE_CHANGED, titleChanged);
  ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_BELL, bell);
  return self;
}

- (void)dealloc
{
  if (outputToUTF8 && outputToUTF8 != (iconv_t)-1) iconv_close(outputToUTF8);
  [outputPending release];
  ghostty_key_encoder_free(keyEncoder);
  ghostty_terminal_free(terminal);
  [super dealloc];
}

- (screen_char_t)cellAtX:(int)column row:(uint32_t)row space:(GhosttyPointTag)space
{
  screen_char_t result = {.ch = ' ', .color = 0xff, .attr = 1};
  GhosttyGridRef ref = GHOSTTY_INIT_SIZED(GhosttyGridRef);
  GhosttyPoint point = {.tag = space, .value.coordinate = {.x = column, .y = row}};
  GhosttyCell cell;
  if (ghostty_terminal_grid_ref(terminal, point, &ref) != GHOSTTY_SUCCESS ||
      ghostty_grid_ref_cell(&ref, &cell) != GHOSTTY_SUCCESS) return result;
  uint32_t codepoint = 0;
  GhosttyCellWide wide;
  ghostty_cell_get(cell, GHOSTTY_CELL_DATA_CODEPOINT, &codepoint);
  ghostty_cell_get(cell, GHOSTTY_CELL_DATA_WIDE, &wide);
  if (wide == GHOSTTY_CELL_WIDE_SPACER_TAIL) result.ch = MULTI_CELL_GLYPH;
  else if (codepoint) result.ch = codepoint;
  GhosttyCellContentTag content;
  ghostty_cell_get(cell, GHOSTTY_CELL_DATA_CONTENT_TAG, &content);
  if (content == GHOSTTY_CELL_CONTENT_CODEPOINT_GRAPHEME &&
      [(id)ts respondsToSelector:@selector(ts_internGrapheme:)]) {
    uint32_t local[16]; size_t needed = 0;
    GhosttyResult status = ghostty_grid_ref_graphemes(&ref, local, 16, &needed);
    NSMutableData *storage = nil;
    const uint32_t *scalars = local;
    if (status == GHOSTTY_OUT_OF_SPACE) {
      storage = [NSMutableData dataWithLength:needed * sizeof(uint32_t)];
      status = ghostty_grid_ref_graphemes(&ref, [storage mutableBytes], needed, &needed);
      scalars = [storage bytes];
    }
    if (status == GHOSTTY_SUCCESS && needed > 1) {
      NSMutableString *text = [NSMutableString string];
      for (size_t i = 0; i < needed; i++) [text appendString:TerminalStringForScalar(scalars[i])];
      result.grapheme = [ts ts_internGrapheme:text];
    }
  }
  GhosttyStyle style = GHOSTTY_INIT_SIZED(GhosttyStyle);
  ghostty_grid_ref_style(&ref, &style);
  result.foregroundColor = fullColor(style.fg_color, colorPalette, defaultForeground);
  result.backgroundColor = fullColor(style.bg_color, colorPalette, defaultBackground);
  result.attr = (style.bold ? 2 : style.faint ? 0 : 1) |
      (style.underline ? 4 : 0) | (style.inverse ? 8 : 0) | (style.blink ? 16 : 0);
  if (style.invisible) result.attr |= 0x20;
  return result;
}

- (void)refreshColors
{
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_COLOR_PALETTE, colorPalette);
  GhosttyColorRgb fg, bg;
  // No configured default yields GHOSTTY_NO_VALUE, not an RGB output.
  defaultForeground = ghostty_terminal_get(terminal,
      GHOSTTY_TERMINAL_DATA_COLOR_FOREGROUND, &fg) == GHOSTTY_SUCCESS
      ? TerminalRGB(fg.r, fg.g, fg.b) : TERMINAL_COLOR_DEFAULT;
  defaultBackground = ghostty_terminal_get(terminal,
      GHOSTTY_TERMINAL_DATA_COLOR_BACKGROUND, &bg) == GHOSTTY_SUCCESS
      ? TerminalRGB(bg.r, bg.g, bg.b) : TERMINAL_COLOR_DEFAULT;
}

- (void)refreshScreen
{
  [self refreshColors];
  for (int row = 0; row < height; row++) {
    for (int column = 0; column < width; column++) {
      screen_char_t cell = [self cellAtX:column row:row space:GHOSTTY_POINT_TAG_ACTIVE];
      screen_char_t old = [ts ts_getCharAtX:column Y:row];
      if (!TerminalCellAppearanceEqual(old, cell))
        [ts ts_putChar:cell count:1 atX:column Y:row];
    }
  }
  uint16_t cx = 0, cy = 0;
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_X, &cx);
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_Y, &cy);
  [ts ts_gotoX:cx Y:cy];
  if ([(id)ts respondsToSelector:@selector(ts_setCursorVisible:)]) {
    bool visible = true;
    ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_VISIBLE, &visible);
    [ts ts_setCursorVisible:visible];
  }
}

- (void)processUTF8Data:(const unsigned char *)bytes length:(NSUInteger)length
{
  GhosttyTerminalScreen before, after;
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_ACTIVE_SCREEN, &before);
  GhosttyTrackedGridRef topRef = NULL;
  GhosttyPoint point = {.tag = GHOSTTY_POINT_TAG_ACTIVE, .value.coordinate = {0, 0}};
  ghostty_terminal_grid_ref_track(terminal, point, &topRef);
  ghostty_terminal_vt_write(terminal, bytes, length);
  [self refreshColors];
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_ACTIVE_SCREEN, &after);
  // Save rows that crossed into history, including output that scrolled more
  // than one screen in this PTY read. A tracked top row survives history pruning.
  if (before == GHOSTTY_TERMINAL_SCREEN_PRIMARY && after == before) {
    size_t history = 0;
    GhosttyPointCoordinate previous;
    ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_SCROLLBACK_ROWS, &history);
    if (topRef && ghostty_tracked_grid_ref_point(topRef, GHOSTTY_POINT_TAG_SCREEN, &previous) == GHOSTTY_SUCCESS) {
      for (size_t row = previous.y; row < history; row++) {
        for (int column = 0; column < width; column++)
          [ts ts_putChar:[self cellAtX:column row:row space:GHOSTTY_POINT_TAG_HISTORY]
                   count:1 atX:column Y:0];
        [ts ts_scrollUpTop:0 bottom:height rows:1 save:YES];
      }
    }
  }
  ghostty_tracked_grid_ref_free(topRef);
  [self refreshScreen];
}

- (void)setCharset:(NSString *)charsetName
{
  // The legacy setter does not close handles when replacing one non-Latin-1 codec with another.
  if (iconv_state) { iconv_close(iconv_state); iconv_state = NULL; }
  if (iconv_input_state) { iconv_close(iconv_input_state); iconv_input_state = NULL; }
  [super setCharset:charsetName];
  if (outputToUTF8 && outputToUTF8 != (iconv_t)-1) iconv_close(outputToUTF8);
  outputToUTF8 = NULL;
  [outputPending release];
  outputPending = nil;
  if ([charsetName caseInsensitiveCompare:@"UTF-8"] != NSOrderedSame &&
      [charsetName caseInsensitiveCompare:@"UTF8"] != NSOrderedSame) {
    outputToUTF8 = iconv_open("UTF-8", [charsetName UTF8String]);
    if (outputToUTF8 == (iconv_t)-1) outputToUTF8 = iconv_open("UTF-8", "ISO-8859-1");
    outputPending = [NSMutableData new];
  }
}

- (void)processData:(const unsigned char *)bytes length:(NSUInteger)length
{
  if (!outputToUTF8 || outputToUTF8 == (iconv_t)-1) {
    [self processUTF8Data:bytes length:length];
    return;
  }
  [outputPending appendBytes:bytes length:length];
  char *input = [outputPending mutableBytes];
  size_t remaining = [outputPending length];
  while (remaining) {
    char buffer[4096], *output = buffer;
    size_t available = sizeof(buffer);
    size_t result = iconv(outputToUTF8, &input, &remaining, &output, &available);
    int error = errno;
    [self processUTF8Data:(const unsigned char *)buffer length:sizeof(buffer) - available];
    if (result != (size_t)-1) break;
    if (error == EINVAL) break; // keep an incomplete encoded character for the next read
    if (error == EILSEQ) {
      static const unsigned char replacement[] = {0xef, 0xbf, 0xbd};
      [self processUTF8Data:replacement length:sizeof(replacement)];
      input++; remaining--;
    } else if (error != E2BIG) break;
  }
  NSUInteger consumed = [outputPending length] - remaining;
  [outputPending replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
}

- (void)processByte:(unsigned char)byte { [self processData:&byte length:1]; }

- (void)setTerminalScreenWidth:(int)w height:(int)h cursorY:(int)cursorY
{
  if (ghostty_terminal_resize(terminal, w, h, 0, 0) != GHOSTTY_SUCCESS) return;
  width = w; height = h;
  [self refreshScreen];
}

- (void)sendString:(NSString *)text
{
  text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\r"];
  if (!iconv_input_state) {
    NSData *bytes = [text dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    if (!bytes) { NSBeep(); return; }
    [ts ts_sendCString:[bytes bytes] length:(int)[bytes length]];
    return;
  }
  // iconv's UCS-4 input is big-endian, as in the legacy htonl path, but
  // NSString conversion combines surrogate pairs instead of sending halves.
  NSData *data = [text dataUsingEncoding:NSUTF32BigEndianStringEncoding];
  char *input = (char *)[data bytes]; size_t remaining = [data length];
  while (remaining) {
    char buffer[4096], *output = buffer; size_t available = sizeof(buffer);
    size_t status = iconv(iconv_input_state, &input, &remaining, &output, &available);
    int error = errno;
    [ts ts_sendCString:buffer length:(int)(sizeof(buffer) - available)];
    if (status == (size_t)-1 && error != E2BIG) { NSBeep(); break; }
  }
}

- (void)handleKeyEvent:(NSEvent *)event
{
  NSString *characters = [event charactersIgnoringModifiers];
  if (![characters length]) return;
  unichar ch = [characters characterAtIndex:0];
  GhosttyKey key = GHOSTTY_KEY_UNIDENTIFIED;
  switch (ch) {
    case NSUpArrowFunctionKey: key = GHOSTTY_KEY_ARROW_UP; break;
    case NSDownArrowFunctionKey: key = GHOSTTY_KEY_ARROW_DOWN; break;
    case NSLeftArrowFunctionKey: key = GHOSTTY_KEY_ARROW_LEFT; break;
    case NSRightArrowFunctionKey: key = GHOSTTY_KEY_ARROW_RIGHT; break;
    case NSHomeFunctionKey: key = GHOSTTY_KEY_HOME; break;
    case NSEndFunctionKey: key = GHOSTTY_KEY_END; break;
    case NSInsertFunctionKey: key = GHOSTTY_KEY_INSERT; break;
    case NSDeleteFunctionKey: key = GHOSTTY_KEY_DELETE; break;
    case NSPageUpFunctionKey: key = GHOSTTY_KEY_PAGE_UP; break;
    case NSPageDownFunctionKey: key = GHOSTTY_KEY_PAGE_DOWN; break;
    default: if (ch >= NSF1FunctionKey && ch <= NSF12FunctionKey)
      key = GHOSTTY_KEY_F1 + (ch - NSF1FunctionKey);
  }
  if (key == GHOSTTY_KEY_UNIDENTIFIED) { [super handleKeyEvent:event]; return; }
  GhosttyKeyEvent input = NULL;
  if (ghostty_key_event_new(NULL, &input) != GHOSTTY_SUCCESS) return;
  GhosttyMods mods = 0;
  NSUInteger flags = [event modifierFlags];
  if (flags & NSShiftKeyMask) mods |= GHOSTTY_MODS_SHIFT;
  if (flags & NSControlKeyMask) mods |= GHOSTTY_MODS_CTRL;
  if ((flags & NSAlternateKeyMask) && alternateAsMeta) mods |= GHOSTTY_MODS_ALT;
  ghostty_key_event_set_action(input, GHOSTTY_KEY_ACTION_PRESS);
  ghostty_key_event_set_key(input, key);
  ghostty_key_event_set_mods(input, mods);
  ghostty_key_encoder_setopt_from_terminal(keyEncoder, terminal);
  char buffer[128]; size_t length = 0;
  if (ghostty_key_encoder_encode(keyEncoder, input, buffer, sizeof(buffer), &length) == GHOSTTY_SUCCESS)
    [ts ts_sendCString:buffer length:(int)length];
  ghostty_key_event_free(input);
}
@end
