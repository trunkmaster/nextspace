//
// Workspace Manager Shelf view
//   Holds icons for dirs and applications.
//   Holds icons of multiple selections temporarely
//

#import <math.h>
#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>

#import <Preferences/Shelf/ShelfPrefs.h>
#import <Viewers/FileViewer.h>
#import <Controller.h>

#import "Recycler.h"
#import "PathIcon.h"
#import "ShelfView.h"

NXIconSlot lastSlotDragEntered;

@interface ShelfView (Private)

@end

@implementation ShelfView (Private)

@end

@implementation ShelfView

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer
{
  [super initWithFrame:r];

  _owner = fileViewer;
  
  [self setAllowsMultipleSelection:NO];
  [self setAllowsArrowsSelection:NO];
  [self setAllowsAlphanumericSelection:NO];
  [self setAutoAdjustsToFitIcons:NO];
  
  [self setTarget:self];
  [self setDelegate:self];
  [self setAction:@selector(iconClicked:)];
  [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(iconDragged:event:)];
  [self registerForDraggedTypes:@[NSFilenamesPboardType]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(iconSlotWidthChanged:)
           name:ShelfIconSlotWidthDidChangeNotification
         object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:_owner
       selector:@selector(shelfResizableStateChanged:)
           name:ShelfResizableStateDidChangeNotification
         object:nil];

  return self;
}

- (void)reconstructFromRepresentation:(NSDictionary *)aDict
{
  for (NSArray *key in [aDict allKeys]) {
    NSArray    *paths;
    NXIconSlot slot;
    PathIcon   *icon;

    if (![key isKindOfClass:[NSArray class]] || [key count] != 2) {
      continue;
    }
    if (![[key objectAtIndex:0] respondsToSelector:@selector(intValue)] ||
        ![[key objectAtIndex:1] respondsToSelector:@selector(intValue)]) {
      continue;
    }

    slot = NXMakeIconSlot([[key objectAtIndex:0] intValue],
                          [[key objectAtIndex:1] intValue]);
      
    paths = [aDict objectForKey:key];
    if (![paths isKindOfClass:[NSArray class]]) {
      continue;
    }

    icon = [self createIconForPaths:paths];
    if (icon) {
      [self putIcon:icon intoSlot:slot];
    }
  }
}

- (NSDictionary *)storableRepresentation
{
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  Class               nullClass = [NSNull class];

  for (PathIcon *icon in [self icons]) {
    NXIconSlot slot;

    if ([icon isKindOfClass:nullClass] || [[icon paths] count] > 1) {
      continue;
    }

    slot = [self slotForIcon:icon];

    if (slot.x == -1) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"ShelfView: in `-storableRepresentation':"
                   @" Unable to deteremine the slot for an icon that"
                   @" _must_ be present"];
    }

    [dict setObject:[icon paths] forKey:@[[NSNumber numberWithInt:slot.x],
                                          [NSNumber numberWithInt:slot.y]]];
  }

  return [dict autorelease];
}

- (void)addIcon:(NXIcon *)anIcon
{
  [super addIcon:anIcon];
  [anIcon setEditable:NO];
}

- (void)putIcon:(NXIcon *)anIcon
       intoSlot:(NXIconSlot)aSlot
{
  [super putIcon:anIcon intoSlot:aSlot];
  [anIcon setEditable:NO];
}

//=============================================================================
// Shelf (moved from FileViewer)
//=============================================================================

- (void)checkIfContentsExist
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *path;

  NSDebugLLog(@"FileViewer", @">>>>>>>>> checkShelfContentsExist");

  for (PathIcon *icon in [self icons]) {
    path = [[icon paths] objectAtIndex:0];
    if (![fm fileExistsAtPath:path]) {
      NSLog(@"Shelf element %@ doesn't exist.", path);
      [self removeIcon:icon];
    }
  }
}

- (void)shelfAddMountedRemovableMedia
{
  id<MediaManager> mediaManager = [[NSApp delegate] mediaManager];
  NSArray          *mountPoints = [mediaManager mountedRemovableMedia];
  NSDictionary     *info;
  NSNotification   *notif;

  for (NSString *mountPath in mountPoints) {
    info = [NSDictionary dictionaryWithObject:mountPath forKey:@"MountPoint"];
    notif = [NSNotification notificationWithName:NXVolumeMounted
                                          object:mediaManager
                                        userInfo:info];
    [_owner volumeDidMount:notif];
  }
}

