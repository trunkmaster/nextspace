/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface Finder : NSObject
{
  id window;
  id shelf;
  id findButton;
  id findField;
  id findScopeButton;
  id runInTerminal;
  id completionList;

  NSArray         *searchPaths;
  NSMutableString *savedCommand;
  NSMutableArray  *historyList;
  
  NSArray   *completionSource;
  NSArray   *commandVariants;
  NSInteger completionIndex;

  BOOL isRunInTerminal;
}

- (void)activate;
- (void)deactivate;

- (void)initHistory;
- (void)saveHistory;
- (void)updateButtonsState;

@end

@interface Finder (Shelf)
- (void)initShelf;
- (NSDictionary *)shelfRepresentation;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

@end
