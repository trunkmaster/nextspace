/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id window;
  id commandName;
  id runInTerminal;
  id historyAndCompletion;

  NSArray        *completionSource;
  
  NSString       *wmHistoryPath;
  NSMutableArray *wmHistory;
  NSInteger      wmHistoryIndex;

  BOOL    historyMode;
  BOOL    filesystemMode;
  NSArray *commandVariants;
}

- (void)activate;
- (void)deactivate;

@end
