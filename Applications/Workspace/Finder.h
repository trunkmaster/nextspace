/* All Rights reserved */

#import <AppKit/AppKit.h>

#import "WMShelf.h"

@class FileViewer;

@interface Finder : NSObject
{
  FileViewer *fileViewer;
  
  WMShelf	*shelf;
  id		window;
  id		findButton;
  id		findField;
  id		findScopeButton;
  id		statusField;
  id		resultList;
  id		resultsFound;
  id		resultIcon;
  id		iconPlace;

  NSMutableArray *variantList;
  NSInteger      resultIndex;

  BOOL isRunInTerminal;

  // Shelf
  NSSet *savedSelection;
}

- (id)initWithFileViewer:(FileViewer *)fv;
- (void)setFileViewer:(FileViewer *)fv;
  
- (void)activateWithString:(NSString *)searchString;
- (void)deactivate;
- (NSWindow *)window;

- (void)updateButtonsState;

@end

@interface Finder (Shelf)
- (NSArray *)storableShelfSelection;
- (void)reconstructShelfSelection:(NSArray *)selectedSlots;
- (void)resignShelfSelection;
- (void)restoreShelfSelection;
@end
