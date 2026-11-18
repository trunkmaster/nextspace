#import <AppKit/AppKit.h>
#import "TerminalParser_Ghostty.h"
#include <assert.h>
#include <string.h>

@interface TestScreen : NSObject <TerminalScreen>
{
@public
  int cols, rows, cx, cy;
  screen_char_t cells[100 * 100];
  NSMutableString *history;
  NSMutableData *replies;
  NSMutableData *historyCells;
  NSString *title;
  BOOL visible;
}
@end
@implementation TestScreen
- (id)init { self = [super init]; cols=10; rows=3; history=[NSMutableString new]; replies=[NSMutableData new]; historyCells=[NSMutableData new]; visible=YES; return self; }
- (void)dealloc { [history release]; [replies release]; [historyCells release]; [title release]; [super dealloc]; }
- (id)preferences { return self; }
- (NSString *)characterSet { return @"UTF-8"; }
- (BOOL)doubleEscape { return NO; }
- (BOOL)alternateAsMeta { return YES; }
- (BOOL)useMultiCellGlyphs { return YES; }
- (int)relativeWidthOfCharacter:(unichar)ch { return ch >= 0x3000 ? 2 : 1; }
- (void)ts_sendCString:(const char *)s { [self ts_sendCString:s length:strlen(s)]; }
- (void)ts_sendCString:(const char *)s length:(int)length { [replies appendBytes:s length:length]; }
- (void)ts_gotoX:(int)x Y:(int)y { cx=x; cy=y; }
- (void)ts_setCursorVisible:(BOOL)value { visible=value; }
- (void)ts_putChar:(screen_char_t)c count:(int)n atX:(int)x Y:(int)y {
  assert(x>=0 && y>=0 && x+n<=cols && y<rows);
  for (int i=0; i<n; i++) cells[y*cols+x+i]=c;
}
- (void)ts_putChar:(screen_char_t)c count:(int)n offset:(int)offset {
  for (int i=0; i<n; i++) cells[offset+i]=c;
}
- (screen_char_t)ts_getCharAtX:(int)x Y:(int)y { return cells[y*cols+x]; }
- (void)ts_scrollUpTop:(int)t bottom:(int)b rows:(int)n save:(BOOL)save {
  assert(t==0 && b==rows && n==1);
  if (save) {
    [historyCells appendBytes:cells length:cols*sizeof(*cells)];
    for (int i=0; i<cols; i++) [history appendString:TerminalStringForScalar(cells[i].ch)];
    [history appendString:@"\n"];
  }
  memmove(cells, cells+cols, (rows-1)*cols*sizeof(*cells));
}
- (void)ts_scrollDownTop:(int)t bottom:(int)b rows:(int)n { assert(0); }
- (void)ts_shiftRow:(int)y at:(int)x delta:(int)d { assert(0); }
- (void)ts_setTitle:(NSString *)value type:(int)type { [title release]; title=[value copy]; }
@end

