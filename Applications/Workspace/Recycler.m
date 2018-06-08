/* All Rights reserved */

#import <GNUstepGUI/GSDisplayServer.h>
#import <NXAppKit/NXAlert.h>
#import <Operations/ProcessManager.h>

#import <NXAppKit/NXIcon.h>
#import <NXAppKit/NXIconLabel.h>
#import <NXFoundation/NXFileManager.h>
#import <NXFoundation/NXDefaults.h>

#import "Controller.h"
#import "Recycler.h"

static Recycler *recycler = nil;

// WindowMaker's callback funtion on mouse click.
// LMB click goes to dock app core window.
// RMB click goes to root window (handles by event.c in WindowMaker).
void _recyclerMouseDown(WObjDescriptor *desc, XEvent *event)
{
  fprintf(stderr, "Recycler: mouse down (window: %lu (%lu) subwindow: %lu)!\n",
          event->xbutton.window, event->xbutton.root, event->xbutton.subwindow);
  NSEvent   *theEvent;
  WAppIcon  *aicon = desc->parent;
  NSInteger clickCount = 1;
      
  XUngrabPointer(dpy, CurrentTime);
  
  if (event->xbutton.button == Button1)
    {
      if (IsDoubleClick(aicon->icon->owner->screen_ptr, event))
        clickCount = 2;

      // Handle move of icon
      if (aicon->dock)
        wHandleAppIconMove(aicon, event);
  
      theEvent =
        [NSEvent mouseEventWithType:NSLeftMouseDown
                           location:NSMakePoint(event->xbutton.x, event->xbutton.y)
                      modifierFlags:0
                          timestamp:(NSTimeInterval)event->xbutton.time / 1000.0
                       windowNumber:[[recycler appIcon] windowNumber]
                            context:[[recycler appIcon] graphicsContext]
                        eventNumber:event->xbutton.serial
                         clickCount:clickCount
                           pressure:1.0];

      [recycler performSelectorOnMainThread:@selector(mouseDown:)
                                 withObject:theEvent
                              waitUntilDone:NO];
      
    }
  else if (event->xbutton.button == Button3)
    {
      // This will bring menu of active application on screen at mouse pointer
      event->xbutton.window = event->xbutton.root;
      XSendEvent(dpy, event->xbutton.root, False, ButtonPressMask, event);
    }
}

@implementation	RecyclerIcon

+ (int)positionInDock:(WDock *)dock
{
  WAppIcon *btn;
  int      rec_pos, new_max_icons;
 
  new_max_icons = dock->screen_ptr->scr_height / wPreferences.icon_size;
  
 // Search for position in Dock for new Recycler
  for (rec_pos = new_max_icons-1; rec_pos > 0; rec_pos--)
    {
      if ((btn = dock->icon_array[rec_pos]) == NULL)
        break;
    }

  return rec_pos;
}

+ (WAppIcon *)createAppIconForDock:(WDock *)dock
{
  WAppIcon *btn;
  int      rec_pos = [RecyclerIcon positionInDock:dock];
 
  btn = wAppIconCreateForDock(dock->screen_ptr, "", "Recycler", "GNUstep",
                              TILE_NORMAL);
  btn->yindex = rec_pos;

  return btn;
}

+ (void)rebuildDock:(WDock *)dock
{
  int new_max_icons = dock->screen_ptr->scr_height / wPreferences.icon_size;
  WAppIcon **new_icon_array = wmalloc(sizeof(WAppIcon *) * new_max_icons);

  dock->icon_count = 0;
  for (int i=0; i < new_max_icons; i++)
    {
      // NSLog(@"%i", i);
      if (dock->icon_array[i] == NULL || i >= dock->max_icons)
        {
          new_icon_array[i] = NULL;
        }
      else 
        {
          new_icon_array[i] = dock->icon_array[i];
          dock->icon_count++;
        }
    }
  wfree(dock->icon_array);
  dock->icon_array = new_icon_array;
  dock->max_icons = new_max_icons;
}

