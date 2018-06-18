//  PathIcon.m
//  An NXIcon subclass that implements file operations.
//
//  PathIcon holds information about object(file, dir) path. Set with setPath:
//  method. Any other metainformation (e.g. device for mount point) set with
//  setInfo: method.


#import <AppKit/AppKit.h>
#import <NXSystem/NXSystemInfo.h>
#import <NXSystem/NXMouse.h>

#import <GNUstepGUI/GSDisplayServer.h>
#import <GNUstepGUI/GSDragView.h>

#import "Workspace+WindowMaker.h"
#import "Controller+NSWorkspace.h"
#import "FileViewer.h"
#import <Operations/ProcessManager.h>
#import "PathIcon.h"

@interface NSApplication (GNUstepPrivate)
- (void)_postAndSendEvent:(NSEvent *)anEvent;
@end
@interface NSCursor (BackendPrivate)
- (void *)_cid;
- (void)_setCid:(void *)val;
@end
@interface GSDragView (Private)
- (void) _clearupWindow;
- (BOOL) _updateOperationMask: (NSEvent*) theEvent;
- (void) _setCursor;
- (void) _sendLocalEvent: (GSAppKitSubtype)subtype
                  action: (NSDragOperation)action
                position: (NSPoint)eventLocation
               timestamp: (NSTimeInterval)time
                toWindow: (NSWindow*)dWindow;
- (void) _handleDrag: (NSEvent*)theEvent slidePoint: (NSPoint)slidePoint;
- (void) _handleEventDuringDragging: (NSEvent *)theEvent;
- (void) _updateAndMoveImageToCorrectPosition;
- (void) _moveDraggedImageToNewPosition;
- (void) _slideDraggedImageTo: (NSPoint)screenPoint
                numberOfSteps: (int) steps
                        delay: (float) delay
               waitAfterSlide: (BOOL) waitFlag;
@end
@implementation GSDragView (Private)

- (void)_clearupWindow
{
  [_window setFrame:NSZeroRect display:NO];
  [_window orderOut:nil];
}

- (BOOL)_updateOperationMask:(NSEvent*) theEvent
{
  NSUInteger mod = [theEvent modifierFlags];
  NSDragOperation oldOperationMask = operationMask;

  if (operationMask == NSDragOperationIgnoresModifiers) {
    return NO;
  }
  
  if (mod & NSControlKeyMask) {
    operationMask = NSDragOperationLink;
  }
  else if (mod & NSAlternateKeyMask) {
    operationMask = NSDragOperationCopy;
  }
  else if (mod & NSCommandKeyMask) {
    operationMask = NSDragOperationGeneric;
  }
  else {
    operationMask = NSDragOperationEvery;
  }

  return (operationMask != oldOperationMask);
}

- (void)_setCursor
{
  NSCursor *newCursor;
  NSString *name;
  NSString *iname;
  NSDragOperation mask;

  mask = dragMask & operationMask;
  if (targetWindowRef != 0) {
    mask &= targetMask;
  }

  // NSLog (@"drag, operation, target mask = (%x, %x, %x), dnd aware = %d\n",
  //        (unsigned int)dragMask, (unsigned int)operationMask, (unsigned int)targetMask,
  //        (targetWindowRef != 0));
  
  if (cursors == nil) {
    cursors = RETAIN([NSMutableDictionary dictionary]);
  }
  
  name = nil;
  newCursor = nil;
  iname = nil;
  switch (mask) {
  case NSDragOperationNone:
    name = @"NoCursor";
    iname = @"dragNoneCursor";
    break;
  case NSDragOperationCopy:
    name = @"CopyCursor";
    iname = @"dragCopyCursor";
    break;
  case NSDragOperationLink:
    name = @"LinkCursor";
    iname = @"dragLinkCursor";
    break;
  case NSDragOperationDelete:
    name = @"DeleteCursor";
    iname = @"dragDeleteCursor";
    break;
  default:
    if (targetWindowRef != 0) {
      name = @"MoveCursor";
      iname = @"dragMoveCursor";
    }
    break;
  }

  if (name != nil) {
    newCursor = [cursors objectForKey: name];
    if (newCursor == nil) {
      NSImage *image = [NSImage imageNamed:iname];
      newCursor = [[NSCursor alloc] initWithImage:image];
      [cursors setObject:newCursor forKey:name];
      RELEASE(newCursor);
    }
  }
  if (newCursor == nil) {
    name = @"ArrowCursor";
    newCursor = [cursors objectForKey:name];
    if (newCursor == nil) {
      void *c;
	  
      newCursor = [[NSCursor alloc] initWithImage:nil];
      [GSCurrentServer() standardcursor:GSArrowCursor :&c];
      [newCursor _setCid:c];
      [cursors setObject:newCursor forKey:name];
      RELEASE(newCursor);
    }
  }

  [newCursor set];
}

