/* All Rights reserved */

#include <AppKit/AppKit.h>
#import <NXAppKit/NXIconView.h>

#import "Workspace+WindowMaker.h"

@interface RecyclerIconView : NSView
- (void)setImage:(NSImage *)anImage;
@end

@interface RecyclerIcon : NSWindow
{
}

+ (WAppIcon *)createAppIconForDock:(WDock *)dock;
+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock;
  
// - initWithDock:(WDock *)dock;
// - (WAppIcon *)dockIcon;
// - (NSImage *)iconImage;
// - (void)updateIconImage;

@end

@interface Recycler : NSObject
{
  RecyclerIcon     *appIcon;
  RecyclerIconView *appIconView;

  WAppIcon         *dockIcon;
  NSImage          *iconImage;
  NSString         *recyclerPath;

  // Panel
  NSPanel      *panel;
  NSImageView  *panelIcon;
  NSScrollView *panelView;
  NXIconView   *filesView;
}

- initWithDock:(WDock *)dock;
- (WAppIcon *)dockIcon;
- (RecyclerIcon *)appIcon;

- (void)mouseDown:(NSEvent*)theEvent;

@end
