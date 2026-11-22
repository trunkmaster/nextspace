#import <AppKit/AppKit.h>
#import "TerminalView.h"
#import "TerminalParser_Ghostty.h"
#import "TerminalColors.h"
#include <assert.h>
#include <math.h>
#include <unistd.h>

@interface ColorTestApplication : NSApplication
@end
@implementation ColorTestApplication
- (void)reportException:(NSException *)exception {
  fprintf(stderr,"RENDER TEST EXCEPTION: %s: %s\n",[[exception name] UTF8String],[[exception reason] UTF8String]);
  _exit(1);
}
@end
static void failedException(NSException *exception) {
  fprintf(stderr,"RENDER TEST EXCEPTION: %s: %s\n",[[exception name] UTF8String],[[exception reason] UTF8String]);
  _exit(1);
}

@interface ColorTestView : TerminalView
- (NSRect)cellRect:(int)x row:(int)y;
- (void)paint;
@end
@implementation ColorTestView
- (NSRect)cellRect:(int)x row:(int)y {
  return NSMakeRect(border_x+x*fx,border_y+(screen_height-1-y)*fy,fx,fy);
}
- (void)paint { draw_all=2; shouldDrawCursor=NO; terminalCursorVisible=NO; [self drawRect:[self bounds]]; }
@end