+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock
{
  WScreen  *scr = dock->screen_ptr;
  WAppIcon *btn, *rec_btn = NULL;
  int      new_yindex = 0, new_max_icons;
 
  btn = scr->app_icon_list;
  while (btn->next)
    {
      if (!strcmp(btn->wm_instance, "Recycler"))
        {
          rec_btn = btn;
          break;
        }
      btn = btn->next;
    }

  if (!rec_btn)
    {
      rec_btn = wAppIconCreateForDock(dock->screen_ptr, "-", "Recycler",
                                      "GNUstep", TILE_NORMAL);
    }
  
  new_yindex = [RecyclerIcon positionInDock:dock];
  new_max_icons = dock->screen_ptr->scr_height / wPreferences.icon_size;

  if (rec_btn->docked &&
      (rec_btn->yindex > new_max_icons-1 && new_yindex == 0))
    {
      NSLog(@"Recycler: detach");
      wDockDetach(dock, rec_btn);
    }
  else if (rec_btn->docked)
    {
      [RecyclerIcon rebuildDock:dock];
      new_yindex = [RecyclerIcon positionInDock:dock];
      if (rec_btn->yindex != new_yindex && new_yindex > 0)
        {
          NSLog(@"Recycler: reattach");
          wDockReattachIcon(dock, rec_btn, 0, new_yindex);
        }
    }
  else if (!rec_btn->docked && new_yindex > 0)
    {
      [RecyclerIcon rebuildDock:dock];
      new_yindex = [RecyclerIcon positionInDock:dock];
      if (new_yindex > 0)
        {
          NSLog(@"Recycler: attach");
          wDockAttachIcon(dock, rec_btn, 0, new_yindex, NO);
        }
    }
  
  rec_btn->running = 1;
  rec_btn->launching = 0;
  rec_btn->lock = 1;
  rec_btn->command = wstrdup("-");
  rec_btn->dnd_command = NULL;
  rec_btn->paste_command = NULL;
  rec_btn->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;
  
  return rec_btn;
}

- (BOOL)canBecomeMainWindow
{
  return NO;
}

- (BOOL)canBecomeKeyWindow
{
  return NO;
}

- (BOOL)worksWhenModal
{
  return YES;
}

- (void)orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWin
{
  [super orderWindow:place relativeTo:otherWin];
}

- (void)_initDefaults
{
  [super _initDefaults];
  
  [self setTitle:@"Recycler"];
  [self setExcludedFromWindowsMenu:YES];
  [self setReleasedWhenClosed:NO];
  
  if ([[NSUserDefaults standardUserDefaults] 
        boolForKey: @"GSAllowWindowsOverIcons"] == YES)
    _windowLevel = NSDockWindowLevel;
}

@end

@implementation RecyclerIconView

// Class variables
static NSCell *dragCell = nil;
static NSCell *tileCell = nil;

+ (void)initialize
{
  NSImage *tileImage;
  NSSize  iconSize = NSMakeSize(64,64);

  dragCell = [[NSCell alloc] initImageCell:nil];
  [dragCell setBordered:NO];
  
  tileImage = [[GSCurrentServer() iconTileImage] copy];
  [tileImage setScalesWhenResized:NO];
  [tileImage setSize:iconSize];
  tileCell = [[NSCell alloc] initImageCell:tileImage];
  RELEASE(tileImage);
  [tileCell setBordered:NO];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self registerForDraggedTypes:[NSArray arrayWithObjects:
                                           NSFilenamesPboardType, nil]];
  return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent
{
  return YES;
}

- (void)setImage:(NSImage *)anImage
{
  [dragCell setImage:anImage];
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize = NSMakeSize(64,64);
  
  // NSLog(@"Recycler View: drawRect!");
  
  [tileCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
  		   inView:self];
  [dragCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
        	   inView:self];
}

// --- Drag and Drop

static int imageNumber;
static NSDate *date = nil;
static NSTimeInterval tInterval = 0;

- (void)animate
{
  NSString *imageName;

  if (([NSDate timeIntervalSinceReferenceDate] - tInterval) < 0.1)
    return;

  tInterval = [NSDate timeIntervalSinceReferenceDate];
  
  if (++imageNumber > 4) imageNumber = 1;

  imageName = [NSString stringWithFormat:@"recycler-%i", imageNumber];
  
  [self setImage:[NSImage imageNamed:imageName]];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  // NSLog(@"Recycler: dragging entered!");
  tInterval = [NSDate timeIntervalSinceReferenceDate];
  return NSDragOperationDelete;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
  // NSLog(@"Recycler: dragging exited!");
  [recycler updateIconImage];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
  [self animate];
  return NSDragOperationDelete;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  NSLog(@"Recycler: prepare fo dragging");
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  BOOL			result = NO;
  NSPasteboard		*dragPb = [sender draggingPasteboard];
  NSArray		*types = [dragPb types];
  NSString		*dbPath;
  NSMutableDictionary	*db;
  NSFileManager		*fm = [NSFileManager defaultManager];
  NSMutableArray 	*items;
  NSString		*sourceDir;
    
  dbPath = [recycler.path stringByAppendingPathComponent:@".recycler.db"];
  if ([fm fileExistsAtPath:dbPath])
    db = [[NSMutableDictionary alloc] initWithContentsOfFile:dbPath];
  else
    db = [NSMutableDictionary new];
  
  NSLog(@"Recycler: perform dragging");
  
  [recycler setIconImage:[NSImage imageNamed:@"recyclerDeposit"]];
  
  if ([types containsObject:NSFilenamesPboardType] == YES)
    {
      NSString *name, *path;
      
      items = [[dragPb propertyListForType:NSFilenamesPboardType] mutableCopy];
      sourceDir = [[items objectAtIndex:0] stringByDeletingLastPathComponent];

      for (NSUInteger i = 0; i < [items count]; i++)
        {
          path = [items objectAtIndex:i];
          name = [path lastPathComponent];
          [db setObject:[path stringByDeletingLastPathComponent] forKey:name];
          [items replaceObjectAtIndex:i withObject:name];
        }

      [[ProcessManager shared] startOperationWithType:MoveOperation
                                               source:sourceDir
                                               target:[recycler path]
                                                files:items];
      [items release];
      [db writeToFile:dbPath atomically:YES];
      result = YES;
    }

  [db release];
  [recycler updateIconImage];
  
  return result;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
  NSLog(@"Recycler: conclude dragging");
}

