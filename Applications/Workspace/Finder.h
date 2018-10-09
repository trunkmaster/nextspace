/* All Rights reserved */

#import <AppKit/AppKit.h>

#import "WMShelf.h"

@class FileViewer;

@interface Finder : NSObject
{
  FileViewer *fileViewer;
  
  WMShelf	*shelf;
  id		window;
  NSImage       *findButtonImage;
  id		findButton;
  id		findField;
  id		findScopeButton;
  id		statusField;
  id		resultList;
  id		resultsFound;
  id		resultIcon;
  id		iconPlace;

  NSOperationQueue *operationQ;
  NSMutableArray   *variantList;
  NSInteger        resultIndex;

  // Shelf
  NSSet *savedSelection;
}

- (id)initWithFileViewer:(FileViewer *)fv;
- (void)setFileViewer:(FileViewer *)fv;
  
- (void)activateWithString:(NSString *)searchString;
- (void)deactivate;
- (NSWindow *)window;

- (void)addResult:(NSString *)resultString;
- (void)finishFind;

@end

@interface Finder (Worker)
- (void)runWorkerWithPaths:(NSArray *)searchPaths
                expression:(NSRegularExpression *)regexp;
@end

@interface Finder (Shelf)
- (void)restoreShelf;
- (NSArray *)storableShelfSelection;
- (void)reconstructShelfSelection:(NSArray *)selectedSlots;
- (void)resignShelfSelection;
- (void)restoreShelfSelection;
@end
