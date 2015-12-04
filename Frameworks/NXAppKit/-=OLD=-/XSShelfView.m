
#import "XSShelfView.h"

#import <math.h>
#import <AppKit/AppKit.h>
#import "XSShelfIcon.h"

@interface XSShelfView (Private)

- (unsigned int) updateDraggedIconToDrag: (id <NSDraggingInfo>) dragInfo;

@end

@implementation XSShelfView (Private)

- (unsigned int)updateDraggedIconToDrag:(id <NSDraggingInfo>)dragInfo
{
  NSSize     mySlotSize = [self slotSize];
  NSPoint    p = [self convertPoint:[dragInfo draggingLocation]
	   		   fromView:nil];
  XSIconSlot slot = XSMakeIconSlot(floorf(p.x / mySlotSize.width),
				   floorf(p.y / mySlotSize.height));
  XSIcon     *icon;

  if (slot.x >= (int)[self slotsWide])
    {
      [self removeIcon:draggedIcon];
      return NSDragOperationNone;
    }

  icon = [self iconInSlot:slot];

  if (icon == nil)
    {
      [self removeIcon:draggedIcon];
      [self putIcon:draggedIcon intoSlot:slot];
      return NSDragOperationCopy;
    }
  else if (icon != draggedIcon)
    {
      [self removeIcon:draggedIcon];
      return NSDragOperationNone;
    }
  else
    {
      return NSDragOperationCopy;
    }
}

@end

@implementation XSShelfView

- initWithFrame:(NSRect)r
{
  [super initWithFrame:r];

  [self setAllowsMultipleSelection:NO];
  [self setAllowsArrowsSelection:NO];
  [self setAllowsAlphanumericSelection:NO];
  [self setAutoAdjustsToFitIcons:NO];

  return self;
}

- (void)reconstructFromRepresentation:(NSDictionary *)aDict
{
  NSArray      *key;
  NSEnumerator *e;
  BOOL         notifyDelegateIconDraggedIn;

  notifyDelegateIconDraggedIn = 
    [delegate respondsToSelector:@selector(shelf:didAcceptIcon:inDrag:)];

  if (delegate == nil)
    {
      NSLog(_(@"XSShelfView: `-reconstructFromRepresentation:' "
	      @"requested but no delegate set"));

      return;
    }

  e = [[aDict allKeys] objectEnumerator];
  while ((key = [e nextObject]) != nil)
    {
      NSDictionary *userInfo;
      XSIconSlot   slot;
      XSShelfIcon  *icon;

      if (![key isKindOfClass:[NSArray class]] || [key count] != 2)
	{
	  continue;
	}
      if (![[key objectAtIndex:0] respondsToSelector:@selector(intValue)] ||
	  ![[key objectAtIndex:1] respondsToSelector:@selector(intValue)])
	{
	  continue;
	}

      slot = XSMakeIconSlot([[key objectAtIndex:0] intValue],
			    [[key objectAtIndex:1] intValue]);

      userInfo = [aDict objectForKey:key];
      if (![userInfo isKindOfClass:[NSDictionary class]])
	{
	  continue;
	}

      icon = [delegate shelf:self generateIconFromUserInfo:userInfo];
      if (icon)
	{
	  // behave as if we dragged it in, only that dragging info
	  if (notifyDelegateIconDraggedIn)
	    {
	      [delegate shelf:self didAcceptIcon:icon inDrag:nil];
	    }

	  [icon setUserInfo:userInfo];
	  [self putIcon:icon intoSlot:slot];
	}
    }
}

- (NSDictionary *)storableRepresentation
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSEnumerator        *e = [[self icons] objectEnumerator];
  XSShelfIcon         *icon;
  Class               nullClass = [NSNull class];

  while ((icon = [e nextObject]) != nil)
    {
      XSIconSlot slot;

      if ([icon isKindOfClass:nullClass])
	{
	  continue;
	}

      slot = [self slotForIcon:icon];

      if (slot.x == NSNotFound)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: _(@"XSShelfView: in "
                                @"`-storableRepresentation':"
				@" Unable to deteremine "
				@"the slot for an icon that"
				@" _must_ be present")];
	}

      [dict setObject:[icon userInfo]
	       forKey:[NSArray arrayWithObjects:
		  [NSNumber numberWithInt:slot.x],
		  [NSNumber numberWithInt:slot.y], nil]];
    }

  return [[dict copy] autorelease];
}

- (void)addIcon:(XSIcon *)anIcon
{
  [super addIcon:anIcon];
  [anIcon setEditable:NO];
}

- (void)putIcon:(XSIcon *)anIcon
       intoSlot:(XSIconSlot)aSlot
{
  [super putIcon:(XSIcon *)anIcon intoSlot:(XSIconSlot)aSlot];
  [anIcon setEditable:NO];
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSDictionary *userInfo;
  id           deleg = [self delegate];

  if (deleg == nil || 
      ![deleg respondsToSelector:@selector(shelf:userInfoForDrag:)])
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }

  userInfo = [deleg shelf:self userInfoForDrag:sender];
  if (userInfo == nil)
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }
  else
    {
      savedDragResult = YES;
    }

  ASSIGN(draggedIcon, [deleg shelf:self generateIconFromUserInfo:userInfo]);
  if (draggedIcon == nil)
    {
      savedDragResult = NO;
      return NSDragOperationNone;
    }

  // make sure the user info is in the icon
  [draggedIcon setUserInfo:userInfo];
  [draggedIcon setDimmed:YES];

  return [self updateDraggedIconToDrag:sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (savedDragResult == NO)
    {
      return NSDragOperationNone;
    }

  return [self updateDraggedIconToDrag:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [self removeIcon:draggedIcon];
  DESTROY(draggedIcon);
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  [draggedIcon setDimmed:NO];
  DESTROY(draggedIcon);

  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if ([delegate respondsToSelector:@selector(shelf:didAcceptIcon:inDrag:)])
    {
      [delegate shelf:self didAcceptIcon:draggedIcon inDrag:sender];
    }
}

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
