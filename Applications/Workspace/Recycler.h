/* All Rights reserved */

#include <AppKit/AppKit.h>
#import "Workspace+WindowMaker.h"

@interface RecyclerView : NSView
- (void)setImage:(NSImage *)anImage;
@end

@interface RecyclerIcon : NSWindow
{
  WAppIcon     *dockIcon;
  RecyclerView *view;
}

+ (WAppIcon *)createAppIconForDock:(WDock *)dock;
+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock;
  
- initWithDock:(WDock *)dock;
- (WAppIcon *)dockIcon;

@end