- (void)_sendLocalEvent:(GSAppKitSubtype)subtype
                 action:(NSDragOperation)action
               position:(NSPoint)eventLocation
              timestamp:(NSTimeInterval)time
               toWindow:(NSWindow*)dWindow
{
  NSEvent           *e;
  NSGraphicsContext *context = GSCurrentContext();
  // FIXME: Should store this once
  NSInteger dragWindowRef;

  dragWindowRef = (NSInteger)(intptr_t)[GSServerForWindow(_window)
                                           windowDevice:[_window windowNumber]];
  eventLocation = [dWindow convertScreenToBase:eventLocation];
  e = [NSEvent otherEventWithType:NSAppKitDefined
	                 location:eventLocation
	            modifierFlags:0
	                timestamp:time
	             windowNumber:[dWindow windowNumber]
	                  context:context
	                  subtype:subtype
	                    data1:dragWindowRef
	                    data2:action];
  [NSApp _postAndSendEvent:e];
}

- (void)_handleDrag:(NSEvent*)theEvent slidePoint:(NSPoint)slidePoint
{
  // Caching some often used values. These values do not
  // change in this method.
  // Use eWindow for coordination transformation
  NSWindow	*eWindow = [theEvent window];
  NSDate	*theDistantFuture = [NSDate distantFuture];
  NSUInteger	eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask |
                             NSLeftMouseDraggedMask | NSMouseMovedMask |
                             NSPeriodicMask | NSAppKitDefinedMask |
                             NSFlagsChangedMask);
  NSPoint       startPoint;
  // Storing values, to restore after we have finished.
  NSCursor      *cursorBeforeDrag = [NSCursor currentCursor];
  BOOL          deposited;

  startPoint = [eWindow convertBaseToScreen:[theEvent locationInWindow]];
  startPoint.x -= offset.width;
  startPoint.y -= offset.height;
  // NSLog(@"Drag window origin %@\n", NSStringFromPoint(startPoint));

  // Notify the source that dragging has started
  if ([dragSource respondsToSelector:@selector(draggedImage:beganAt:)]) {
    [dragSource draggedImage:[self draggedImage] beganAt:startPoint];
  }

  // --- Setup up the masks for the drag operation ---------------------
  if ([dragSource respondsToSelector:@selector(ignoreModifierKeysWhileDragging)]
      && [dragSource ignoreModifierKeysWhileDragging]) {
    operationMask = NSDragOperationIgnoresModifiers;
  }
  else {
    operationMask = 0;
    [self _updateOperationMask:theEvent];
  }
  if ([dragSource respondsToSelector:@selector(draggingSourceOperationMaskForLocal:)]) {
    dragMask = [dragSource draggingSourceOperationMaskForLocal:!destExternal];
  }
  else {
    dragMask = (NSDragOperationCopy | NSDragOperationLink |
                NSDragOperationGeneric | NSDragOperationPrivate);
  }
  
  // --- Setup the event loop ------------------------------------------
  [self _updateAndMoveImageToCorrectPosition];
  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.03];

  // --- Loop that handles all events during drag operation -----------
  while ([theEvent type] != NSLeftMouseUp) {
    [self _handleEventDuringDragging:theEvent];
    theEvent = [NSApp nextEventMatchingMask:eventMask
                                  untilDate:theDistantFuture
                                     inMode:NSEventTrackingRunLoopMode
                                    dequeue:YES];
  }

  // --- Event loop for drag operation stopped ------------------------
  [NSEvent stopPeriodicEvents];
  [self _updateAndMoveImageToCorrectPosition];

  NSDebugLLog(@"NSDragging", @"dnd ending %d\n", targetWindowRef);

  // --- Deposit the drop ----------------------------------------------
  if ((targetWindowRef != 0) &&
      ((targetMask & dragMask & operationMask) != NSDragOperationNone)) {
    [self _clearupWindow];
    [cursorBeforeDrag set];
    NSDebugLLog(@"NSDragging", @"sending dnd drop\n");
    if (!destExternal) {
      [self _sendLocalEvent:GSAppKitDraggingDrop
                     action:0
                   position:dragPosition
                  timestamp:[theEvent timestamp]
                   toWindow:destWindow];
    }
    else {
      [self sendExternalEvent:GSAppKitDraggingDrop
                       action:0
                     position:dragPosition
                    timestamp:[theEvent timestamp]
                     toWindow:targetWindowRef];
    }
    deposited = YES;
  }
  else {
    if (slideBack) {
      [self slideDraggedImageTo: slidePoint];
    }
    [self _clearupWindow];
    [cursorBeforeDrag set];
    deposited = NO;
  }

  if ([dragSource respondsToSelector:@selector(draggedImage:endedAt:operation:)]) {
    NSPoint point;
           
    point = [theEvent locationInWindow];
    // Convert from mouse cursor coordinate to image coordinate
    point.x -= offset.width;
    point.y -= offset.height;
    point = [[theEvent window] convertBaseToScreen: point];
    [dragSource draggedImage:[self draggedImage]
                     endedAt:point
                   operation:targetMask & dragMask & operationMask];
  }
  else if ([dragSource respondsToSelector:@selector(draggedImage:endedAt:deposited:)]) {
    NSPoint point;
          
    point = [theEvent locationInWindow];
    // Convert from mouse cursor coordinate to image coordinate
    point.x -= offset.width;
    point.y -= offset.height;
    point = [[theEvent window] convertBaseToScreen: point];
    [dragSource draggedImage:[self draggedImage]
                     endedAt:point
                   deposited:deposited];
  }
}

