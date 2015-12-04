/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id       window;
  id       commandName;
  NSString *savedString;
}

+ shared;

- (void)runCommand:(id)sender;

@end
