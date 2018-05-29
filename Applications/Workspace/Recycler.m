/* All Rights reserved */

#import <GNUstepGUI/GSDisplayServer.h>
#import <NXAppKit/NXAlert.h>
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
      NSLog(@"%i", i);
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

static NSSize scaledIconSizeForSize(NSSize imageSize)
{
  NSSize iconSize, retSize;
  
  // iconSize = GSGetIconSize();
  iconSize = NSMakeSize(64,64);
  retSize.width = imageSize.width * iconSize.width / 64;
  retSize.height = imageSize.height * iconSize.height / 64;
  return retSize;
}

+ (void)initialize
{
  NSImage *tileImage;
  NSSize  iconSize = NSMakeSize(64,64);

  // iconSize = GSGetIconSize();
  dragCell = [[NSCell alloc] initImageCell:nil];
  [dragCell setBordered:NO];
  
  tileImage = [[GSCurrentServer() iconTileImage] copy];
  [tileImage setScalesWhenResized:YES];
  [tileImage setSize:iconSize];
  tileCell = [[NSCell alloc] initImageCell:tileImage];
  RELEASE(tileImage);
  [tileCell setBordered:NO];
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize = NSMakeSize(64,64);
  // NSSize iconSize = GSGetIconSize();
  
  NSLog(@"Recycler View: drawRect!");
  
  [tileCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
  		   inView:self];
  [dragCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
        	   inView:self];

  // for (NSView *sv in [self subviews])
  //   {
  //     [sv drawRect:rect];
  //   }
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self registerForDraggedTypes:[NSArray arrayWithObjects:
                                           NSFilenamesPboardType, nil]];
  return self;
}

- (void)setImage:(NSImage *)anImage
{
  NSImage *imgCopy = [anImage copy];

  if (imgCopy)
    {
      NSSize imageSize = [imgCopy size];

      [imgCopy setScalesWhenResized:YES];
      [imgCopy setSize:scaledIconSizeForSize(imageSize)];
    }
  [dragCell setImage:imgCopy];
  RELEASE(imgCopy);
  [self setNeedsDisplay:YES];
}

// --- Drag and Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  NSLog(@"Recycler: dragging entered!");
  return NSDragOperationGeneric;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
  return NSDragOperationGeneric;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  // NSArray	*types;
  // NSPasteboard	*dragPb;

  // dragPb = [sender draggingPasteboard];
  // types = [dragPb types];
  // if ([types containsObject: NSFilenamesPboardType] == YES)
  //   {
  //     NSArray	*names = [dragPb propertyListForType: NSFilenamesPboardType];
  //     NSUInteger index;

  //     [NSApp activateIgnoringOtherApps: YES];
  //     for (index = 0; index < [names count]; index++)
  //       {
  //         [NSApp _openDocument: [names objectAtIndex: index]];
  //       }
  //     return YES;
  //   }
  return NO;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
}

@end

@implementation Recycler