static void feed(TerminalParser_Ghostty *parser, const char *s) {
  [parser processData:(const unsigned char *)s length:strlen(s)];
}
static NSEvent *up(void) {
  unichar code=NSUpArrowFunctionKey;
  NSString *s=[NSString stringWithCharacters:&code length:1];
  return [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0
      timestamp:0 windowNumber:0 context:nil characters:s charactersIgnoringModifiers:s
      isARepeat:NO keyCode:0];
}
int main(void) {
  NSAutoreleasePool *pool=[NSAutoreleasePool new];
  TestScreen *screen=[TestScreen new];
  TerminalParser_Ghostty *parser=[[TerminalParser_Ghostty alloc]
      initWithTerminalScreen:screen width:screen->cols height:screen->rows];
  assert(parser);
  GhosttyColorRgb palette[256];
  ghostty_color_palette_default(palette);
  uint32_t red = TerminalRGB(palette[1].r, palette[1].g, palette[1].b);
  feed(parser, "hello");
  assert(screen->cells[0].foregroundColor == TERMINAL_COLOR_DEFAULT);
  assert(screen->cells[0].backgroundColor == TERMINAL_COLOR_DEFAULT);
  feed(parser, "\033[H\033[38;2;12;34;56;48;2;23;45;67mX");
  assert(screen->cells[0].foregroundColor == TerminalRGB(12,34,56));
  assert(screen->cells[0].backgroundColor == TerminalRGB(23,45,67));
  screen_char_t before = screen->cells[0];
  feed(parser, "\033[H\033[38;2;13;34;56mX");
  assert(screen->cells[0].foregroundColor == TerminalRGB(13,34,56));
  assert(!TerminalCellAppearanceEqual(before, screen->cells[0]));
  before=screen->cells[0]; before.attr ^= 0xc0;
  assert(TerminalCellAppearanceEqual(before, screen->cells[0]));
  feed(parser, "\033[H\033[0mhello");
  assert(screen->cells[0].ch=='h' && screen->cells[4].ch=='o' && screen->cx==5);
  feed(parser, "\033[2J\033[H\033[1;31mR\033[0m");
  assert(screen->cells[0].ch=='R' && screen->cells[0].foregroundColor==red && (screen->cells[0].attr&3)==2);
  feed(parser, "\033[H\033[41m \033[0m");
  assert(screen->cells[0].backgroundColor==red);
  // Every indexed color survives without RGB quantization or default-slot collisions.
  for (unsigned i=0; i<256; i++) {
    char sequence[80];
    snprintf(sequence,sizeof(sequence),"\033[H\033[38;5;%u;48;5;%umX",i,255-i);
    feed(parser, sequence);
    assert(screen->cells[0].foregroundColor == TerminalRGB(palette[i].r,palette[i].g,palette[i].b));
    assert(screen->cells[0].backgroundColor == TerminalRGB(palette[255-i].r,palette[255-i].g,palette[255-i].b));
  }
  feed(parser,"\033[H\033[38;2;255;255;255;48;2;0;0;0mX");
  assert(screen->cells[0].foregroundColor == TerminalRGB(255,255,255));
  assert(screen->cells[0].backgroundColor == TerminalRGB(0,0,0));
  feed(parser,"\033[H\033[0mX\033]10;#123456\007\033]11;#234567\007");
  assert(screen->cells[0].foregroundColor == TerminalRGB(0x12,0x34,0x56));
  assert(screen->cells[0].backgroundColor == TerminalRGB(0x23,0x45,0x67));
  feed(parser,"\033]110\007\033]111\007");
  assert(screen->cells[0].foregroundColor == TERMINAL_COLOR_DEFAULT);
  assert(screen->cells[0].backgroundColor == TERMINAL_COLOR_DEFAULT);
  feed(parser,"\033[H\033[38;5;42mX\033]4;42;#abcdef\007");
  assert(screen->cells[0].foregroundColor == TerminalRGB(0xab,0xcd,0xef));
  feed(parser,"\033]104;42\007\033[0m");
  feed(parser, "\033[H\033[2J\033]2;Ghostty test\007");
  assert([screen->title isEqualToString:@"Ghostty test"]);
  feed(parser, "\033[?25l"); assert(!screen->visible);
  feed(parser, "\033[?25h"); assert(screen->visible);
  const unsigned char first[]={0xd0}, second[]={0x96};
  [parser processData:first length:1]; [parser processData:second length:1];
  assert(screen->cells[0].ch==0x416);
  feed(parser, "\033[H\033[2J\xe4\xb8\xad");
  assert(screen->cells[0].ch==0x4e2d && screen->cells[1].ch==MULTI_CELL_GLYPH);
  feed(parser, "\033[H\033[2J\033[38;2;12;34;56;48;2;23;45;67mPRIMARY\033[?1049hALT\033[?1049l");
  assert(screen->cells[0].foregroundColor == TerminalRGB(12,34,56));
  assert(screen->cells[0].backgroundColor == TerminalRGB(23,45,67));
  assert(screen->cells[0].ch=='P' && screen->cells[1].ch=='R');
  feed(parser, "\033[H\033[2J");
  [screen->history setString:@""];
  feed(parser, "one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n");
  assert([screen->history hasPrefix:@"one       \ntwo       \nthree     \n"]);
  assert(screen->cells[0].ch=='f' && screen->cells[10].ch=='f');
  assert([screen->historyCells length]>=sizeof(screen_char_t));
  screen_char_t saved;
  [screen->historyCells getBytes:&saved length:sizeof(saved)];
  assert(saved.foregroundColor == TerminalRGB(12,34,56));
  assert(saved.backgroundColor == TerminalRGB(23,45,67));
  [screen->replies setLength:0]; feed(parser,"\033[6n");
  assert([screen->replies length] && ((char *)[screen->replies bytes])[0]=='\033');
  [screen->replies setLength:0]; [parser handleKeyEvent:up()];
  assert([screen->replies isEqualToData:[NSData dataWithBytes:"\033[A" length:3]]);
  feed(parser,"\033[?1h"); [screen->replies setLength:0]; [parser handleKeyEvent:up()];
  assert([screen->replies isEqualToData:[NSData dataWithBytes:"\033OA" length:3]]);
  feed(parser,"\033[H\033[2J\033[38;2;98;76;54;48;2;87;65;43mX");
  screen->cols=12; screen->rows=4;
  [parser setTerminalScreenWidth:12 height:4 cursorY:screen->cy];
  assert(screen->cells[0].foregroundColor == TerminalRGB(98,76,54));
  assert(screen->cells[0].backgroundColor == TerminalRGB(87,65,43));
  feed(parser,"\033[H\033[2JZ"); assert(screen->cells[0].ch=='Z');
  [parser setCharset:@"ISO-8859-1"];
  feed(parser,"\033[H\033[2J\xe9"); assert(screen->cells[0].ch==0xe9);
  // Cross the engine's 10,000-line history limit. A growing history count
  // alone cannot detect scrolling once pruning starts; tracked rows must work.
  feed(parser,"\033[H\033[2J"); [screen->history setString:@""];
  char chunk[100];
  for (int i=0; i<50; i++) { chunk[i*2]='\r'; chunk[i*2+1]='\n'; }
  for (int i=0; i<241; i++) [parser processData:(unsigned char *)chunk length:sizeof(chunk)];
  assert([screen->history length] == (12050 - 3) * 13);
  [parser release]; [screen release];
  puts("PASS: RGB, all 256 palette colors, OSC defaults/palette, color-only damage, grid, SGR, title, cursor visibility, split UTF-8, wide cells, alternate screen, scrollback including history pruning, DSR, application keys, resize, Latin-1");
  [pool drain];
  return 0;
}