- (void)_handleEventDuringDragging:(NSEvent *)theEvent
{
  switch ([theEvent type])
    {
    case NSAppKitDefined:
      {
        GSAppKitSubtype	sub = [theEvent subtype];
        switch (sub)
          {
          case GSAppKitWindowMoved:
          case GSAppKitWindowResized:
          case GSAppKitRegionExposed:
            /*
             * Keep window up-to-date with its current position.
             */
            [NSApp sendEvent:theEvent];
            break;

          case GSAppKitDraggingStatus:
            NSDebugLLog(@"NSDragging", @"got GSAppKitDraggingStatus\n");
            if ((int)[theEvent data1] == targetWindowRef) {
              NSDragOperation newTargetMask = (NSDragOperation)[theEvent data2];
              if (newTargetMask != targetMask) {
                targetMask = newTargetMask;
                [self _setCursor];
              }
            }
            break;
          
          case GSAppKitDraggingFinished:
            NSLog(@"Internal: got GSAppKitDraggingFinished out of seq");
            break;

          case GSAppKitWindowFocusIn:
          case GSAppKitWindowFocusOut:
          case GSAppKitWindowLeave:
          case GSAppKitWindowEnter:
            break;

          default:
            NSDebugLLog(@"NSDragging", @"dropped NSAppKitDefined (%d) event", sub);
            break;
          }
      }
      break;

    case NSMouseMoved:
    case NSLeftMouseDragged:
    case NSLeftMouseDown:
    case NSLeftMouseUp:
      newPosition = [[theEvent window] convertBaseToScreen:[theEvent locationInWindow]];
      break;
    case NSFlagsChanged:
      if ([self _updateOperationMask: theEvent]) {
          // If flags change, send update to allow
          // destination to take note.
        if (destWindow) {
          [self _sendLocalEvent:GSAppKitDraggingUpdate
                         action:dragMask & operationMask
                       position:newPosition
                      timestamp:[theEvent timestamp]
                       toWindow:destWindow];
        }
        else {
          [self sendExternalEvent:GSAppKitDraggingUpdate
                           action:dragMask & operationMask
                         position:newPosition
                        timestamp:[theEvent timestamp]
                         toWindow:targetWindowRef];
        }
        [self _setCursor];
      }
      break;
    case NSPeriodic:
      newPosition = [NSEvent mouseLocation];
      if (newPosition.x != dragPosition.x || newPosition.y != dragPosition.y) {
        [self _updateAndMoveImageToCorrectPosition];
      }
      else if (destWindow) {
        [self _sendLocalEvent:GSAppKitDraggingUpdate
                       action:dragMask & operationMask
                     position:newPosition
                    timestamp:[theEvent timestamp]
                     toWindow:destWindow];
      }
      else {
        [self sendExternalEvent:GSAppKitDraggingUpdate
                         action:dragMask & operationMask
                       position:newPosition
                      timestamp:[theEvent timestamp]
                       toWindow:targetWindowRef];
      }
      break;
    default:
      NSLog(@"Internal: dropped event (%d) during dragging", (int)[theEvent type]);
    }
}
  