@end

@implementation ItemsLoader

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

- (void)main
{
  NSString 		*filename;
  NSMutableArray	*icons = [NSMutableArray array];
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSMutableArray	*items;
  NSString		*path;
  NXIcon		*anIcon;
  NSUInteger		slotsWide, x;
  NSInteger             ind;

  [statusField performSelectorOnMainThread:@selector(setStringValue:)
                                withObject:@"Loading items list..."
                             waitUntilDone:YES];
  NSLog(@"Operation: Begin path loading...");
  
  items = [[xfm directoryContentsAtPath:directoryPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES] mutableCopy];

  _itemsCount = [items count];
  
  ind = [items indexOfObject:@".recycler.db"];
  if (ind != NSNotFound) {
    [items removeObjectAtIndex:ind];
    _itemsCount--;
  }
  
  x = 0;
  slotsWide = [iconView slotsWide];
  for (filename in items)
    {
      path = [directoryPath stringByAppendingPathComponent:filename];

      anIcon = [[NXIcon new] autorelease];
      [anIcon setLabelString:filename];
      [anIcon setIconImage:[[NSApp delegate] iconForFile:path]];
      // [[anIcon label] setIconLabelDelegate:recycler];
      [anIcon setDelegate:recycler];
      [anIcon
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

      // if (![fm isReadableFileAtPath:path])
      //   [anIcon setDimmed:YES];
      
      if ([selectedFiles containsObject:filename])
        [selected addObject:anIcon];

      // [icons addObject:anIcon];      
      [iconView performSelectorOnMainThread:@selector(addIcon:)
                                 withObject:anIcon
                              waitUntilDone:YES];
      x++;
      if (x >= slotsWide)
        {
          [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
                                     withObject:nil
                                  waitUntilDone:YES];
          x = 0;
        }
    }

  // NSLog(@"Recycler: fill with %lu icons", [icons count]);
  // [filesView fillWithIcons:icons];
  
  if ([selected count] != 0)
    [iconView selectIcons:selected];
  else
    [iconView scrollPoint:NSZeroPoint];

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

- (id)initWithDock:(WDock *)dock
{
  XClassHint classhint;
  BOOL       isDir;

  recycler = self = [super init];
  
  _dockIcon = [RecyclerIcon recyclerAppIconForDock:dock];
 
  if (_dockIcon == NULL)
    {
      NSLog(@"Recycler Dock icon creation failed!");
      return nil;
    }

  _dockIcon->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;

  classhint.res_name = "Recycler";
  classhint.res_class = "GNUstep";
  XSetClassHint(dpy, _dockIcon->icon->core->window, &classhint);
  
  _appIcon = [[RecyclerIcon alloc] initWithWindowRef:&_dockIcon->icon->core->window];
  
  _path = [NSHomeDirectory() stringByAppendingPathComponent:@".Recycler"];
  [_path retain];
  recyclerDBPath = [_path stringByAppendingPathComponent:@".recycler.db"];
  [recyclerDBPath retain];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:_path
                                           isDirectory:&isDir] == NO)
    {
      if ([[NSFileManager defaultManager] createDirectoryAtPath:_path
                                                     attributes:nil] == NO)
        {
          NXRunAlertPanel(_(@"Workspace"),
                          _(@"Your Recycler storage doesn't exist and cannot"
                            " be created at path: %@."),
                          _(@"Dismiss"), nil, nil, _path);
          // THINK: is it possible to not be able to create directory in $HOME?
        }
      // TODO: validate contents of exixsting directory: Was it created by Workspace?
    }
  else if (isDir == NO)
    {
      NXRunAlertPanel(_(@"Workspace"),
                      _(@"Your Recycler storage is not directory.\n"
                        "Do you want to disable or recover Recycler?.\n"
                        "'Recover' operation destroys existing file '.Recycler'"
                        " in your home directory."),
                      _(@"Disable"), _(@"Recover"), nil);
      // TODO: on disable Recycler icon should be removed from screen.
    }

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
  [filesView setDragAction:@selector(iconDragged:event:)];
  // [filesView setDoubleAction:@selector(open:)];
  // [filesView setSendsDoubleActionOnReturn:YES];
  iconSize = [NXIconView defaultSlotSize];
  if ([[NXDefaults userDefaults] objectForKey:@"IconSlotWidth"])
    {
      iconSize.width = [[NXDefaults userDefaults] floatForKey:@"IconSlotWidth"]; 
      [filesView setSlotSize:iconSize];
   }
  
  [filesView
    registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

  [panelView setDocumentView:filesView];
  [filesView setFrame:NSMakeRect(0, 0,
                                 [[panelView contentView] frame].size.width, 0)];
  [filesView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

  [panelIcon setImage:[self iconImage]];

  operationQ = [[NSOperationQueue alloc] init];
  itemsLoader = nil;

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(iconWidthDidChange:)
           name:@"IconSlotWidthDidChangeNotification"
         object:nil];
}

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
  
  [filesView removeAllIcons];

  if (itemsLoader != nil) {
    [itemsLoader cancel];
    [itemsLoader release];
  }

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
                                                 files:items])
    {
      return;
    }
  
  if (itemsLoader)
    [itemsLoader cancel];

  if (filesView)
    [filesView removeAllIcons];

  if (db)
    {
      for (NSString *item in items)
        {
          [db removeObjectForKey:item];
        }
      [db writeToFile:recyclerDBPath atomically:YES];
      [db release];
    }
  [items release];
  
  [recycler updateIconImage];
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
    [icon setTarget:self];
    [icon setDragAction:@selector(iconsDraggedInFilesView:withEvent:)];
  }
}

