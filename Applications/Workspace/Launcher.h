/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Launcher : NSObject
{
  id window;
  id commandField;
  id runInTerminal;
  id completionList;

  NSArray   *completionSource;
  NSArray   *commandVariants;
  NSInteger completionIndex;
  
  NSString       *wmHistoryPath;
  NSMutableArray *wmHistory;

}

- (void)activate;
- (void)deactivate;

@end
