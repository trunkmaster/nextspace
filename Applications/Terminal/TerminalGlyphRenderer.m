/* GPL-2.0-or-later. */
#import "TerminalGlyphRenderer.h"
#include <fontconfig/fontconfig.h>
#include <math.h>
#include <hb.h>
#include <hb-ft.h>

// FreeType BGRA bitmaps are premultiplied. Filter in that representation
// and unpremultiply once, before compositing into AppKit's straight RGBA.
static void samplePixel(const FT_Bitmap *bitmap, NSInteger x, NSInteger y,
                        const CGFloat tint[3], CGFloat sample[4])
{
  sample[0] = sample[1] = sample[2] = sample[3] = 0;
  if (x < 0 || y < 0 || x >= bitmap->width || y >= bitmap->rows) return;
  const unsigned char *row = bitmap->buffer +
      (bitmap->pitch >= 0 ? y : bitmap->rows - 1 - y) * abs(bitmap->pitch);
  if (bitmap->pixel_mode == FT_PIXEL_MODE_BGRA) {
    sample[0] = row[x*4+2] / 255.0;
    sample[1] = row[x*4+1] / 255.0;
    sample[2] = row[x*4] / 255.0;
    sample[3] = row[x*4+3] / 255.0;
  } else {
    CGFloat alpha = bitmap->pixel_mode == FT_PIXEL_MODE_MONO ?
        ((row[x/8] & (0x80 >> (x%8))) ? 1 : 0) : row[x] / 255.0;
    for (int c=0; c<3; c++) sample[c] = tint[c] * alpha;
    sample[3] = alpha;
  }
}

@implementation TerminalGlyphRenderer
- (id)init
{
  if (!(self = [super init])) return nil;
  if (FT_Init_FreeType(&library)) { [self release]; return nil; }
  images = [NSMutableDictionary new];
  return self;
}
- (void)dealloc
{
  [images release];
  if (library) FT_Done_FreeType(library);
  [super dealloc];
}