- (void)iconClicked:(id)sender
{
  NSString *path = [[sender paths] lastObject];
  
  [_owner slideToPathFromShelfIcon:sender];
  
  // Convert 'path' variable contents as relative path
  if ([_owner isFolderViewer]) {
    if ([path isEqualToString:[_owner rootPath]]) {
      path = @"/";
    }
    else {
      path = [path substringFromIndex:[[_owner rootPath] length]];
    }
  }
  
  [_owner displayPath:path selection:nil sender:self];
  [self selectIcons:nil];
}

- (void)iconDoubleClicked:(id)sender
{
  PathIcon *selectedIcon = sender;

  [selectedIcon setDimmed:YES];
  [_owner open:selectedIcon];

  [selectedIcon setDimmed:NO];
  [self selectIcons:nil];
}

- (NSArray *)pathsForDrag:(id <NSDraggingInfo>)draggingInfo
{
  NSArray *paths;

  paths = [[draggingInfo draggingPasteboard]
            propertyListForType:NSFilenamesPboardType];

  if (![paths isKindOfClass:[NSArray class]] || [paths count] != 1) {
    return nil;
  }

  return paths;
}

- (PathIcon *)createIconForPaths:(NSArray *)paths
{
  PathIcon *icon;
  NSString *path;
  NSString *relativePath;
  NSString *rootPath = [_owner rootPath];

  if ((path = [paths objectAtIndex:0]) == nil) {
    return nil;
  }

  // make sure its a subpath of our current root path
  if ([path rangeOfString:rootPath].location != 0) {
    return nil;
  }
  relativePath = [path substringFromIndex:[rootPath length]];

  icon = [[PathIcon new] autorelease];
  if ([paths count] == 1) {
    [icon setIconImage:[[NSApp delegate] iconForFile:path]];
  }
  [icon setPaths:paths];
  [icon setDelegate:self];
  [icon setDoubleClickPassesClick:NO];
  [icon setEditable:NO];
  [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
  [[icon label] setNextKeyView:[[_owner viewer] view]];

  return icon;
}

- (void)didAcceptIcon:(PathIcon *)anIcon
               inDrag:(id <NSDraggingInfo>)draggingInfo
{
  // NSLog(@"[FileViewer] didAcceptIcon in shelf");
  if ([[anIcon paths] count] == 1) {
    [anIcon registerForDraggedTypes:@[NSFilenamesPboardType]];
  }
  [anIcon setDelegate:self];
}

- (void)iconDragged:(id)sender event:(NSEvent *)ev
{
  NSDictionary *iconInfo;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;
  NXIconSlot   iconSlot = [self slotForIcon:sender];

  NSLog(@"Shelf: iconDragged: %@", [sender className]);

  draggedSource = self;
  draggedIcon = [sender retain];

  [sender setSelected:NO];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if (iconSlot.x == 0 && iconSlot.y == 0) {
    draggedMask = NSDragOperationCopy;
  }
  else {
    draggedMask = (NSDragOperationMove|NSDragOperationCopy);
    [self removeIcon:sender];
  }

  // Pasteboard info for 'draggedIcon'
  [pb declareTypes:@[NSFilenamesPboardType,NSGeneralPboardType] owner:nil];
  [pb setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];
  if ((iconInfo = [draggedIcon info]) != nil) {
    [pb setPropertyList:iconInfo forType:NSGeneralPboardType];
  }

  [self dragImage:[draggedIcon iconImage]
               at:iconLocation
           offset:NSZeroSize
            event:ev
       pasteboard:pb
           source:draggedSource
        slideBack:NO];
}

// --- Notifications

- (void)iconSlotWidthChanged:(NSNotification *)notif
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     size = [self slotSize];
  CGFloat    width = 0.0;

  if ((width = [df floatForKey:ShelfIconSlotWidth]) > 0.0) {
    size.width = width;
  }
  else {
    size.width = SHELF_LABEL_WIDTH;
  }
  [self setSlotSize:size];
}

//============================================================================
// Drag and drop
//============================================================================

// --- NSDraggingSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXIconView *)sender
{
  NSLog(@"[ShelfView] draggingSourceOperationMaskForLocal: %@",
        [sender className]);
  // if (isLocal == NO) {
  //   return NSDragOperationDelete;
  // }
  // else {
    return NSDragOperationMove;
  // }
}

