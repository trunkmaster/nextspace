/* All Rights reserved */

#include <AppKit/AppKit.h>
#import <DesktopKit/NXTIconView.h>

// Using NSOperation https://developer.apple.com/library/archive/technotes/tn2109/_index.html
@interface PathLoader : NSOperation
{
  NXTIconView  *iconView;
  NSTextField *statusField;
  NSString    *directoryPath;
  NSArray     *selectedFiles;
}

@property (atomic, assign, readonly) NSInteger itemsCount;

- (id)initWithIconView:(NXTIconView *)view
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
  NXTIconView   *filesView;

  NSOperationQueue *opQ;
  PathLoader       *pathLoaderOp;
}

- (void)show;

- (NSUInteger)itemsCount;

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames;

@end

