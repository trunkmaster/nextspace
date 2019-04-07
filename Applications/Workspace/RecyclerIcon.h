/* All Rights reserved */

#include <AppKit/AppKit.h>

#import "Workspace+WM.h"

@interface RecyclerIconView : NSView
{
  NSTimer      *timer;
  unsigned int draggingMask;
}
- (void)setImage:(NSImage *)anImage;
@end

@class Recycler;

@interface RecyclerIcon : NSWindow

+ (WAppIcon *)createAppIconForDock:(WDock *)dock;
+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock;

- (id)initWithWindowRef:(void *)X11Window recycler:(Recycler *)theRecycler;

@end
