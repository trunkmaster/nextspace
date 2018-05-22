/* All Rights reserved */

#import "Recycler.h"
#import <GNUstepGUI/GSDisplayServer.h>

@implementation	RecyclerIconWindow

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
  
  // if ([[NSUserDefaults standardUserDefaults] 
  //       boolForKey: @"GSAllowWindowsOverIcons"] == YES)
    _windowLevel = NSDockWindowLevel;
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
  NSLog(@"Recycler: RMB click!");
  [NSApp rightMouseDown:theEvent];
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
  NSImage	*tileImage;
  NSSize	iconSize = NSMakeSize(64,64);

  // iconSize = GSGetIconSize();
  /* _appIconInit will set our image */
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

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
}

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

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize = NSMakeSize(64,64);
  // NSSize iconSize = GSGetIconSize();
  
  NSLog(@"Recycler: drawRect!");
  
  [tileCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
  		   inView:self];
  [dragCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)
		   inView:self];
  
  if ([NSApp isHidden])
    {
      NSRectEdge mySides[] = {NSMinXEdge, NSMinYEdge, NSMaxXEdge, NSMaxYEdge};
      CGFloat    myGrays[] = {NSBlack, NSWhite, NSWhite, NSBlack};
      NSDrawTiledRects(NSMakeRect(4, 4, 3, 2), rect, mySides, myGrays, 4);
    }
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self registerForDraggedTypes:[NSArray arrayWithObjects:
                                           NSFilenamesPboardType, nil]];
  return self;
}

- (void)mouseDown:(NSEvent*)theEvent
{
  NSLog(@"Recycler View: mouse down!");

  if ([theEvent clickCount] >= 2)
    {
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
                  && aWin != [self window] 
                  && ([aWin styleMask] & NSMiniWindowMask) == 0)
                {
                  [aWin orderFrontRegardless];
                }
            }
	
          if ([NSApp isActive] == YES)
            {
              if ([NSApp keyWindow] != nil)
                {
                  [[NSApp keyWindow] orderFront: self];
                }
              else if ([NSApp mainWindow] != nil)
                {
                  [[NSApp mainWindow] makeKeyAndOrderFront: self];
                }
              else
                {
                  /* We need give input focus to some window otherwise we'll 
                     never get keyboard events. FIXME: doesn't work. */
                  NSWindow *menu_window= [[NSApp mainMenu] window];
                  NSDebugLLog(@"Focus",
                              @"No key on activation - make menu key");
                  [GSServerForWindow(menu_window) setinputfocus:
                                      [menu_window windowNumber]];
                }
            }
	  
          RELEASE(windows);
        }
      [NSApp unhide: self]; // or activate or do nothing.
    }
  else
    {
      NSPoint	lastLocation;
      NSPoint	location;
      NSUInteger eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask
	| NSPeriodicMask | NSOtherMouseUpMask | NSRightMouseUpMask;
      NSDate	*theDistantFuture = [NSDate distantFuture];
      BOOL	done = NO;

      lastLocation = [theEvent locationInWindow];
      [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];

      while (!done)
	{
	  theEvent = [NSApp nextEventMatchingMask: eventMask
					untilDate: theDistantFuture
					   inMode: NSEventTrackingRunLoopMode
					  dequeue: YES];
	
	  switch ([theEvent type])
	    {
            case NSRightMouseUp:
            case NSOtherMouseUp:
            case NSLeftMouseUp:
	      /* any mouse up means we're done */
              done = YES;
              break;
            case NSPeriodic:
              location = [_window mouseLocationOutsideOfEventStream];
              if (NSEqualPoints(location, lastLocation) == NO)
                {
                  NSPoint	origin = [_window frame].origin;

                  origin.x += (location.x - lastLocation.x);
                  origin.y += (location.y - lastLocation.y);
                  [_window setFrameOrigin: origin];
                }
              break;

            default:
              break;
	    }
	}
      [NSEvent stopPeriodicEvents];
    }
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

- (void)setImage:(NSImage *)anImage
{
  NSImage *imgCopy = [anImage copy];

  if (imgCopy)
    {
      NSSize imageSize = [imgCopy size];

      [imgCopy setScalesWhenResized: YES];
      [imgCopy setSize: scaledIconSizeForSize(imageSize)];
    }
  [dragCell setImage: imgCopy];
  RELEASE(imgCopy);
  [self setNeedsDisplay: YES];
}

@end
