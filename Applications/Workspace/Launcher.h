/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id       window;
  id       commandName;
  id       runInTerminal;
  id       historyAndCompletion;

  NSString *commandMode;
  BOOL     historyMode;
  BOOL     filesystemMode;
  NSString *savedString;
}

+ shared;

- (void)runCommand:(id)sender;

@end
