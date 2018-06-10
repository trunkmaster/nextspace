//  PathIcon.m
//  An NXIcon subclass that implements file operations.
//
//  PathIcon holds information about object(file, dir) path. Set with setPath:
//  method. Any other metainformation (e.g. device for mount point) set with
//  setInfo: method.


#import <AppKit/AppKit.h>
#import <NXSystem/NXSystemInfo.h>

#import "Controller+NSWorkspace.h"
#import "FileViewer.h"
#import <Operations/ProcessManager.h>
#import "PathIcon.h"

@implementation PathIcon (Private)

- (NSEvent *)_waitForSecondMouseClick
{
  unsigned  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
			 | NSPeriodicMask | NSOtherMouseUpMask 
			 | NSRightMouseUpMask);
  NSEvent   *event = nil;

  event = [[self window]
    nextEventMatchingMask:eventMask
		untilDate:[NSDate dateWithTimeIntervalSinceNow:0.30]
		   inMode:NSEventTrackingRunLoopMode
		  dequeue:NO];
  return event;
}

@end

@implementation PathIcon

//============================================================================
// Init and destroy
//============================================================================

- init
{
  [super init];

  // registerForDraggedTypes: must call view that holds icon (Shelf, Path).
  // Calling it here make shelf icons continuosly added and removed
  // while dragged.
//  [self registerForDraggedTypes:
//       [NSArray arrayWithObject:NSFilenamesPboardType]];

  doubleClickPassesClick = YES;
  return self;
}

- (void)dealloc
{
  TEST_RELEASE(paths);
  TEST_RELEASE(info);

  [super dealloc];
}

// Overriding
- (void)mouseDown:(NSEvent *)ev
{
  int        clickCount;
  NSArray    *slctdIcons;
  NXIconView *superView = (NXIconView *)[self superview];

  if (target == nil || isSelectable == NO || [ev type] != NSLeftMouseDown)
    {
      return;
    }

//  NSLog(@"PathIcon: mouseDown");

  // [superView selectIcons:[NSSet setWithObject:self]];
    
  clickCount = [ev clickCount];
  modifierFlags = [ev modifierFlags];
  
  [superView updateSelectionWithIcons:[NSSet setWithObject:self]
                        modifierFlags:modifierFlags];

  // Dragging
  if ([target respondsToSelector:dragAction]) {
    NSPoint startPoint = [ev locationInWindow];
    unsigned int mask = NSLeftMouseDraggedMask | NSLeftMouseUpMask;

    //      NSLog(@"[PathIcon-mouseDown]: DRAGGING");

    while ([(ev = [[self window] nextEventMatchingMask:mask 
                                             untilDate:[NSDate distantFuture]
                                                inMode:NSEventTrackingRunLoopMode
                                               dequeue:YES])
	     type] != NSLeftMouseUp) {
      NSPoint endPoint = [ev locationInWindow];
      
      if (absolute_value(startPoint.x - endPoint.x) > 3 ||
          absolute_value(startPoint.y - endPoint.y) > 3) {
        [target performSelector:dragAction
                     withObject:self
                     withObject:ev];
        return;
      }
    }
  }

  [_window makeFirstResponder:[longLabel nextKeyView]];

  // Clicking
  if (clickCount == 2) {
    if ([target respondsToSelector:doubleAction]) {
      [target performSelector:doubleAction withObject:self];
    }
  }
  else if (clickCount == 1 || clickCount > 2) {
    // Double clicked
    if (!doubleClickPassesClick && [self _waitForSecondMouseClick] != nil) {
      return;
    }
    // [_window makeFirstResponder:[[self label] nextKeyView]];
    if ([target respondsToSelector:action]) {
      [target performSelector:action withObject:self];
    }
  }  
}

// Addons
- (void)setPaths:(NSArray *)newPaths
{
  ASSIGN(paths, newPaths);
  
  if ([paths count] > 1)
    {
      [self setLabelString:
              [NSString stringWithFormat:_(@"%d items"),[paths count]]];
    }
  else
    {
      NSString *path = [paths objectAtIndex:0];
      
      if ([[path pathComponents] count] == 1)
        {
          [self setLabelString:[NXSystemInfo hostName]];
        }
      else
        {
          [self setLabelString:[path lastPathComponent]];
        }
    }
}

