/* All Rights reserved */

#import <NXAppKit/NXAlert.h>
#import <Operations/ProcessManager.h>

#import <NXAppKit/NXIcon.h>
#import <NXAppKit/NXIconLabel.h>
#import <NXFoundation/NXFileManager.h>
#import <NXFoundation/NXDefaults.h>

#import "Controller.h"
#import "RecyclerIcon.h"
#import "Recycler.h"

@implementation ItemsLoader

static NSMutableArray *fileList = nil;

- (id)initWithIconView:(NXIconView *)view
                status:(NSTextField *)status
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames
{
  if (self != nil)
    {
      iconView = view;
      statusField = status;
      directoryPath = dirPath;
      selectedFiles = filenames;
    }

  return self;
}

- (NXIcon *)_iconForLabel:(NSString *)label inView:(NXIconView *)view
{
  for (NXIcon *icon in [view icons]) {
    if ([label isEqualToString:[[icon label] text]]) {
      return icon;
    }
  }

  return nil;
}
- (void)_optimizeItems:(NSMutableArray *)items
              fileView:(NXIconView *)view
{
  NXIcon         *icon;
  NSMutableArray *itemsCopy = [items mutableCopy];
  NSArray        *iconsCopy = [[view icons] copy];

  // Remove non-existing items
  for (NXIcon *icon in iconsCopy) {
    if ([items indexOfObject:[[icon label] text]] == NSNotFound) {
      [view removeIcon:icon];
    }
  }

  // Leave in `items` array items to add.
  for (NSString *filename in itemsCopy) {
    icon = [self _iconForLabel:filename inView:view];
    if (icon) {
      [items removeObject:filename];
    }
  }
  [itemsCopy release];
  
  // [view performSelectorOnMainThread:@selector(adjustToFitIcons)
  //                        withObject:nil
  //                     waitUntilDone:YES];
}

- (void)main
{
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSMutableArray	*items;
  NSString		*path;
  PathIcon		*anIcon;
  NSUInteger		slotsWide, x;
  NSInteger             dbFileIndex;

  NSLog(@"Operation: Begin path loading...");
  
  items = [[xfm directoryContentsAtPath:directoryPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES] mutableCopy];

  _itemsCount = [items count];
  
  dbFileIndex = [items indexOfObject:@".recycler.db"];
  if (dbFileIndex != NSNotFound) {
    [items removeObjectAtIndex:dbFileIndex];
    _itemsCount--;
  }
  
  x = 0;
  slotsWide = [iconView slotsWide];
  [self _optimizeItems:items fileView:iconView];
  for (NSString *filename in items) {
    path = [directoryPath stringByAppendingPathComponent:filename];

    anIcon = [[PathIcon new] autorelease];
    [anIcon setLabelString:filename];
    [anIcon setIconImage:[[NSApp delegate] iconForFile:path]];
    [anIcon setPaths:[NSArray arrayWithObject:path]];
    [anIcon registerForDraggedTypes:@[NSFilenamesPboardType]];

    if ([selectedFiles containsObject:filename]) {
      [selected addObject:anIcon];
    }

    [iconView performSelectorOnMainThread:@selector(addIcon:)
                               withObject:anIcon
                            waitUntilDone:YES];
    x++;
    if (x >= slotsWide) {
      [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
                                 withObject:nil
                              waitUntilDone:YES];
      x = 0;
    }
  }

  if ([selected count] != 0) {
    [iconView selectIcons:selected];
  }
  else {
    [iconView scrollPoint:NSZeroPoint];
  }

  NSLog(@"Operation: End path loading...");
  [statusField performSelectorOnMainThread:@selector(setStringValue:)
                                withObject:@""
                             waitUntilDone:YES];
}

- (BOOL)isReady
{
  return YES;
}

@end

@implementation Recycler

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [fileSystemMonitor removePath:_path];
  
  [_appIcon release];
  [recyclerDBPath release];
  [_path release];

  [operationQ release];
  if (itemsLoader) {
    [itemsLoader removeObserver:self forKeyPath:@"isFinished"];
    [itemsLoader cancel];
    [itemsLoader release];
  }
  
  [super dealloc];
}

