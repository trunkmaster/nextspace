/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id window;
  id commandName;
  id runInTerminal;
  id historyAndCompletion;

  NSString       *wmHistoryPath;
  NSMutableArray *wmHistory;
  NSInteger      wmHistoryIndex;

  NSString *commandMode;
  BOOL     historyMode;
  BOOL     filesystemMode;
}

- (void)activate;
- (void)deactivate;

@end