- (NSArray *)paths
{
  return paths;
}

- (void)setInfo:(NSDictionary *)anInfo
{
  ASSIGN(info, [anInfo copy]);
}

- (NSDictionary *)info
{
  return info;
}

- (void)setDoubleClickPassesClick:(BOOL)isPass
{
  doubleClickPassesClick = isPass;
}

- (BOOL)isDoubleClickPassesClick
{
  return doubleClickPassesClick;
}

- (BOOL)becomeFirstResponder
{
  return NO;
}

//============================================================================
// Drag and drop
//============================================================================

// --- NSDraggingSource must have 'draggingSourceOperationMaskForLocal:'
// catched by enclosing view (PathView, ShelfView) and dispathed to
// 'delegate' - FileViewer 'draggingSourceOperationMaskForLocal:iconView:'
// method.

// --- NSDraggingDestination

// - Before the Image is Released
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSString *destPath;
  NSArray  *sourcePaths;

  sourcePaths = [[sender draggingPasteboard]
                  propertyListForType:NSFilenamesPboardType];
  destPath = [paths objectAtIndex:0];

  NSLog(@"[PathIcon] draggingEntered: %@(%@) -> %@",
        [(NSObject* )sender className], [delegate className], destPath);

  // NSLog(@"[PathIcon] draggingEntered (%@->%@): %@ --> %@ delegate: %@", 
  //       [[sender draggingSource] className], [self className], 
  //       sourcePaths, destPath, [delegate className]);

  if ([sender draggingSource] == self)
    {
      // Dragging to itself - source and dest paths are equal!
      draggingMask = NSDragOperationNone;
    }
  else if (![sourcePaths isKindOfClass:[NSArray class]] 
	   || [sourcePaths count] == 0)
    {
      NSLog(@"sourcePaths bad!!!");
      draggingMask = NSDragOperationNone;
    }
  else if (delegate &&
           [delegate respondsToSelector:
                       @selector(draggingDestinationMaskForPaths:intoPath:)])
    {
      draggingMask = [delegate draggingDestinationMaskForPaths:sourcePaths
                                                      intoPath:destPath];
    }
  else
    {
      draggingMask = NSDragOperationNone;
    }

  if (draggingMask != NSDragOperationNone)
    {
      // NSWorkspace?
      [self setIconImage:[[NSApp delegate] openIconForDirectory:destPath]];
    }

  return draggingMask;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
//  NSLog(@"[PathIcon] draggingUpdated");
  return draggingMask;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  Controller *wsDelegate = [NSApp delegate];
  
  NSLog(@"[PathIcon] draggingExited");
  if (draggingMask != NSDragOperationNone)
    {
      [self setIconImage:[wsDelegate iconForFile:[paths objectAtIndex:0]]];
    }
}

// - After the Image is Released
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSMutableArray *filenames = [NSMutableArray array];
  NSArray        *sourcePaths = [[sender draggingPasteboard]
                                  propertyListForType: NSFilenamesPboardType];
  NSEnumerator   *e = [sourcePaths objectEnumerator];
  NSString       *sourceDir, * path;
  unsigned int   mask;
  unsigned int   opType = NSDragOperationNone;

  sourceDir = [[sourcePaths objectAtIndex: 0]
                stringByDeletingLastPathComponent];

  // construct an array holding only the trailing filenames
  while ((path = [e nextObject]) != nil)
    {
      [filenames addObject:[path lastPathComponent]];
    }

  mask = [sender draggingSourceOperationMask];

  if (mask & NSDragOperationMove)
    // opType = NSDragOperationMove;
    opType = MoveOperation;
  else if (mask & NSDragOperationCopy)
    // opType = NSDragOperationCopy;
    opType = CopyOperation;
  else if (mask & NSDragOperationLink)
    // opType = NSDragOperationLink;
    opType = LinkOperation;
  else
    return NO;

  [[ProcessManager shared] startOperationWithType:opType
                                           source:sourceDir
                                           target:[paths objectAtIndex:0]
                                            files:filenames];

  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [self draggingExited:sender];
}

@end