// IconView actions
- (void)iconsDraggedInFilesView:(id)sender withEvent:(NSEvent *)event
{
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSArray      *pbTypes = nil;
  
  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  draggedSource = filesView;
  draggedIcon = sender;
  draggingSourceMask = NSDragOperationMove;

  [draggedIcon setSelected:NO];
  [draggedIcon setDimmed:YES];
  // Icon will be added back in draggingEntered:icon:
  // [filesView removeIcon:sender];
  
  // Pasteboard info for 'draggedIcon'
  // pbTypes = [NSArray arrayWithObjects:NSFilenamesPboardType,NSGeneralPboardType,
  //                    nil];
  // [pb declareTypes:pbTypes owner:nil];
  // [pb setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];
  // if ((iconInfo = [draggedIcon info]) != nil)
  //   {
  //     [pb setPropertyList:iconInfo forType:NSGeneralPboardType];
  //   }

  [filesView dragImage:[draggedIcon iconImage]
                    at:iconLocation
                offset:NSZeroSize
                 event:event
            pasteboard:pb
                source:draggedSource
             slideBack:YES];
}
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXIconView *)sender
{
  NSLog(@"[Recycler] draggingSourceOperationMaskForLocal:");
  return NSDragOperationMove;
}
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSLog(@"[Recycler] draggingEntered: %@", [(NSObject *)sender className]);
  return NSDragOperationMove;
}
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSLog(@"[Recycler] draggingUpdated: %@", [(NSObject *)sender className]);
  // [filesView removeIcon:icon];
  return NSDragOperationMove;
}
- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  NSLog(@"[Recycler] draggingExited: %@", [(NSObject *)sender className]);
  // [filesView removeIcon:icon];
}

// Icon actions
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  NSLog(@"[Recycler] draggingEntered:icon:");
  return NSDragOperationMove;
}
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  NSLog(@"[Recycler] draggingUpdated:icon:");
  return NSDragOperationMove;
}
- (void)draggingExited:(id <NSDraggingInfo>)sender
                  icon:(NXIcon *)icon
{
  NSLog(@"[Recycler] draggingOperationExited:icon:");
  [filesView removeIcon:icon];
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

  if ([changedPath isEqualToString:_path])
    {
      [self updateIconImage];
      [self updatePanel];
    }
}

@end
