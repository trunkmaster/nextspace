/* All Rights reserved */

#include <AppKit/AppKit.h>

@class FileViewer;

@interface Finder : NSObject
{
  FileViewer *fileViewer;
  
  id window;
  id shelf;
  id findButton;
  id findField;
  id findScopeButton;
  id resultList;
  id resultsFound;
  id resultIcon;

  NSArray   *variantList;
  NSInteger resultIndex;

  BOOL isRunInTerminal;
}

- initWithFileViewer:(FileViewer *)fv;
  
- (void)activateWithString:(NSString *)searchString;
- (void)deactivate;

- (void)updateButtonsState;

@end

@interface Finder (Shelf)
- (void)initShelf;
- (NSDictionary *)shelfRepresentation;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

@end