- (id)initWithDock:(WDock *)dock
{
  XClassHint    classhint;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL          isDir;

  self = [super init];
  
  _dockIcon = [RecyclerIcon recyclerAppIconForDock:dock];
 
  if (_dockIcon == NULL) {
    NSLog(@"Recycler Dock icon creation failed!");
    return nil;
  }

  // _dockIcon->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;

  classhint.res_name = "Recycler";
  classhint.res_class = "GNUstep";
  XSetClassHint(dpy, _dockIcon->icon->core->window, &classhint);
  
  _path = [NSHomeDirectory() stringByAppendingPathComponent:@".Recycler"];
  [_path retain];
  recyclerDBPath = [_path stringByAppendingPathComponent:@".recycler.db"];
  [recyclerDBPath retain];
  
  if ([fileManager fileExistsAtPath:_path isDirectory:&isDir] == NO) {
    if ([fileManager createDirectoryAtPath:_path attributes:nil] == NO) {
      NXRunAlertPanel(_(@"Workspace"),
                      _(@"Your Recycler storage doesn't exist and cannot"
                        " be created at path: %@."),
                      _(@"Dismiss"), nil, nil, _path);
      // THINK: is it possible to not be able to create directory in $HOME?
    }
    // TODO: validate contents of exixsting directory: Was it created by Workspace?
  }
  else if (isDir == NO) {
    NXRunAlertPanel(_(@"Workspace"),
                    _(@"Your Recycler storage is not directory.\n"
                      "Do you want to disable or recover Recycler?.\n"
                      "'Recover' operation destroys existing file '.Recycler'"
                      " in your home directory."),
                    _(@"Disable"), _(@"Recover"), nil);
    // TODO: on disable Recycler icon should be removed from screen.
  }

  _appIcon = [[RecyclerIcon alloc]
               initWithWindowRef:&_dockIcon->icon->core->window
                        recycler:self];
  
  appIconView = [[RecyclerIconView alloc] initWithFrame:NSMakeRect(0,0,64,64)];
  [_appIcon setContentView:appIconView];
  [appIconView release];

  // Badge on appicon with number of items inside
  badge = [[NXIconBadge alloc] initWithPoint:NSMakePoint(2,51)
                                        text:@"0"
                                        font:[NSFont systemFontOfSize:9]
                                   textColor:[NSColor blackColor]
                                 shadowColor:[NSColor whiteColor]];
  [appIconView addSubview:badge];
  [badge release];

  [self updateIconImage];
  
  fileSystemMonitor = [[NSApp delegate] fileSystemMonitor];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(fileSystemChangedAtPath:)
           name:NXFileSystemChangedAtPath
         object:nil];
  [fileSystemMonitor addPath:_path];

  return self;
}

- (void)awakeFromNib
{
  NSSize iconSize;
  
  [panel setFrameAutosaveName:@"Recycler"];
  
  [panelView setHasHorizontalScroller:NO];
  [panelView setHasVerticalScroller:YES];

  filesView = [[NXIconView alloc] initWithFrame:[[panelView contentView] frame]];
  [filesView setDelegate:self];
  [filesView setTarget:self];
  [filesView setDragAction:@selector(filesView:iconDragged:withEvent:)];
  // [filesView setDoubleAction:@selector(open:)];
  // [filesView setSendsDoubleActionOnReturn:YES];
  iconSize = [NXIconView defaultSlotSize];
  if ([[NXDefaults userDefaults] objectForKey:@"IconSlotWidth"])
    {
      iconSize.width = [[NXDefaults userDefaults] floatForKey:@"IconSlotWidth"]; 
      [filesView setSlotSize:iconSize];
   }
  
  [filesView registerForDraggedTypes:@[NSFilenamesPboardType]];

  [panelView setDocumentView:filesView];
  [filesView setFrame:NSMakeRect(0, 0,
                                 [[panelView contentView] frame].size.width, 0)];
  [filesView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];

  [panelIcon setImage:[self iconImage]];

  operationQ = [[NSOperationQueue alloc] init];
  itemsLoader = nil;

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(iconWidthDidChange:)
           name:@"IconSlotWidthDidChangeNotification"
         object:nil];
}

- (NSImage *)iconImage
{
  return iconImage;
}

- (void)setIconImage:(NSImage *)image
{
  [appIconView setImage:image];
}

- (void)updateIconImage
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  _itemsCount = [[fm directoryContentsAtPath:_path] count];

  if ([fm fileExistsAtPath:[_path stringByAppendingPathComponent:@".recycler.db"]])
    _itemsCount--;
    
  if (_itemsCount)
    {
      iconImage = [NSImage imageNamed:@"recyclerFull"];
      [badge setStringValue:[NSString stringWithFormat:@"%lu", _itemsCount]];
    }
  else
    {
      iconImage = [NSImage imageNamed:@"recycler"];
      [badge setStringValue:@""];
    }
  
  [appIconView setImage:iconImage];  
}

- (void)updatePanel
{
  NSString *iconLabel;
  
  if (!panel)
    return;

  // Panel icon image
  [panelIcon setImage:[self iconImage]];
  if (_itemsCount != 1)
    iconLabel = [NSString stringWithFormat:@"%lu items", _itemsCount];
  else
    iconLabel = @"1 item";
  [panelItems setStringValue:iconLabel];
  
  // [filesView removeAllIcons];

  if (itemsLoader != nil) {
    [itemsLoader cancel];
    [itemsLoader release];
  }

  [panelItems setStringValue:@"Busy..."];

  [filesView setAutoAdjustsToFitIcons:NO];
  
  itemsLoader = [[ItemsLoader alloc] initWithIconView:filesView
                                               status:nil
                                                 path:_path
                                            selection:nil];
  [itemsLoader addObserver:self
                forKeyPath:@"isFinished"
                   options:0
                   context:&self->_itemsCount];
  [operationQ addOperation:itemsLoader];
}

