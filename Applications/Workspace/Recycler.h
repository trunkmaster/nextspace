/* All Rights reserved */

#include <AppKit/AppKit.h>

#import <NXAppKit/NXIconView.h>
#import <NXAppKit/NXIconBadge.h>
#import <NXSystem/NXFileSystemMonitor.h>

#import "Workspace+WindowMaker.h"

@interface RecyclerIconView : NSView
{
  NSTimer *timer;
}
- (void)setImage:(NSImage *)anImage;
@end

@interface RecyclerIcon : NSWindow
{
}

+ (WAppIcon *)createAppIconForDock:(WDock *)dock;
+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock;
  
@end

@interface ItemsLoader : NSOperation
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

@interface Recycler : NSObject
{
  RecyclerIcon     *appIcon;
  RecyclerIconView *appIconView;
  NXIconBadge      *badge;

  WAppIcon         *dockIcon;
  NSImage          *iconImage;
  NSString         *recyclerPath;
  NSString         *recyclerDBPath;
  NSUInteger       itemsCount;
  
  NXFileSystemMonitor *fileSystemMonitor;

  // Panel
  NSPanel      *panel;
  NSImageView  *panelIcon;
  NSTextField  *panelItems;
  NSScrollView *panelView;
  NXIconView   *filesView;

  // Items loader
  NSOperationQueue *operationQ;
  ItemsLoader      *itemsLoader;
}

- initWithDock:(WDock *)dock;
- (WAppIcon *)dockIcon;
- (RecyclerIcon *)appIcon;
- (NSUInteger)itemsCount;
- (NSString *)path;

- (void)setIconImage:(NSImage *)image;
- (void)updateIconImage;

- (void)purge;

@end
