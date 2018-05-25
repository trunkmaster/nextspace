/* All Rights reserved */

#import <GNUstepGUI/GSDisplayServer.h>
#import <NXAppKit/NXAlert.h>
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
      if (IsDoubleClick(aicon->dock->screen_ptr, event))
        clickCount = 2;

      // Handle move of icon
      wHandleAppIconMove(desc->parent, event);
  
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

+ (WAppIcon *)createAppIconForDock:(WDock *)dock
{
  WScreen  *scr = dock->screen_ptr;
  WAppIcon *btn = NULL;
  int      rec_pos;
 
  // Search for position in Dock for new Recycler
  for (rec_pos = dock->max_icons-1; rec_pos > 0; rec_pos--)
    {
      if ((btn = dock->icon_array[rec_pos]) == NULL)
        break;
    }

  if (rec_pos > 0) // There is a space in Dock
    {
      btn = wAppIconCreateForDock(scr, "", "Recycler", "GNUstep", TILE_NORMAL);
      btn->yindex = rec_pos;
    }
  else // No space in Dock
    {
      NSLog(@"Recycler: no space in the Dock. Not implemented yet...");
    }

  return btn;
}

+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock
{
  WScreen  *scr = dock->screen_ptr;
  WAppIcon *btn, *rec_btn = NULL;
 
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
      rec_btn = [RecyclerIcon createAppIconForDock:dock];
      wDockAttachIcon(dock, rec_btn, 0, rec_btn->yindex, NO);
    }
  
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
  
  recyclerPath = [NSString stringWithFormat:@"%@/.Recycler", NSHomeDirectory()];
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
  [self updateIconImage];
  [appIcon setContentView:appIconView];
  [appIconView release];

  return self;
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
  [panelView setVerticalScroller:nil];
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

// Actions

- (NSImage *)iconImage
{
  return iconImage;
}
- (void)updateIconImage
{
  if ([[[NSFileManager defaultManager] directoryContentsAtPath:recyclerPath] count])
    iconImage = [NSImage imageNamed:@"recyclerFull"];
  else
    iconImage = [NSImage imageNamed:@"recycler"];
  
  [appIconView setImage:iconImage];
  if (panel)
    [panelIcon setImage:[self iconImage]];
}

@end
