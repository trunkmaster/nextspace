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
  NSString *title;
  BOOL visible;
}
@end
@implementation TestScreen
- (id)init { self = [super init]; cols=10; rows=3; history=[NSMutableString new]; replies=[NSMutableData new]; visible=YES; return self; }
- (void)dealloc { [history release]; [replies release]; [title release]; [super dealloc]; }
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
    for (int i=0; i<cols; i++) [history appendFormat:@"%C", cells[i].ch];
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
  feed(parser, "hello");
  assert(screen->cells[0].ch=='h' && screen->cells[4].ch=='o' && screen->cx==5);
  feed(parser, "\033[2J\033[H\033[1;31mR\033[0m");
  assert(screen->cells[0].ch=='R' && (screen->cells[0].color&15)==1 && (screen->cells[0].attr&3)==2);
  feed(parser, "\033[H\033[41m \033[0m");
  assert((screen->cells[0].color>>4)==1);
  feed(parser, "\033[H\033[2J\033]2;Ghostty test\007");
  assert([screen->title isEqualToString:@"Ghostty test"]);
  feed(parser, "\033[?25l"); assert(!screen->visible);
  feed(parser, "\033[?25h"); assert(screen->visible);
  const unsigned char first[]={0xd0}, second[]={0x96};
  [parser processData:first length:1]; [parser processData:second length:1];
  assert(screen->cells[0].ch==0x416);
  feed(parser, "\033[H\033[2J\xe4\xb8\xad");
  assert(screen->cells[0].ch==0x4e2d && screen->cells[1].ch==MULTI_CELL_GLYPH);
  feed(parser, "\033[H\033[2JPRIMARY\033[?1049hALT\033[?1049l");
  assert(screen->cells[0].ch=='P' && screen->cells[1].ch=='R');
  feed(parser, "\033[H\033[2J");
  [screen->history setString:@""];
  feed(parser, "one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n");
  assert([screen->history hasPrefix:@"one       \ntwo       \nthree     \n"]);
  assert(screen->cells[0].ch=='f' && screen->cells[10].ch=='f');
  [screen->replies setLength:0]; feed(parser,"\033[6n");
  assert([screen->replies length] && ((char *)[screen->replies bytes])[0]=='\033');
  [screen->replies setLength:0]; [parser handleKeyEvent:up()];
  assert([screen->replies isEqualToData:[NSData dataWithBytes:"\033[A" length:3]]);
  feed(parser,"\033[?1h"); [screen->replies setLength:0]; [parser handleKeyEvent:up()];
  assert([screen->replies isEqualToData:[NSData dataWithBytes:"\033OA" length:3]]);
  screen->cols=12; screen->rows=4;
  [parser setTerminalScreenWidth:12 height:4 cursorY:screen->cy];
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
  puts("PASS: grid, SGR, title, cursor visibility, split UTF-8, wide cells, alternate screen, scrollback including history pruning, DSR, application keys, resize, Latin-1");
  [pool drain];
  return 0;
}
