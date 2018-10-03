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
  id iconPlace;

  NSArray   *variantList;
  NSInteger resultIndex;

  BOOL isRunInTerminal;

  // Shelf
  NSSet *savedSelection;
}

- initWithFileViewer:(FileViewer *)fv;
  
- (void)activateWithString:(NSString *)searchString;
- (void)deactivate;

- (void)updateButtonsState;

@end

@interface Finder (Shelf)
- (void)initShelf;
- (NSDictionary *)shelfRepresentation;
- (void)resignSelection;
- (void)restoreSelection;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

@end
