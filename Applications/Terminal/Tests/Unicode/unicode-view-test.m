#import <AppKit/AppKit.h>
#import "TerminalView.h"
#import "TerminalGlyphRenderer.h"
#include <assert.h>

@interface TerminalView (UnicodeTest)
- (NSString *)_selectionAsString;
- (NSString *)textForCell:(screen_char_t)cell;
@end

@interface UnicodeTestView : TerminalView
{
  NSMutableData *sentBytes;
}
- (NSData *)sentBytes;
- (void)clearSentBytes;
- (void)testGraphemeCollection;
@end
@implementation UnicodeTestView
- (void)dealloc { [sentBytes release]; [super dealloc]; }
- (void)ts_sendCString:(const char *)bytes length:(int)length {
  if (!sentBytes) sentBytes = [NSMutableData new];
  [sentBytes appendBytes:bytes length:length];
}
- (void)assertSnapshotScrollInvalidation { assert(pending_scroll == 0); }
- (NSData *)sentBytes { return sentBytes; }
- (void)clearSentBytes { [sentBytes setLength:0]; }
- (void)testGraphemeCollection {
  for (NSUInteger i=0; i<15000; i++) {
    NSString *text = [NSString stringWithFormat:@"x%lu\u0301", (unsigned long)i];
    uint32_t handle = [self ts_internGrapheme:text];
    screen[0].ch = 'x'; screen[0].grapheme = handle;
    assert([[self textForCell:screen[0]] isEqualToString:text]);
  }
  NSUInteger limit = MAX(4096, (curr_sb_depth + screen_height) * screen_width * 2);
  assert([graphemeTexts count] <= limit);
}
@end

