/* All Rights reserved */

#include <AppKit/AppKit.h>
#import <NXAppKit/NXIconView.h>

// Using NSOperation https://developer.apple.com/library/archive/technotes/tn2109/_index.html
@interface PathLoader : NSOperation
{
  NXIconView  *iconView;
  NSTextField *statusField;
  NSString    *directoryPath;
  NSArray     *selectedFiles;
}

@property (atomic, assign, readonly) NSInteger itemsCount;

- (id)initWithIconView:(NXIconView *)view
                status:(NSTextField *)status
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames;

@end

@interface IconViewTest : NSObject
{
  NSImage          *iconImage;
  NSString         *recyclerPath;
  NSUInteger       itemsCount;
  
  // Panel
  NSPanel      *panel;
  NSImageView  *panelIcon;
  NSTextField  *panelItemsCount;
  NSTextField  *panelStatusField;
  NSScrollView *panelView;
  NXIconView   *filesView;

  NSOperationQueue *opQ;
  PathLoader       *pathLoaderOp;
}

- (void)show;

- (NSUInteger)itemsCount;

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames;

@end