- (void)draggedImage:(NSImage *)image
	     endedAt:(NSPoint)screenPoint
	   operation:(NSDragOperation)operation
{
  NSLog(@"[ShelfView] draggedImage:endedAt:operation:%lu", operation);
  NXIconSlot iconSlot = [self slotForIcon:draggedIcon];
  NSPoint    windowPoint = [[_owner window] convertScreenToBase:screenPoint];
  NSPoint    shelfPoint = [self convertPoint:windowPoint fromView:nil];

  [draggedIcon setDimmed:NO];

  // Root icon must never be moved or removed
  if (iconSlot.x == 0 && iconSlot.y == 0)
    {
      return;
    }

  NSLog(@"windowPoint %@ shelfPoint %@", 
        NSStringFromPoint(windowPoint), NSStringFromPoint(shelfPoint));

  [draggedIcon release];
      
  draggedSource = nil;
  draggedIcon = nil;
}

// --- NSDraggingDestination

- (unsigned int)updateDraggedIconToDrag:(id <NSDraggingInfo>)dragInfo
{
  NSSize     mySlotSize = [self slotSize];
  NSPoint    p = [self convertPoint:[dragInfo draggingLocation]
	   		   fromView:nil];
  NXIconSlot slot = NXMakeIconSlot(floorf(p.x / mySlotSize.width),
				   floorf(p.y / mySlotSize.height));
  NXIcon     *icon;


  // Draging hasn't leave shelf yet and no slot for drop
  if (slot.x >= [self slotsWide])
    {
      slot.x = [self slotsWide]-1;
    }
  if (slot.y >= [self slotsTall])
    {
      slot.y = [self slotsTall]-1;
    }

  if (lastSlotDragEntered.x == slot.x &&
      lastSlotDragEntered.y == slot.y)
    {
      return draggedMask;
    }
  else
    {
      lastSlotDragEntered.x = slot.x;
      lastSlotDragEntered.y = slot.y;
    }

  icon = [self iconInSlot:slot];
  draggedMask = NSDragOperationMove;
//  NSLog(@"DRAG: slot.x,y: %i,%i slotsWide: %i icon:%@", slot.x, slot.y, slotsWide, icon);

  if (icon == nil)
    {
      id draggingSource = [dragInfo draggingSource];
      if ([draggingSource class] != [self class])
	{
	  draggedMask = NSDragOperationCopy;
	}
      if ([draggedIcon superview])
	{
	  [self removeIcon:draggedIcon];
	}
      [self putIcon:draggedIcon intoSlot:slot];
    }
  else if (icon != draggedIcon)
    {
      draggedMask = NSDragOperationNone;
    }

  return draggedMask;
}

// - Before the Image is Released

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSArray      *paths;
  NSDictionary *info;
  NXIconSlot   iconSlot;

  NSLog(@"[ShelfView] -draggingEntered (source:%@)",
        [[sender draggingSource] className]);

  if (delegate == nil ||
      [[sender draggingSource] isKindOfClass:[Recycler class]])
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }

  paths = [[sender draggingPasteboard]
            propertyListForType:NSFilenamesPboardType];
  if (![paths isKindOfClass:[NSArray class]] || [paths count] == 0)
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }

  ASSIGN(draggedIcon, [self createIconForPaths:paths]);
  if (draggedIcon == nil)
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }
  else
    {
      [draggedIcon setInfo:[[sender draggingPasteboard]
                             propertyListForType:NSGeneralPboardType]];
      [draggedIcon setIconImage:[sender draggedImage]];
    }

  [draggedIcon setDimmed:YES];

  savedDragResult = YES;
  return [self updateDraggedIconToDrag:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  // NSLog(@"[ShelfView] draggingUpdated");
  if (savedDragResult == NO) {
    return NSDragOperationNone;
  }

  return [self updateDraggedIconToDrag:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)dragInfo
{
  NSLog(@"[ShelfView] draggingExited");

  [self removeIcon:draggedIcon];

  lastSlotDragEntered.x = -1;
  lastSlotDragEntered.y = -1;
  DESTROY(draggedIcon);
  draggedIcon = nil;
}

// - After the Image is Released

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSLog(@"[ShelfView] performDragOperation");
  if ([delegate respondsToSelector:@selector(shelf:didAcceptIcon:inDrag:)])
    {
      [delegate shelf:self didAcceptIcon:draggedIcon inDrag:sender];
    }

  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSLog(@"[ShelfView] concludeDragOperation");

  [draggedIcon setDimmed:NO];

  lastSlotDragEntered.x = -1;
  lastSlotDragEntered.y = -1;
  DESTROY(draggedIcon);
  draggedIcon = nil;
}

// --- NSView overridings

- (void)mouseDown:(NSEvent *)ev
{
  // Do nothing. It prevents bogus icons deselection.
}

- (BOOL)acceptsFirstResponder
{
  // Do nothing. It prevents first responder stealing.
  return NO;
}

@end