- (void)showPanel
{
  if (panel == nil)
    {
      if (![NSBundle loadNibNamed:@"Recycler" owner:self])
        {
          NSLog(@"Error loading Recycler.gorm!");
        }
    }

  [self updateIconImage];
  [self updatePanel];
  
  [panel makeKeyAndOrderFront:self];
}

- (void)mouseDown:(NSEvent*)theEvent
{
  // NSLog(@"Recycler: mouse down!");

  if ([theEvent clickCount] >= 2)
    {
      [self showPanel];
    }
}

- (void)purge
{
  NSFileManager 	*fm = [NSFileManager defaultManager];
  NSMutableArray	*items = [[fm directoryContentsAtPath:_path] mutableCopy];
  NSMutableDictionary	*db = nil;

  // Database
  if ([fm fileExistsAtPath:recyclerDBPath])
    db = [[NSMutableDictionary alloc] initWithContentsOfFile:recyclerDBPath];

  // Remove .recycler.db from itmes list
  for (NSString *itemPath in items)
    {
      if ([itemPath isEqualToString:[recyclerDBPath lastPathComponent]])
        {
          [items removeObjectAtIndex:[items indexOfObject:itemPath]];
          break;
        }
    }
  
  if (![[ProcessManager shared] startOperationWithType:DeleteOperation
                                                source:_path
                                                target:nil
                                                 files:items]) {
    return;
  }
  
  if (itemsLoader) {
    [itemsLoader cancel];
  }

  if (filesView) {
    [filesView removeAllIcons];
  }

  if (db) {
    for (NSString *item in items) {
      [db removeObjectForKey:item];
    }
    [db writeToFile:recyclerDBPath atomically:YES];
    [db release];
  }
  [items release];
  
  [self updateIconImage];
}

// -- NSOperation
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  NSLog(@"Observer of '%@' was called.", keyPath);
  [panelItems setStringValue:[NSString stringWithFormat:@"%lu items",
                                       itemsLoader.itemsCount]];
  for (NXIcon *icon in [filesView icons]) {
    [icon setDelegate:self];
    [icon setTarget:self];
    [icon setDragAction:@selector(iconDragged:withEvent:)];
  }

  [filesView setAutoAdjustsToFitIcons:YES];
}

// IconView actions
- (void)iconDragged:(PathIcon *)theIcon
          withEvent:(NSEvent *)theEvent
{
  NSRect       iconFrame = [theIcon frame];
  NSPoint      iconLocation = iconFrame.origin;
  NSPasteboard *pasteBoard = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSDictionary *iconInfo;
  
  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  draggedSource = self;
  draggedIcon = theIcon;
  draggingSourceMask = NSDragOperationMove;

  [draggedIcon setSelected:NO];
  [draggedIcon setDimmed:YES];
  
  // Pasteboard info for 'draggedIcon'
  [pasteBoard declareTypes:@[NSFilenamesPboardType, NSGeneralPboardType]
                     owner:nil];
  [pasteBoard setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];
  if ((iconInfo = [draggedIcon info]) != nil) {
    [pasteBoard setPropertyList:iconInfo forType:NSGeneralPboardType];
  }

  [filesView dragImage:[draggedIcon iconImage]
                    at:iconLocation
                offset:NSZeroSize
                 event:theEvent
            pasteboard:pasteBoard
                source:draggedSource
             slideBack:YES];
}

// NSDraggingSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSLog(@"[Recycler] draggingSourceOperationMaskForLocal:");
  return draggingSourceMask;
}
- (BOOL)ignoreModifierKeysWhileDragging
{
  return YES;
}
- (void)draggedImage:(NSImage*)image
             endedAt:(NSPoint)screenPoint
           deposited:(BOOL)didDeposit
{
  NSLog(@"draggedImage:endedAt:operation:");
  if (didDeposit == NO) {
    [draggedIcon setSelected:YES];
    [draggedIcon setDimmed:NO];
  }
}

// NXIcon delegate methods (NSDraggingDestination)
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingEntered:icon:");
  return draggingSourceMask;
}
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingUpdated:icon:");
  return draggingSourceMask;
}
- (void)draggingExited:(id <NSDraggingInfo>)sender
                  icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingOperationExited:icon:");
}

// -- Notifications
- (void)iconWidthDidChange:(NSNotification *)notification
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     slotSize = [filesView slotSize];

  slotSize.width = [df floatForKey:@"IconSlotWidth"];
  [filesView setSlotSize:slotSize];
}

- (void)fileSystemChangedAtPath:(NSNotification *)notif
{
  NSDictionary *changes = [notif userInfo];
  NSString     *changedPath = [changes objectForKey:@"ChangedPath"];

  if ([changedPath isEqualToString:_path]) {
    [self updateIconImage];
    [self updatePanel];
  }
}

@end