static NSBitmapImageRep *snapshot(ColorTestView *view) {
  [view lockFocus]; [view paint];
  NSBitmapImageRep *image=[[NSBitmapImageRep alloc] initWithFocusedViewRect:[view bounds]];
  [view unlockFocus];
  return [image autorelease];
}
static unsigned pixel(NSBitmapImageRep *image, int x, int y) {
  // back-art's focused-view readback has valid RGB but zero alpha. colorAtX:
  // unpremultiplies it to white, so inspect the captured RGB channels directly.
  assert([image bitsPerPixel]==32 && [image samplesPerPixel]==4 && [image bitmapFormat]==0);
  unsigned char *p=[image bitmapData]+y*[image bytesPerRow]+x*4;
  return (p[0]<<16)|(p[1]<<8)|p[2];
}
static BOOL matches(unsigned actual, unsigned expected) {
  return abs((int)((actual>>16)&255)-(int)((expected>>16)&255))<=1 &&
      abs((int)((actual>>8)&255)-(int)((expected>>8)&255))<=1 &&
      abs((int)(actual&255)-(int)(expected&255))<=1;
}
static void solidCell(NSBitmapImageRep *image, NSRect rect, unsigned rgb) {
  // Bitmap rows run top-to-bottom, view coordinates bottom-to-top.
  for (int x=ceil(NSMinX(rect))+1; x<floor(NSMaxX(rect))-1; x++)
    for (int y=ceil(NSMinY(rect))+1; y<floor(NSMaxY(rect))-1; y++) {
      unsigned c=pixel(image,x,[image pixelsHigh]-1-y);
      if (!matches(c,rgb)) { NSLog(@"expected %06x at %d,%d, got %06x",rgb,x,y,c); abort(); }
    }
}
static void glyphColor(NSBitmapImageRep *image, NSRect rect, unsigned rgb) {
  unsigned count=0;
  for(int x=ceil(NSMinX(rect));x<floor(NSMaxX(rect));x++)
    for(int y=ceil(NSMinY(rect));y<floor(NSMaxY(rect));y++)
      if(matches(pixel(image,x,[image pixelsHigh]-1-y),rgb)) count++;
  if (!count) NSLog(@"missing glyph RGB %06x",rgb);
  assert(count>0);
}
static void feed(ColorTestView *view, const char *text) {
  [(TerminalParser_Ghostty *)[view terminalParser] processData:(const unsigned char *)text length:strlen(text)];
}
int main(void) {
  NSAutoreleasePool *pool=[NSAutoreleasePool new];
  NSSetUncaughtExceptionHandler(failedException);
  [ColorTestApplication sharedApplication];
  Defaults *prefs=[[Defaults alloc] initWithDefaults:[NSMutableDictionary dictionary]];
  [prefs setWindowWidth:16]; [prefs setWindowHeight:4];
  [prefs setTerminalFont:[NSFont fontWithName:@"Keith" size:18]];
  ColorTestView *view=[[ColorTestView alloc] initWithPreferences:prefs];
  [view setBorderX:0 Y:0];
  NSRect last=[view cellRect:15 row:0];
  [view setFrame:NSMakeRect(0,0,NSMaxX(last),NSMaxY(last))];
  NSWindow *window=[[NSWindow alloc] initWithContentRect:[view frame]
      styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:view]; [window orderFront:nil];
  feed(view,"\033[2J\033[H\033[38;2;12;34;56;48;2;23;45;67m H \033[48;2;24;45;67m \033[0m");
  NSBitmapImageRep *image=snapshot(view);
  solidCell(image,[view cellRect:0 row:0],0x172d43);
  glyphColor(image,[view cellRect:1 row:0],0x0c2238);
  solidCell(image,[view cellRect:2 row:0],0x172d43);
  solidCell(image,[view cellRect:3 row:0],0x182d43);
  // A same-glyph/same-legacy-slot color change must damage the cell.
  feed(view,"\033[H\033[48;2;25;45;67m ");
  assert([view ts_getCharAtX:0 Y:0].backgroundColor==TerminalRGB(25,45,67));
  solidCell(snapshot(view),[view cellRect:0 row:0],0x192d43);
  // Inverse swaps explicit foreground/background, including glyph paint.
  feed(view,"\033[H\033[7;38;2;12;34;56;48;2;23;45;67m H ");
  image=snapshot(view);
  solidCell(image,[view cellRect:0 row:0],0x0c2238);
  glyphColor(image,[view cellRect:1 row:0],0x172d43);
  // Selection overrides RGB; unselect must recover the stored colors.
  [view setSelectedRange:NSMakeRange(0,3)];
  image=snapshot(view);
  NSColor *selection=[[prefs windowSelectionColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  NSRect r=[view cellRect:0 row:0];
  assert(matches(pixel(image,NSMidX(r),[image pixelsHigh]-1-NSMidY(r)),
      TerminalRGB(lround([selection redComponent]*255),lround([selection greenComponent]*255),lround([selection blueComponent]*255))));
  [view setSelectedRange:NSMakeRange(0,0)];
  solidCell(snapshot(view),[view cellRect:0 row:0],0x0c2238);
  // Explicit white and black must not become terminal default colors.
  feed(view,"\033[0m\033[H\033[38;2;255;255;255;48;2;0;0;0mH ");
  image=snapshot(view);glyphColor(image,[view cellRect:0 row:0],0xffffff);
  solidCell(image,[view cellRect:1 row:0],0x000000);
  // Sample the actual fill for every one of Ghostty's 256 palette entries.
  GhosttyColorRgb palette[256]; ghostty_color_palette_default(palette);
  for (unsigned base=0;base<256;base+=16) {
    for(unsigned col=0;col<16;col++) {
      char seq[80]; snprintf(seq,sizeof(seq),"\033[0m\033[1;%uH\033[48;5;%um ",col+1,base+col);
      feed(view,seq);
    }
    image=snapshot(view);
    for(unsigned col=0;col<16;col++) {
      GhosttyColorRgb rgb=palette[base+col];
      solidCell(image,[view cellRect:col row:0],TerminalRGB(rgb.r,rgb.g,rgb.b));
    }
  }
  // Faint dims explicit foreground only; bold must not replace explicit RGB.
  feed(view,"\033[0m\033[H\033[1;38;2;12;34;56;48;2;23;45;67mH");
  glyphColor(snapshot(view),[view cellRect:0 row:0],0x0c2238);
  feed(view,"\033[H\033[0;2;38;2;12;34;56mH");
  glyphColor(snapshot(view),[view cellRect:0 row:0],0x06111c);
  puts("PASS: real back-art pixels: exact RGB backgrounds/glyphs, adjacent runs, color-only update, inverse, selection/unselect, explicit white/black, all 256 palette fills, bold/faint RGB");
  [window orderOut:nil];
  [pool drain];return 0;
}
