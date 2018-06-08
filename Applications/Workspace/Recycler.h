/* All Rights reserved */

#include <AppKit/AppKit.h>

#import <NXAppKit/NXIconView.h>
#import <NXAppKit/NXIconBadge.h>
#import <NXSystem/NXFileSystemMonitor.h>

#import <Viewers/PathIcon.h>

#import "RecyclerIcon.h"
#import "Workspace+WindowMaker.h"

@interface ItemsLoader : NSOperation
{
  NXIconView  *iconView;
  NSTextField *statusField;
  NSString    *directoryPath;
  NSArray     *selectedFiles;
}

@property (atomic, readonly) NSInteger itemsCount;

- (id)initWithIconView:(NXIconView *)view
                status:(NSTextField *)status
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames;

@end

@interface Recycler : NSObject
{
  RecyclerIconView	*appIconView;
  NXIconBadge		*badge;

  NSImage		*iconImage;
  NSString		*recyclerDBPath;
  
  NXFileSystemMonitor	*fileSystemMonitor;

  // Panel
  NSPanel		*panel;
  NSImageView		*panelIcon;
  NSTextField		*panelItems;
  NSScrollView		*panelView;
  NXIconView		*filesView;

  // Items loader
  NSOperationQueue	*operationQ;
  ItemsLoader		*itemsLoader;
  
  // Dragging
  id			draggedSource;
  PathIcon		*draggedIcon;
  NSDragOperation	draggingSourceMask;
}

@property (atomic, readonly) WAppIcon *dockIcon;
@property (atomic, readonly) RecyclerIcon *appIcon;
@property (atomic, readonly) NSString *path;
@property (atomic, readonly) NSInteger itemsCount;

- (id)initWithDock:(WDock *)dock;

- (void)setIconImage:(NSImage *)image;
- (void)updateIconImage;
- (void)updatePanel;

- (void)purge;

@end