static NSUInteger coloredPixels(NSImage *image)
{
  NSBitmapImageRep *bitmap = [[image representations] objectAtIndex:0];
  unsigned char *pixels = [bitmap bitmapData];
  NSUInteger colored = 0;
  for (NSInteger y=0; y<[bitmap pixelsHigh]; y++) for (NSInteger x=0; x<[bitmap pixelsWide]; x++) {
    unsigned char *p = pixels + y*[bitmap bytesPerRow] + x*4;
    if (p[3] > 32 && (abs((int)p[0]-p[1]) > 15 || abs((int)p[1]-p[2]) > 15)) colored++;
  }
  return colored;
}

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  [NSApplication sharedApplication];
  Defaults *preferences = [Defaults shared];
  UnicodeTestView *view = [[UnicodeTestView alloc] initWithPreferences:preferences];
  NSFont *font = [NSFont fontWithName:@"Keith-Medium" size:20];
  TerminalGlyphRenderer *renderer = [TerminalGlyphRenderer new];
  for (NSString *text in @[@"中", @"日", @"한"]) {
    NSImage *image = [renderer imageForString:text font:font
        cellSize:NSMakeSize(12,24) baseline:4 columns:2 color:[NSColor blackColor]];
    assert(image);
    NSBitmapImageRep *bitmap = [[image representations] objectAtIndex:0];
    unsigned char *bytes = [bitmap bitmapData];
    NSUInteger ink = 0;
    for (NSUInteger i=3; i<[bitmap bytesPerRow]*[bitmap pixelsHigh]; i+=4) ink += bytes[i] > 0;
    assert(ink > 10);
  }
  NSString *sample = @"ABC中日한Z";
  NSData *input = [sample dataUsingEncoding:NSUTF8StringEncoding];
  [[view terminalParser] processData:[input bytes] length:[input length]];
  [view setSelectedRange:NSMakeRange(0,10)];
  assert([[view _selectionAsString] isEqualToString:sample]);
  NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:@"NextSpaceUnicodeTest"];
  [pasteboard declareTypes:@[NSStringPboardType] owner:nil];
  [view writeSelectionToPasteboard:pasteboard types:@[NSStringPboardType]];
  assert([[pasteboard stringForType:NSStringPboardType] isEqualToString:sample]);
  [view setFrameSize:NSMakeSize(800,300)];
  [view setSelectedRange:NSMakeRange(0,10)];
  assert([[view _selectionAsString] isEqualToString:sample]);
  [view setSelectedRange:NSMakeRange(0,0)];
  NSString *unicode = @"e\u0301 😀 👩🏽‍💻 🇯🇵 ❤️ 𠮷";
  NSString *woman = @"👩🏽‍💻";
  NSData *clear = [@"\033[2J\033[H" dataUsingEncoding:NSUTF8StringEncoding];
  [[view terminalParser] processData:[clear bytes] length:[clear length]];
  NSData *unicodeBytes = [unicode dataUsingEncoding:NSUTF8StringEncoding];
  // Feed one byte at a time, including inside supplementary scalars and ZWJ sequences.
  const unsigned char *raw = [unicodeBytes bytes];
  for (NSUInteger i=0; i<[unicodeBytes length]; i++) [[view terminalParser] processByte:raw[i]];
  [view setSelectedRange:NSMakeRange(0,16)];
  assert([[view _selectionAsString] isEqualToString:unicode]);
  [pasteboard setString:unicode forType:NSStringPboardType];
  [[view terminalParser] sendString:[pasteboard stringForType:NSStringPboardType]];
  assert([[view sentBytes] isEqualToData:unicodeBytes]);
  [view clearSentBytes];
  NSEvent *emojiEvent = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0
      timestamp:0 windowNumber:0 context:nil characters:@"😀" charactersIgnoringModifiers:@"😀"
      isARepeat:NO keyCode:0];
  [[view terminalParser] handleKeyEvent:emojiEvent];
  assert([[view sentBytes] isEqualToData:[@"😀" dataUsingEncoding:NSUTF8StringEncoding]]);
  NSRange found = [[view stringRepresentation] rangeOfString:woman];
  assert(found.location != NSNotFound);
  [view setSelectedTextRange:found];
  assert([[view _selectionAsString] isEqualToString:woman]);
  assert(NSEqualRanges([view selectedTextRange],found));
  [view setSelectedRange:NSMakeRange(6,1)]; // select only the second column of the ZWJ emoji
  assert([[view _selectionAsString] isEqualToString:woman]);
  for (NSString *cluster in @[@"e\u0301", @"😀", woman, @"🇯🇵", @"❤️", @"𠮷"]) {
    assert([renderer imageForString:cluster font:font cellSize:NSMakeSize(12,24)
        baseline:4 columns:2 color:[NSColor blackColor]]);
  }
  for (NSNumber *size in @[@12,@20,@32]) {
    NSFont *sizedFont = [NSFont fontWithName:@"Keith-Medium" size:[size doubleValue]];
    for (NSString *cluster in @[@"😀", woman, @"🇯🇵", @"❤️"]) {
      NSImage *image = [renderer imageForString:cluster font:sizedFont
          cellSize:NSMakeSize([size doubleValue]*0.6,[size doubleValue]*1.2)
          baseline:[size doubleValue]*0.2 columns:2 color:[NSColor blackColor]];
      assert(image && coloredPixels(image) > 4);
    }
  }
  NSImage *textEmoji = [renderer imageForString:@"😀\ufe0e" font:font
      cellSize:NSMakeSize(12,24) baseline:4 columns:2 color:[NSColor blackColor]];
  assert(textEmoji && coloredPixels(textEmoji) == 0);
  NSImage *joined = [renderer imageForString:woman font:font
      cellSize:NSMakeSize(12,24) baseline:4 columns:2 color:[NSColor blackColor]];
  NSImage *unjoined = [renderer imageForString:@"👩" font:font
      cellSize:NSMakeSize(12,24) baseline:4 columns:2 color:[NSColor blackColor]];
  NSBitmapImageRep *joinedBits = [[joined representations] objectAtIndex:0];
  NSBitmapImageRep *unjoinedBits = [[unjoined representations] objectAtIndex:0];
  assert(![[NSData dataWithBytes:[joinedBits bitmapData] length:[joinedBits bytesPerRow]*[joinedBits pixelsHigh]]
      isEqualToData:[NSData dataWithBytes:[unjoinedBits bitmapData] length:[unjoinedBits bytesPerRow]*[unjoinedBits pixelsHigh]]]);
  [[view terminalParser] processData:[clear bytes] length:[clear length]];
  [[view terminalParser] setCharset:@"SHIFT_JIS"];
  const unsigned char japanese[] = {0x93,0xfa}; // 日 in Shift-JIS
  [[view terminalParser] processByte:japanese[0]];
  [[view terminalParser] processByte:japanese[1]];
  [view setSelectedRange:NSMakeRange(0,2)];
  assert([[view _selectionAsString] isEqualToString:@"日"]);
  [view clearSentBytes];
  [[view terminalParser] sendString:@"日"];
  assert([[view sentBytes] isEqualToData:[NSData dataWithBytes:japanese length:sizeof(japanese)]]);
  [[view terminalParser] setCharset:@"UTF-8"];
  [view setSelectedRange:NSMakeRange(0,0)];
  NSMutableString *longCluster = [NSMutableString stringWithString:@"e"];
  for (int i=0; i<40; i++) [longCluster appendString:@"\u0301"];
  [[view terminalParser] processData:[clear bytes] length:[clear length]];
  NSData *longBytes = [longCluster dataUsingEncoding:NSUTF8StringEncoding];
  [[view terminalParser] processData:[longBytes bytes] length:[longBytes length]];
  [view setSelectedRange:NSMakeRange(0,1)];
  assert([[view _selectionAsString] isEqualToString:longCluster]);
  [view setSelectedRange:NSMakeRange(0,0)];
  NSMutableString *lines = [NSMutableString string];
  for (int i=0; i<80; i++) [lines appendFormat:@"%@\r\n", unicode];
  NSData *scrolling = [lines dataUsingEncoding:NSUTF8StringEncoding];
  [[view terminalParser] processData:[scrolling bytes] length:[scrolling length]];
  [view assertSnapshotScrollInvalidation];
  found = [[view stringRepresentation] rangeOfString:unicode];
  assert(found.location != NSNotFound);
  [view setSelectedTextRange:found];
  assert([[view _selectionAsString] isEqualToString:unicode]);
  [view setSelectedRange:NSMakeRange(0,0)];
  [view setFrameSize:NSMakeSize(560,420)];
  [view changeScrollBackBufferDepth:30];
  found = [[view stringRepresentation] rangeOfString:woman];
  assert(found.location != NSNotFound);
  [view setSelectedTextRange:found];
  assert([[view _selectionAsString] isEqualToString:woman]);
  [view setSelectedRange:NSMakeRange(0,0)];
  UnicodeTestView *collection = [[UnicodeTestView alloc] initWithPreferences:preferences];
  [collection testGraphemeCollection];
  [collection release];
  if (argc > 1) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(300,300,980,360)
        styleMask:NSTitledWindowMask | NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [window setTitle:@"Terminal Unicode acceptance"];
    [window setContentView:view];
    [window makeKeyAndOrderFront:nil];
    [window display];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:12]];
    [window close];
  }
  puts("PASS: CJK; split Unicode scalars/graphemes; paste/key input; selection/search; history growth/shrink/resize; bounded grapheme collection; color emoji at 12/20/32pt; VS15 text presentation; split Shift-JIS round trip");
  [renderer release];
  [view release];
  [pool drain];
  return 0;
}