- (void) _updateAndMoveImageToCorrectPosition
{
  //--- Store old values -----------------------------------------------------
  NSWindow *oldDestWindow = destWindow;
  BOOL oldDestExternal = destExternal;
  int mouseWindowRef; 
  BOOL changeCursor = NO;
 
  //--- Move drag image to the new position -----------------------------------
  [self _moveDraggedImageToNewPosition];

  if ([dragSource respondsToSelector:@selector(draggedImage:movedTo:)])
    {
      [dragSource draggedImage: [self draggedImage] movedTo: dragPosition];
    }

  //--- Determine target window ---------------------------------------------
  destWindow = [self windowAcceptingDnDunder: dragPosition
                                   windowRef: &mouseWindowRef];

  // If we are not hovering above a window that we own
  // we are dragging to an external application.
  destExternal = (mouseWindowRef != 0) && (destWindow == nil);
            
  if (destWindow != nil)
    {
      dragPoint = [destWindow convertScreenToBase: dragPosition];
    }
            
  NSDebugLLog(@"NSDragging", @"mouse window %d (%@) at %@\n",
    mouseWindowRef, destWindow, NSStringFromPoint(dragPosition));
            
  //--- send exit message if necessary -------------------------------------
  if ((mouseWindowRef != targetWindowRef) && targetWindowRef)
    {
      /* If we change windows and the old window is dnd aware, we send an
         dnd exit */
      NSDebugLLog(@"NSDragging", @"sending dnd exit\n");
                
      if (oldDestWindow != nil)   
        {
          [self _sendLocalEvent: GSAppKitDraggingExit
                         action: dragMask & operationMask
                       position: NSZeroPoint
                      timestamp: dragSequence
                       toWindow: oldDestWindow];
        }  
      else
        {  
          [self sendExternalEvent: GSAppKitDraggingExit
                           action: dragMask & operationMask
                         position: NSZeroPoint
                        timestamp: dragSequence
                         toWindow: targetWindowRef];
        }
    }

  //  Reset drag mask when we switch from external to internal or back
  if (oldDestExternal != destExternal)
    {
      NSDragOperation newMask;

      if ([dragSource respondsToSelector:
                        @selector(draggingSourceOperationMaskForLocal:)])
        {
          newMask = [dragSource draggingSourceOperationMaskForLocal: !destExternal];
        }
      else
        {
          newMask = NSDragOperationCopy | NSDragOperationLink |
            NSDragOperationGeneric | NSDragOperationPrivate;
        }

      if (newMask != dragMask)
        {
          dragMask = newMask;
          changeCursor = YES;
        }
    }

  if (mouseWindowRef == targetWindowRef && targetWindowRef)  
    { 
      // same window, sending update
      NSDebugLLog(@"NSDragging", @"sending dnd pos\n");

      // FIXME: We should only send this when the destination wantsPeriodicDraggingUpdates
      if (destWindow != nil)
        {
          [self _sendLocalEvent: GSAppKitDraggingUpdate
                         action: dragMask & operationMask
                       position: dragPosition
                      timestamp: dragSequence
                       toWindow: destWindow];
        }
      else 
        {
          [self sendExternalEvent: GSAppKitDraggingUpdate 
                           action: dragMask & operationMask
                         position: dragPosition
                        timestamp: dragSequence
                         toWindow: targetWindowRef];
        }
    }
  else if (mouseWindowRef != 0)
    {
      // FIXME: We might force the cursor update here, if the
      // target wants to change the cursor.
      NSDebugLLog(@"NSDragging", @"sending dnd enter/pos\n");
      
      if (destWindow != nil)
        {
          [self _sendLocalEvent: GSAppKitDraggingEnter
                         action: dragMask
                       position: dragPosition
                      timestamp: dragSequence
                       toWindow: destWindow];
        }
      else
        {
          [self sendExternalEvent: GSAppKitDraggingEnter
                           action: dragMask
                         position: dragPosition
                        timestamp: dragSequence
                         toWindow: mouseWindowRef];
        }
    }

  if (targetWindowRef != mouseWindowRef)
    {
      targetWindowRef = mouseWindowRef;
      changeCursor = YES;
    }
  
  if (changeCursor)
    {
      [self _setCursor];
    }
}