- (NSImage *)imageForString:(NSString *)text font:(NSFont *)font
                  cellSize:(NSSize)cellSize baseline:(CGFloat)baseline
                   columns:(NSUInteger)columns color:(NSColor *)color
{
  if (![text length] || !columns || cellSize.width <= 0 || cellSize.height <= 0) return nil;
  color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  NSString *key = [NSString stringWithFormat:@"%@/%@/%g/%g/%g/%g/%lu/%@",
      text, [font fontName], [font pointSize], cellSize.width, cellSize.height,
      baseline, (unsigned long)columns, color];
  NSImage *cached = [images objectForKey:key];
  if (cached) return cached;

  NSData *utf32 = [text dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
  const uint32_t *scalars = [utf32 bytes];
  NSUInteger count = [utf32 length] / sizeof(uint32_t);
  if (!count) return nil;
  FcCharSet *charset = FcCharSetCreate();
  BOOL textPresentation = NO;
  for (NSUInteger i = 0; i < count; i++) {
    if (scalars[i] == 0xfe0e) textPresentation = YES;
    // Select a font for visible characters, not joining/variation controls.
    if (scalars[i] != 0x200d && !(scalars[i] >= 0xfe00 && scalars[i] <= 0xfe0f))
      FcCharSetAddChar(charset, scalars[i]);
  }
  FcPattern *pattern = FcPatternCreate();
  BOOL emoji = NO;
  for (NSUInteger i = 0; i < count; i++)
    if ((scalars[i] >= 0x1f000 && scalars[i] <= 0x1faff) || scalars[i] == 0xfe0f) emoji = YES;
  FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *)(emoji ? "emoji" : [[font familyName] UTF8String]));
  FcPatternAddCharSet(pattern, FC_CHARSET, charset);
  FcPatternAddDouble(pattern, FC_PIXEL_SIZE, [font pointSize]);
  FcPatternAddInteger(pattern, FC_WEIGHT,
      ([[NSFontManager sharedFontManager] traitsOfFont:font] & NSBoldFontMask) ? FC_WEIGHT_BOLD : FC_WEIGHT_REGULAR);
  FcConfigSubstitute(NULL, pattern, FcMatchPattern);
  FcDefaultSubstitute(pattern);
  FcResult result;
  FcPattern *match = FcFontMatch(NULL, pattern, &result);
  FcCharSetDestroy(charset);
  FcPatternDestroy(pattern);
  FcChar8 *file = NULL;
  int faceIndex = 0;
  FT_Face face = NULL;
  if (!match || FcPatternGetString(match, FC_FILE, 0, &file) != FcResultMatch) {
    if (match) FcPatternDestroy(match);
    return nil;
  }
  FcPatternGetInteger(match, FC_INDEX, 0, &faceIndex);
  FT_Error error = FT_New_Face(library, (const char *)file, faceIndex, &face);
  FcPatternDestroy(match);
  if (error) return nil;
  FT_Select_Charmap(face, FT_ENCODING_UNICODE);
  CGFloat requested = MAX(1, [font pointSize]);
  if (FT_Set_Pixel_Sizes(face, 0, lround(requested))) {
    if (!face->num_fixed_sizes || FT_Select_Size(face, 0)) { FT_Done_Face(face); return nil; }
  }
  hb_font_t *shapingFont = hb_ft_font_create_referenced(face);
  hb_ft_font_set_load_flags(shapingFont, FT_LOAD_DEFAULT | FT_LOAD_COLOR);
  hb_buffer_t *shapingBuffer = hb_buffer_create();
  const char *utf8 = [text UTF8String];
  hb_buffer_add_utf8(shapingBuffer, utf8, (int)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, -1);
  hb_buffer_guess_segment_properties(shapingBuffer);
  hb_shape(shapingFont, shapingBuffer, NULL, 0);
  unsigned glyphCount;
  hb_glyph_info_t *glyphs = hb_buffer_get_glyph_infos(shapingBuffer, &glyphCount);
  hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(shapingBuffer, &glyphCount);
  NSInteger width = ceil(cellSize.width * columns), height = ceil(cellSize.height);
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
      initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
      bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
      colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
      bytesPerRow:width * 4 bitsPerPixel:32];
  unsigned char *pixels = [bitmap bitmapData];
  memset(pixels, 0, width * height * 4);
  CGFloat scale = requested / MAX(1, face->size->metrics.y_ppem);
  CGFloat advance = 0;
  for (unsigned i = 0; i < glyphCount; i++) advance += positions[i].x_advance / 64.0;
  if (advance * scale > width && advance > 0) scale = width / advance;
  CGFloat pen = MAX(0, (width - advance * scale) / 2);
  BOOL drew = NO;
  for (unsigned i = 0; i < glyphCount; i++) {
    if (FT_Load_Glyph(face, glyphs[i].codepoint, FT_LOAD_DEFAULT | FT_LOAD_COLOR)) continue;
    FT_GlyphSlot slot = face->glyph;
    if (slot->format != FT_GLYPH_FORMAT_BITMAP && FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL)) continue;
    FT_Bitmap *source = &slot->bitmap;
    CGFloat left = pen + (positions[i].x_offset / 64.0 + slot->bitmap_left) * scale;
    CGFloat top = height - baseline - (positions[i].y_offset / 64.0 + slot->bitmap_top) * scale;
    if (source->pixel_mode != FT_PIXEL_MODE_GRAY && source->pixel_mode != FT_PIXEL_MODE_MONO && source->pixel_mode != FT_PIXEL_MODE_BGRA) continue;
    CGFloat glyphScale = scale;
    if (source->pixel_mode == FT_PIXEL_MODE_BGRA && glyphCount == 1) {
      // Color fonts commonly have a single large bitmap strike. Fit the
      // complete image into its cells without cropping its bottom edge.
      glyphScale = MIN(scale, MIN(width / (CGFloat)MAX(1,source->width), height / (CGFloat)MAX(1,source->rows)));
      left = (width - source->width * glyphScale) / 2;
      top = (height - source->rows * glyphScale) / 2;
    }
    CGFloat tint[3] = {[color redComponent], [color greenComponent], [color blueComponent]};
    for (NSInteger dy = MAX(0, floor(top)); dy < MIN(height, ceil(top + source->rows * glyphScale)); dy++) {
      CGFloat sy = (dy + 0.5 - top) / glyphScale - 0.5;
      NSInteger y0 = floor(sy); CGFloat wy = sy - y0;
      for (NSInteger dx = MAX(0, floor(left)); dx < MIN(width, ceil(left + source->width * glyphScale)); dx++) {
        CGFloat sx = (dx + 0.5 - left) / glyphScale - 0.5;
        NSInteger x0 = floor(sx); CGFloat wx = sx - x0;
        CGFloat filtered[4] = {0,0,0,0};
        for (int yy=0; yy<2; yy++) for (int xx=0; xx<2; xx++) {
          CGFloat sample[4]; samplePixel(source,x0+xx,y0+yy,tint,sample);
          CGFloat weight = (xx ? wx : 1-wx) * (yy ? wy : 1-wy);
          for (int c=0; c<4; c++) filtered[c] += sample[c]*weight;
        }
        CGFloat alpha = filtered[3];
        CGFloat red = alpha ? filtered[0]/alpha : 0;
        CGFloat green = alpha ? filtered[1]/alpha : 0;
        CGFloat blue = alpha ? filtered[2]/alpha : 0;
        if (source->pixel_mode == FT_PIXEL_MODE_BGRA && textPresentation) {
          // Explicit VS15 requests text presentation even with a color-only font.
          red = green = blue = 0.2126*red + 0.7152*green + 0.0722*blue;
        }
        if (!alpha) continue;
        unsigned char *destination = pixels + (dy * width + dx) * 4;
        CGFloat oldAlpha = destination[3] / 255.0;
        CGFloat combined = alpha + oldAlpha * (1-alpha);
        destination[0] = lround(255 * (red*alpha + destination[0]/255.0*oldAlpha*(1-alpha)) / combined);
        destination[1] = lround(255 * (green*alpha + destination[1]/255.0*oldAlpha*(1-alpha)) / combined);
        destination[2] = lround(255 * (blue*alpha + destination[2]/255.0*oldAlpha*(1-alpha)) / combined);
        destination[3] = lround(255 * combined);
        drew = YES;
      }
    }
    pen += positions[i].x_advance / 64.0 * scale;
  }
  hb_buffer_destroy(shapingBuffer);
  hb_font_destroy(shapingFont);
  FT_Done_Face(face);
  if (!drew) { [bitmap release]; return nil; }
  NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
  [image addRepresentation:bitmap];
  [bitmap release];
  if ([images count] >= 256) [images removeAllObjects];
  [images setObject:image forKey:key];
  return [image autorelease];
}
@end
