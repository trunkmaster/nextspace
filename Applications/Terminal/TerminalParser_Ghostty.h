/* GPL-2.0-or-later, like Terminal.app. */
#import "TerminalParser_Linux.h"
#undef foreground
#undef background
#include <ghostty/vt.h>

// Reuse the existing user input/charset preferences, not its VT parser.
@interface TerminalParser_Ghostty : TerminalParser_Linux
{
  GhosttyTerminal terminal;
  GhosttyKeyEncoder keyEncoder;
  iconv_t outputToUTF8;
  NSMutableData *outputPending;
}
- (void)processData:(const unsigned char *)bytes length:(NSUInteger)length;
@end