- (void) _moveDraggedImageToNewPosition
{
  dragPosition = newPosition;
  [GSServerForWindow(_window) movewindow:
    NSMakePoint(newPosition.x - offset.width, newPosition.y - offset.height) 
    : [_window windowNumber]];
}

- (void) _slideDraggedImageTo: (NSPoint)screenPoint
                numberOfSteps: (int)steps
			delay: (float)delay
               waitAfterSlide: (BOOL)waitFlag
{
  /* If we do not need multiple redrawing, just move the image immediately
   * to its desired spot.
   */
  if (steps < 2)
    {
      newPosition = screenPoint;
      [self _moveDraggedImageToNewPosition];
    }
  else
    {
      [NSEvent startPeriodicEventsAfterDelay: delay withPeriod: delay];

      // Use the event loop to redraw the image repeatedly.
      // Using the event loop to allow the application to process
      // expose events.  
      while (steps)
        {
          NSEvent *theEvent = [NSApp nextEventMatchingMask: NSPeriodicMask
                                     untilDate: [NSDate distantFuture]
                                     inMode: NSEventTrackingRunLoopMode
                                     dequeue: YES];
          
          if ([theEvent type] != NSPeriodic)
            {
              NSDebugLLog (@"NSDragging", 
			   @"Unexpected event type: %d during slide",
                           (int)[theEvent type]);
            }
          newPosition.x = (screenPoint.x + ((float) steps - 1.0) 
			   * dragPosition.x) / ((float) steps);
          newPosition.y = (screenPoint.y + ((float) steps - 1.0) 
			   * dragPosition.y) / ((float) steps);

          [self _moveDraggedImageToNewPosition];
          steps--;
        }
      [NSEvent stopPeriodicEvents];
    }

  if (waitFlag)
    {
      [NSThread sleepUntilDate: 
	[NSDate dateWithTimeIntervalSinceNow: delay * 2.0]];
    }
}

