/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id window;
  id commandField;
  id runInTerminal;
  id completionList;
  id runButton;

  NSMutableString *savedCommand;
  NSMutableArray  *historyList;
  
  NSArray   *completionSource;
  NSArray   *commandVariants;
  NSInteger completionIndex;  
}

- (void)activate;
- (void)deactivate;

- (void)initHistory;
- (void)saveHistory;

@end
