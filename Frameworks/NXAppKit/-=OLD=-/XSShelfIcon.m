
#import <AppKit/AppKit.h>

#import "XSShelfIcon.h"

@implementation XSShelfIcon

- (void)dealloc
{
  TEST_RELEASE(userInfo);

  [super dealloc];
}

- (void)setUserInfo:(NSDictionary *)ui
{
  ASSIGN(userInfo, ui);
}

- (NSDictionary *)userInfo
{
  return userInfo;
}

- (void)mouseDown:(NSEvent *)ev
{
  int clickCount;

  if (target == nil || isSelectable == NO || [ev type] != NSLeftMouseDown)
    {
      return;
    }

  [self setSelected:YES];
    
  clickCount = [ev clickCount];
  modifierFlags = [ev modifierFlags];

  NSLog(@"XSShelfIcon: mouseDown: %i", clickCount);

  // Dragging
  if ([target respondsToSelector:dragAction])
    {
      NSLog(@"XSShelfIcon: DRAGGING");

      NSPoint startPoint = [ev locationInWindow];
      NSPoint endPoint;
      unsigned int mask = NSLeftMouseDraggedMask | NSLeftMouseUpMask;
      NSWindow *window = [self window];

//    while ([(ev = [[self window] nextEventMatchingMask:NSAnyEventMask]) type]

      while ([(ev = [window nextEventMatchingMask:mask 
					 untilDate:[NSDate distantFuture]
					    inMode:NSEventTrackingRunLoopMode
					   dequeue:YES])
	     type] != NSLeftMouseUp)
	{
	  endPoint = [ev locationInWindow];

	  if (absolute_value(startPoint.x - endPoint.x) > 5 ||
	      absolute_value(startPoint.y - endPoint.y) > 5)
	    {
	      [target performSelector:dragAction
			   withObject:self
			   withObject:ev];
	      return;
	    }
	}
    }

  // Clicking
  if (clickCount == 2)
    {
      NSLog(@"XSShelfIcon: CLICK=2");
      [self setSelected:NO];
      if ([target respondsToSelector:doubleAction])
	{
     	  [target performSelector:doubleAction withObject:self];
	}
      return;
    }
  else if (clickCount == 1)
    {
      unsigned  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
		     	     | NSPeriodicMask | NSOtherMouseUpMask 
			     | NSRightMouseUpMask);
      NSEvent   *event = nil;

      NSLog(@"XSShelfIcon: CLICK=1");
      
      event = [[self window]
	nextEventMatchingMask:eventMask
		    untilDate:[NSDate dateWithTimeIntervalSinceNow:0.30]
		       inMode:NSEventTrackingRunLoopMode
		      dequeue:NO];
      // Double clicked
      if (event != nil)
	{
	  return;
	}

      [self setSelected:NO];
      if ([target respondsToSelector:action])
	{
      	  [target performSelector:action withObject:self];
	}
    }

}

- (BOOL)becomeFirstResponder
{
  return NO;
}

@end
