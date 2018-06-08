//
// Workspace Manager Shelf view
//   Holds icons for dirs and applications.
//   Holds icons of multiple selections temporarely
//

#import <math.h>
#import <AppKit/AppKit.h>

#import "PathIcon.h"
#import "ShelfView.h"

NXIconSlot lastSlotDragEntered;

@interface ShelfView (Private)

- (unsigned int)updateDraggedIconToDrag:(id <NSDraggingInfo>)dragInfo;

@end

@implementation ShelfView (Private)

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

@end

@implementation ShelfView //: NXIconView

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
      NSLog(@"ShelfView: `-reconstructFromRepresentation:' "
            @"requested but no delegate was set");
      
      return;
    }

  e = [[aDict allKeys] objectEnumerator];
  while ((key = [e nextObject]) != nil)
    {
      NSArray    *paths;
      NXIconSlot slot;
      PathIcon   *icon;

      if (![key isKindOfClass:[NSArray class]] || [key count] != 2)
	{
	  continue;
	}
      if (![[key objectAtIndex:0] respondsToSelector:@selector(intValue)] ||
	  ![[key objectAtIndex:1] respondsToSelector:@selector(intValue)])
	{
	  continue;
	}

      slot = NXMakeIconSlot([[key objectAtIndex:0] intValue],
			    [[key objectAtIndex:1] intValue]);
      
      paths = [aDict objectForKey:key];
      if (![paths isKindOfClass:[NSArray class]])
	{
	  continue;
	}

      icon = [delegate shelf:self createIconForPaths:paths];
      if (icon)
	{
	  // behave as if we dragged it in, only that dragging info
	  if (notifyDelegateIconDraggedIn)
	    {
	      [delegate shelf:self didAcceptIcon:icon inDrag:nil];
	    }

	  [icon setPaths:paths];
	  [self putIcon:icon intoSlot:slot];
	}
    }
}

- (NSDictionary *)storableRepresentation
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSEnumerator        *e = [[self icons] objectEnumerator];
  PathIcon            *icon;
  Class               nullClass = [NSNull class];

  while ((icon = [e nextObject]) != nil)
    {
      NXIconSlot slot;

      if ([icon isKindOfClass:nullClass] || [[icon paths] count] > 1)
	{
	  continue;
	}

      slot = [self slotForIcon:icon];

      if (slot.x == NSNotFound)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"ShelfView: in `-storableRepresentation':"
                       @" Unable to deteremine the slot for an icon that"
                       @" _must_ be present"];
	}

      [dict setObject:[icon paths]
	       forKey:[NSArray arrayWithObjects:
                                 [NSNumber numberWithInt:slot.x],
                                 [NSNumber numberWithInt:slot.y], nil]];
    }

  return [[dict copy] autorelease];
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

//============================================================================
// Drag and drop
//============================================================================

// --- NSDraggingDestination

// - Before the Image is Released

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSArray      *paths;
  NSDictionary *info;
  NXIconSlot   iconSlot;

  NSLog(@"[ShelfView] -draggingEntered (source:%@)",
        [[sender draggingSource] className]);

  if (delegate == nil)
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

  ASSIGN(draggedIcon, [delegate shelf:self createIconForPaths:paths]);
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

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSLog(@"[ShelfView] draggingUpdated");
  if (savedDragResult == NO)
    {
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
