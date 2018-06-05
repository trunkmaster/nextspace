/* All Rights reserved */

#include <AppKit/AppKit.h>
#import <NXAppKit/NXIconView.h>

@interface IconViewTest : NSObject
{
  NSImage          *iconImage;
  NSString         *recyclerPath;
  NSUInteger       itemsCount;
  
  // Panel
  NSPanel      *panel;
  NSImageView  *panelIcon;
  NSTextField  *panelItemsCount;
  NSScrollView *panelView;
  NXIconView   *filesView;

  NSOperationQueue *opQ;
  NSOperation      *pathLoaderOp;
}

- (void)show;

- (NSUInteger)itemsCount;

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames;

@end

// Using NSOperation https://developer.apple.com/library/archive/technotes/tn2109/_index.html
@interface PathLoader : NSOperation
{
  NXIconView *iconView;
  NSString   *directoryPath;
  NSArray    *selectedFiles;
}

@property (atomic, assign, readwrite) NSInteger itemsCount;

- (id)initWithIconView:(NXIconView *)view
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames;

@end
