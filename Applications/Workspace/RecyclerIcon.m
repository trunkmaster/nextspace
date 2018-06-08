/* */
#import <GNUstepGUI/GSDisplayServer.h>
#import <Operations/ProcessManager.h>

#import "Recycler.h"
#import "RecyclerIcon.h"

static Recycler *recycler = nil;

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
  [self registerForDraggedTypes:@[NSFilenamesPboardType]];
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

  if (([NSDate timeIntervalSinceReferenceDate] - tInterval) < 0.1) {
    return;
  }

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
  if ([fm fileExistsAtPath:dbPath]) {
    db = [[NSMutableDictionary alloc] initWithContentsOfFile:dbPath];
  }
  else {
    db = [NSMutableDictionary new];
  }
  
  NSLog(@"Recycler: perform dragging");
  
  [recycler setIconImage:[NSImage imageNamed:@"recycler"]];
  
  if ([types containsObject:NSFilenamesPboardType] == YES) {
    NSString *name, *path;
      
    items = [[dragPb propertyListForType:NSFilenamesPboardType] mutableCopy];
    sourceDir = [[items objectAtIndex:0] stringByDeletingLastPathComponent];

    for (NSUInteger i = 0; i < [items count]; i++) {
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
  for (rec_pos = new_max_icons-1; rec_pos > 0; rec_pos--) {
    if ((btn = dock->icon_array[rec_pos]) == NULL) {
      break;
    }
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
  for (int i=0; i < new_max_icons; i++) {
    // NSLog(@"%i", i);
    if (dock->icon_array[i] == NULL || i >= dock->max_icons) {
      new_icon_array[i] = NULL;
    }
    else {
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
  while (btn->next) {
    if (!strcmp(btn->wm_instance, "Recycler")) {
      rec_btn = btn;
      break;
    }
    btn = btn->next;
  }

  if (!rec_btn) {
    rec_btn = wAppIconCreateForDock(dock->screen_ptr, "-", "Recycler",
                                    "GNUstep", TILE_NORMAL);
  }
  
  new_yindex = [RecyclerIcon positionInDock:dock];
  new_max_icons = dock->screen_ptr->scr_height / wPreferences.icon_size;

  if (rec_btn->docked &&
      (rec_btn->yindex > new_max_icons-1 && new_yindex == 0)) {
    NSLog(@"Recycler: detach");
    wDockDetach(dock, rec_btn);
  }
  else if (rec_btn->docked) {
    [RecyclerIcon rebuildDock:dock];
    new_yindex = [RecyclerIcon positionInDock:dock];
    if (rec_btn->yindex != new_yindex && new_yindex > 0) {
      NSLog(@"Recycler: reattach");
      wDockReattachIcon(dock, rec_btn, 0, new_yindex);
    }
  }
  else if (!rec_btn->docked && new_yindex > 0) {
    [RecyclerIcon rebuildDock:dock];
    new_yindex = [RecyclerIcon positionInDock:dock];
    if (new_yindex > 0) {
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

- (void)_initDefaults
{
  [super _initDefaults];
  
  [self setTitle:@"Recycler"];
  [self setExcludedFromWindowsMenu:YES];
  [self setReleasedWhenClosed:NO];
  
  if ([[NSUserDefaults standardUserDefaults] 
        boolForKey: @"GSAllowWindowsOverIcons"] == YES) {
    _windowLevel = NSDockWindowLevel;
  }
}

- (id)initWithWindowRef:(void *)X11Window recycler:(Recycler *)theRecycler
{
  self = [super initWithWindowRef:X11Window];
  recycler = theRecycler;

  return self;
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

@end