@end

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
  NSInteger clickCount;
  
  if (target == nil || isSelectable == NO || [ev type] != NSLeftMouseDown) {
    return;
  }
  // NSLog(@"PathIcon: mouseDown: %@", paths);
  
  clickCount = [ev clickCount];
  modifierFlags = [ev modifierFlags];
  
  [(NXIconView *)[self superview] selectIcons:[NSSet setWithObject:self]
                                withModifiers:modifierFlags];
  
  // Dragging
  if ([target respondsToSelector:dragAction]) {
    // NSLog(@"[PathIcon-mouseDown]: DRAGGING");
    NSPoint   startPoint = [ev locationInWindow];
    NSInteger eventMask = NSLeftMouseDraggedMask | NSLeftMouseUpMask;
    NSInteger moveThreshold = [[[NXMouse new] autorelease] accelerationThreshold];
    
    while ([(ev = [_window nextEventMatchingMask:eventMask])
             type] != NSLeftMouseUp) {
      NSPoint endPoint = [ev locationInWindow];
      if (absolute_value(startPoint.x - endPoint.x) > moveThreshold ||
          absolute_value(startPoint.y - endPoint.y) > moveThreshold) {
        [target performSelector:dragAction withObject:self withObject:ev];
        return;
      }
    }
  }
  [_window makeFirstResponder:[longLabel nextKeyView]];
  // Clicking
  if (clickCount == 2) {
    // NSLog(@"PathIcon: 2 mouseDown: %@", paths);
    if ([target respondsToSelector:doubleAction]) {
      [target performSelector:doubleAction withObject:self];
    }
  }
  else if (clickCount == 1 || clickCount > 2) {
    // NSLog(@"PathIcon: 1 || >2 mouseDown: %@", paths);
    if (!doubleClickPassesClick && [self _waitForSecondMouseClick] != nil) {
      return;
    }
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

// - (void)dragImage:(NSImage*)anImage
//                at:(NSPoint)baseLocation
//            offset:(NSSize)initialOffset
//             event:(NSEvent*)event
//        pasteboard:(NSPasteboard*)pboard
//            source:(id)sourceObject
//         slideBack:(BOOL)slideFlag
// {
//   id dragView = [GSServerForWindow(self) dragInfo];

//   [NSApp preventWindowOrdering];
//   [dragView dragImage:anImage
//                    at:[_window convertBaseToScreen:baseLocation]
//                offset:initialOffset
//                 event:event
//            pasteboard:pboard
//                source:sourceObject
//             slideBack:slideFlag];
// }

// --- NSDraggingSource must have 'draggingSourceOperationMaskForLocal:'
// catched by enclosing view (PathView, ShelfView) and dispathed to
// 'delegate' - FileViewer 'draggingSourceOperationMaskForLocal:iconView:'
// method.

// --- NSDraggingDestination

#define PASTEBOARD [sender draggingPasteboard]

- (NSDragOperation)_draggingDestinationMaskForPaths:(NSArray *)sourcePaths
                                           intoPath:(NSString *)destPath
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString      *realPath;
  unsigned int  mask = (NSDragOperationCopy | NSDragOperationMove | 
                        NSDragOperationLink | NSDragOperationDelete);

  if ([fileManager isWritableFileAtPath:destPath] == NO) {
    NSLog(@"[FileViewer] %@ is not writable!", destPath);
    return NSDragOperationNone;
  }

  if ([[[fileManager fileAttributesAtPath:destPath traverseLink:YES]
         fileType] isEqualToString:NSFileTypeDirectory] == NO) {
    NSLog(@"[FileViewer] destination path `%@` is not a directory!", destPath);
    return NSDragOperationNone;
  }

  for (NSString *path in sourcePaths) {
    NSRange r;

    if ([fileManager isDeletableFileAtPath:path] == NO) {
      NSLog(@"[FileViewer] path %@ can not be deleted."
            @"Disabling Move and Delete operation.", path);
      mask ^= (NSDragOperationMove | NSDragOperationDelete);
    }

    if ([path isEqualToString:destPath]) {
      NSLog(@"[FileViewer] source and destination paths are equal "
            @"(%@ == %@)", path, destPath);
      return NSDragOperationNone;
    }

    if ([[path stringByDeletingLastPathComponent] isEqualToString:destPath]) {
      NSLog(@"[FileViewer] `%@` already exists in `%@`", path, destPath);
      return NSDragOperationNone;
    }
  }

  return mask;
}

// - Before the Image is Released
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSString *destPath;
  NSArray  *sourcePaths;

  sourcePaths = [PASTEBOARD propertyListForType:NSFilenamesPboardType];
  destPath = [paths objectAtIndex:0];
  
  NSLog(@"[PathIcon] draggingEntered: %@(%@) -> %@",
        [[sender draggingSource] className], [delegate className], destPath);

  if ([sender draggingSource] == self) {
    draggingMask = NSDragOperationNone;
  }
  else if (![sourcePaths isKindOfClass:[NSArray class]] 
	   || [sourcePaths count] == 0) {
    NSLog(@"[PathIcon] source path list is not NSArray or NSArray is empty!");
    draggingMask = NSDragOperationNone;
  }
  else {
    draggingMask = [self _draggingDestinationMaskForPaths:sourcePaths
                                                 intoPath:destPath];
  }
  
  if (draggingMask != NSDragOperationNone) {
    [self setIconImage:[[NSApp delegate] openIconForDirectory:destPath]];
  }

  return draggingMask;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSLog(@"[PathIcon] draggingUpdated: mask - %i", draggingMask);
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
  NSArray        *sourcePaths;
  NSString       *sourceDir;
  unsigned int   mask;
  unsigned int   opType = NSDragOperationNone;

  sourcePaths = [PASTEBOARD propertyListForType:NSFilenamesPboardType];
  // construct an array holding only the trailing filenames
  for (NSString *path in sourcePaths) {
    [filenames addObject:[path lastPathComponent]];
  }

  mask = [sender draggingSourceOperationMask];
  
  if (mask & NSDragOperationMove) {
    opType = MoveOperation;
  }
  else if (mask & NSDragOperationCopy) {
    opType = CopyOperation;
  }
  else if (mask & NSDragOperationLink) {
    opType = LinkOperation;
  }
  else {
    return NO;
  }

  sourceDir = [[sourcePaths objectAtIndex:0] stringByDeletingLastPathComponent];
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
