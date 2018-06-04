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
}

- (void)show;

- (NSUInteger)itemsCount;

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames;

@end
