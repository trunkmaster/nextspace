/* GPL-2.0-or-later. Terminal-local font fallback; no platform frameworks. */
#import <AppKit/AppKit.h>
#include <ft2build.h>
#include FT_FREETYPE_H

@interface TerminalGlyphRenderer : NSObject
{
  FT_Library library;
  NSMutableDictionary *images;
}
- (NSImage *)imageForString:(NSString *)text font:(NSFont *)font
                  cellSize:(NSSize)cellSize baseline:(CGFloat)baseline
                   columns:(NSUInteger)columns color:(NSColor *)color;
@end