- initWithDock:(WDock *)dock
{
  XClassHint classhint;
  BOOL       isDir;

  recycler = self = [super init];
  
  dockIcon = [RecyclerIcon recyclerAppIconForDock:dock];
 
  if (dockIcon == NULL)
    {
      NSLog(@"Recycler Dock icon creation failed!");
      return nil;
    }

  dockIcon->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;

  classhint.res_name = "Recycler";
  classhint.res_class = "GNUstep";
  XSetClassHint(dpy, dockIcon->icon->core->window, &classhint);
  
  appIcon = [[RecyclerIcon alloc] initWithWindowRef:&dockIcon->icon->core->window];
  
  recyclerPath = [[NSString stringWithFormat:@"%@/.Recycler", NSHomeDirectory()]
                   retain];
  if ([[NSFileManager defaultManager] fileExistsAtPath:recyclerPath
                                           isDirectory:&isDir] == NO)
    {
      if ([[NSFileManager defaultManager] createDirectoryAtPath:recyclerPath
                                                     attributes:nil] == NO)
        {
          NXRunAlertPanel(_(@"Workspace"),
                          _(@"Your Recycler storage doesn't exist and cannot"
                            " be created at path: %@."),
                          _(@"Dismiss"), nil, nil, recyclerPath);
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
  [appIcon setContentView:appIconView];
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
  [fileSystemMonitor addPath:recyclerPath];

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [appIcon release];
  [fileSystemMonitor removePath:recyclerPath];
  [recyclerPath release];
  
  [super dealloc];
}

- (WAppIcon *)dockIcon
{
  return dockIcon;
}

- (RecyclerIcon *)appIcon
{
  return appIcon;
}

- (void)awakeFromNib
{
  [panel setFrameAutosaveName:@"Recycler"];
  
  [panelView setHasHorizontalScroller:YES];
  [panelView setHasVerticalScroller:NO];
  filesView = [[NXIconView alloc] initWithFrame:[panelView frame]];
  [panelView setDocumentView:filesView];

  [panelIcon setImage:[self iconImage]];
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
  
  [panel makeKeyAndOrderFront:self];
}

- (void)mouseDown:(NSEvent*)theEvent
{
  NSLog(@"Recycler: mouse down!");

  if ([theEvent clickCount] >= 2)
    {
      NSLog(@"Recycler: show Recycler window");
      [self showPanel];
      
      /* if not hidden raise windows which are possibly obscured. */
      if ([NSApp isHidden] == NO)
        {
          NSArray *windows = RETAIN(GSOrderedWindows());
          NSWindow *aWin;
          NSEnumerator *iter = [windows reverseObjectEnumerator];
          
          while ((aWin = [iter nextObject]))
            { 
              if ([aWin isVisible] == YES && [aWin isMiniaturized] == NO
                  && aWin != [NSApp keyWindow] && aWin != [NSApp mainWindow]
                  && aWin != appIcon
                  && ([aWin styleMask] & NSMiniWindowMask) == 0)
                {
                  [aWin orderFrontRegardless];
                }
            }
	
          if ([NSApp isActive] == YES)
            {
              if ([NSApp keyWindow] != nil)
                {
                  [[NSApp keyWindow] orderFront:self];
                }
              else if ([NSApp mainWindow] != nil)
                {
                  [[NSApp mainWindow] makeKeyAndOrderFront:self];
                }
              else
                {
                  /* We need give input focus to some window otherwise we'll 
                     never get keyboard events. FIXME: doesn't work. */
                  NSWindow *menu_window = [[NSApp mainMenu] window];
                  NSDebugLLog(@"Focus",
                              @"No key on activation - make menu key");
                  [GSServerForWindow(menu_window)
                      setinputfocus:[menu_window windowNumber]];
                }
            }
	  
          RELEASE(windows);
        }
      [NSApp unhide:self]; // or activate or do nothing.
    }
}

- (NSImage *)iconImage
{
  return iconImage;
}
- (void)updateIconImage
{
  itemsCount = [[[NSFileManager defaultManager]
                  directoryContentsAtPath:recyclerPath] count];
  
  if (itemsCount)
    {
      iconImage = [NSImage imageNamed:@"recyclerFull"];
      [badge setStringValue:[NSString stringWithFormat:@"%lu", itemsCount]];
    }
  else
    {
      iconImage = [NSImage imageNamed:@"recycler"];
      [badge setStringValue:@""];
    }
  
  
  [appIconView setImage:iconImage];
  
  if (panel)
    [panelIcon setImage:[self iconImage]];
}

- (NSUInteger)itemsCount
{
  return itemsCount;
}

- (void)fileSystemChangedAtPath:(NSNotification *)notif
{
  NSDictionary *changes = [notif userInfo];
  NSString     *changedPath = [changes objectForKey:@"ChangedPath"];

  if ([changedPath isEqualToString:recyclerPath])
    [self updateIconImage];
}

- (void)purge
{
}

@end
