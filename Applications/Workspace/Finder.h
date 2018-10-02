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
  id runInTerminal;
  id resultList;

  NSArray   *completionSource;
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
