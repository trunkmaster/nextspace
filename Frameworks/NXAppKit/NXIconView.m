/**
   @class NXIconView
   @brief This class is a view that allows the comfortable display of icons.

   You use instances of NXIconView (or simply icon views) to stack icons
   into matrix-like layouts. An icon view is composed of slots, each
   containing one icon. Icons in an icon view need not be linearly following -
   there can be empty slots (holes) in it. The icon view handles the
   correct and efficient layout of icons inside itself.

   The layout starts at the upper left corner (slot 0x0) and continues
   to the right-bottom.

   @author Saso Kiselkov, Sergii Stoian
*/

#import "NXIconView.h"

#import <math.h>
#import <AppKit/AppKit.h>

#import "NXIcon.h"
#import "NXIconLabel.h"

static NSSize defaultSlotSize = {100, 80};
static int useDottedRect = -1;
static float defaultMaximumCollapsedLabelWidthSpace = 20;

static inline NSRect PositiveRect(NSRect r)
{
  if (r.size.width < 0) {
      r.size.width = -r.size.width;
      r.origin.x -= r.size.width;
  }
  if (r.size.height < 0) {
      r.size.height = -r.size.height;
      r.origin.y -= r.size.height;
  }

  return r;
}

static inline NSPoint PointForSlot(NSSize slotSize, NXIconSlot slot)
{
  return NSMakePoint(floorf(slot.x * slotSize.width + slotSize.width / 2),
		     floorf(slot.y * slotSize.height + slotSize.height / 2));
}

static inline unsigned int IndexFromSlot(unsigned slotsWide, NXIconSlot slot)
{
  return (slot.x + slotsWide * slot.y);
}

static inline NXIconSlot SlotFromIndex(unsigned slotsWide, unsigned i)
{
  unsigned int x;

  x = i % slotsWide;

  return NXMakeIconSlot(x, (i - x) / slotsWide);
}

// NSString * NXIconViewDidChangeSelectionNotification =
//              @"NXIconViewDidChangeSelectionNotification";

/// Private NXIconView methods.
@interface NXIconView (Private)

/* Removes all icons from the superview and puts them at recomputed
   positions where they belong. This method is invoked e.g. after a
   slot size change, when the icon positions need to be updated. */
- (void)relayoutIcons;

/* Does a reverse search in the receiver's list of icons and removes
   any trailing holes and if autoAdjustsToFitIcons is YES, then it
   also invokes adjustToFitIcons. */
- (void)checkWrapDown;

/* Invokes updateSelectionWithIcons:modifierFlags:with a single icon. */
- (void)updateSelectionWithIcon:(NXIcon *)anIcon
       		  modifierFlags:(unsigned)flags;

/* Changes the selection of icons.

   This method is invoked every time a selection change occurs.
     
   @param someIcons A set of icons with which to do the change.
   @param flags Keyboard modifier flags which change the operation
   type. See NXIconSelectionMode. */
- (void)updateSelectionWithIcons:(NSSet *)someIcons
       		   modifierFlags:(unsigned)flags;

@end

@implementation NXIconView

+ (void)setDefaultSlotSize:(NSSize)aSize
{
  defaultSlotSize = aSize;
}

+ (NSSize)defaultSlotSize
{
  return defaultSlotSize;
}

+ (void)setDefaultMaximumCollapsedLabelWidthSpace:(float) aValue
{
  defaultMaximumCollapsedLabelWidthSpace = aValue;
}

+ (float)defaultMaximumCollapsedLabelWidthSpace
{
  return defaultMaximumCollapsedLabelWidthSpace;
}

//------------------------------------------------------------------------------
// Initialization and deallocation
//------------------------------------------------------------------------------
- initWithFrame:(NSRect)r
{
  [super initWithFrame:r];

  icons = [NSMutableArray new];
  selectedIcons = [NSMutableSet new];

  autoAdjustsToFitIcons = YES;
  adjustsToFillEnclosingScrollView = YES;
  fillWithHoleWhenRemovingIcon = YES;
  isSlotsTallFixed = NO;

  slotSize = defaultSlotSize;

  selectable = YES;
  allowsMultipleSelection = YES;
  allowsArrowsSelection = YES;
  allowsAlphanumericSelection = YES;

  slotsWide = roundf(r.size.width / slotSize.width);
  if (slotsWide == 0)
    slotsWide = 1;

  lastIcon = NXMakeIconSlot(-1, 0);

  selectedIconSlot.x = -1;

  maximumCollapsedLabelWidthSpace =
    defaultMaximumCollapsedLabelWidthSpace;

  return self;
}

- initSlotsWide:(unsigned int)newSlotsWide
{
  return [self initWithFrame:
                 NSMakeRect(0, 0, newSlotsWide * defaultSlotSize.width, 0)];
}

- (void)dealloc
{
  TEST_RELEASE(icons);
  TEST_RELEASE(selectedIcons);

  [super dealloc];
}

//------------------------------------------------------------------------------
// Changing contents (icons add/removal)
//------------------------------------------------------------------------------
- (void)fillWithIcons:(NSArray *)someIcons
{
  BOOL         saved = autoAdjustsToFitIcons;
  NSEnumerator *e;
  NXIcon       *icon;

  autoAdjustsToFitIcons = NO;
  [self removeAllIcons];

  e = [someIcons objectEnumerator];
  while ((icon = [e nextObject]) != nil)
    {
      [self addIcon:icon];
    }

  autoAdjustsToFitIcons = saved;
  if (autoAdjustsToFitIcons)
    {
      [self adjustToFitIcons];
    }
}

- (void)addIcon:(NXIcon *)anIcon
{
  NXIconSlot slot;
  NSUInteger i, n;

  slot.x = 0;
  slot.y = 0;

  if (numHoles != 0)
    {
      // find a free spot - there _must_ be something, because
      // we remember to have some holes somewhere
      // NSLog(@"[NXIconView] icons: %@", icons);
      for (i = 0, n = [icons count]; i < n; i++)
	{
	  if ([[icons objectAtIndex:i] isKindOfClass:[NSNull class]])
	    {
	      slot = SlotFromIndex(slotsWide, i);
	      break;
	    }
	}
      if (i >= n)
	{
	  [NSException raise:NSInternalInconsistencyException
		      format:_(@"NXIconView:tried to pack "
		       	       @"a icon into free slots, but "
	       		       @"none were found (even though "
       			       @"I thought there were!)")];
	}
      // NSLog(@"[NXIconView] found hole at index: %lu", i);
    }
  else
    {
      // NSLog(@"[NXIconView] no holes! lastIcon.x=%i, lastIcon.y=%i",
      //       lastIcon.x, lastIcon.y);
      slot = lastIcon;
      slot.x++;
      if (slot.x >= slotsWide)
	{
          if (slotsTall == 0)
            slotsTall++;
	  slot.x = 0;
	  slot.y++;
	}
    }

  // NSLog(@"Put icon '%@' into slot {%i, %i}", [anIcon labelString],
  //       slot.x, slot.y);
  
  [self putIcon:anIcon intoSlot:slot];
}

- (void)putIcon:(NXIcon *)anIcon
       intoSlot:(NXIconSlot)aSlot
{
  unsigned index;

  // constrain the x coord to the current width
  if (aSlot.x >= (int)slotsWide)
    {
      aSlot.x = slotsWide-1;
    }

  if (lastIcon.x <= aSlot.x || lastIcon.y <= aSlot.y)
    {
      lastIcon = aSlot;
    }

  index = IndexFromSlot(slotsWide, aSlot);

  if (index >= [icons count])
    {
      // enlarge - the slot is greater than our current height
      unsigned i;

      slotsTall = aSlot.y + 1;
      for (i = [icons count]; i < index; i++)
        {
          [icons addObject:[NSNull null]];
          numHoles++;
        }
      [icons addObject:anIcon];
      if (autoAdjustsToFitIcons)
        {
          [self adjustToFitIcons];
        }
    }
  else
    {
      // put into an existing slot
      NXIcon *oldIcon;

      oldIcon = [icons objectAtIndex:index];
      if ([oldIcon isKindOfClass:[NSNull class]])
	{
	  numHoles--;
	}
      else
	{
	  [oldIcon removeFromSuperview];
	}

      [icons replaceObjectAtIndex:index withObject:anIcon];
    }

  [anIcon setTarget:self];
  [anIcon setAction:@selector(iconClicked:)];
  [anIcon setDragAction:@selector(iconDragged:event:)];
  [anIcon setDoubleAction:@selector(iconDoubleClicked:)];
  
  [anIcon putIntoView:self
	      atPoint:PointForSlot(slotSize, aSlot)];
  [anIcon setMaximumCollapsedLabelWidth:
            slotSize.width - maximumCollapsedLabelWidthSpace];
}

- (void)removeIcon:(NXIcon *)anIcon
{
  NSUInteger i;

//  NSLog(@"[NXIconView -removeIcon] icons count: %i", [icons count]);

//  for (i=0; i<[icons count]; i++)
//    {
//      NSLog(@"+ %@", [[icons objectAtIndex:i] labelString]);
//    }

  i = [icons indexOfObjectIdenticalTo:anIcon];
  if (i == NSNotFound)
    {
      NSLog(@"[NXIconView -removeIcon] failed: Icon not found!");
      return;
    }

  [selectedIcons removeObject:anIcon];
  [anIcon removeFromSuperview];
  if (fillWithHoleWhenRemovingIcon)
    {
      [icons replaceObjectAtIndex:i withObject:[NSNull null]];
      numHoles++;
    }
  else
    {
      [icons removeObjectAtIndex:i];
    }

  // [self checkWrapDown];
}

- (void)removeIcons:(NSArray *)someIcons
{
  NSEnumerator *e;
  NXIcon       *icon;
  BOOL         saved;

  saved = autoAdjustsToFitIcons;
  autoAdjustsToFitIcons = NO;
  e = [someIcons objectEnumerator];
  while ((icon = [e nextObject]) != nil)
    {
      [self removeIcon:icon];
    }

  autoAdjustsToFitIcons = saved;
  if (autoAdjustsToFitIcons)
    {
      [self adjustToFitIcons];
    }
}

- (void)removeIconInSlot:(NXIconSlot)aSlot
{
  unsigned i;
  NXIcon   *icon;

  if (aSlot.x >= (int) slotsWide)
    {
      return;
    }

  i = IndexFromSlot(slotsWide, aSlot);
  if (i >= [icons count])
    {
      return;
    }

  icon = [icons objectAtIndex:i];

  if (![icon isKindOfClass:[NXIcon class]])
    {
      return;
    }

  [self removeIcon:icon];
}

- (void)removeAllIcons
{
  [icons makeObjectsPerform:@selector(removeFromSuperview)];
  [icons removeAllObjects];
  [selectedIcons removeAllObjects];

  slotsTall = 0;
  numHoles = 0;
  lastIcon = NXMakeIconSlot(-1, 0);

  selectedIconSlot.x = -1;
  selectedIconSlot.y = -1;

  if (autoAdjustsToFitIcons)
    {
      [self adjustToFitIcons];
    }
}

- (void)setFillsWithHoleWhenRemovingIcon:(BOOL)flag
{
  fillWithHoleWhenRemovingIcon = flag;
}

- (BOOL)fillsWithHoleWhenRemovingIcon
{
  return fillWithHoleWhenRemovingIcon;
}

//------------------------------------------------------------------------------
// Access to icons
//------------------------------------------------------------------------------
- (NSArray *)icons
{
  NSMutableArray *array = [NSMutableArray array];
  NSEnumerator   *e = [icons objectEnumerator];
  NXIcon         *icon;
  Class          iconClass = [NXIcon class];

  while ((icon = [e nextObject]) != nil)
    {
      if ([icon isKindOfClass:iconClass])
	{
      	  [array addObject:icon];
	}
    }

  return [[array copy] autorelease];
}

- (NXIcon *)iconInSlot:(NXIconSlot)aSlot
{
  NXIcon * icon;
  unsigned i;

  if (aSlot.x >= (int) slotsWide)
    return nil;

  i = IndexFromSlot(slotsWide, aSlot);

  if (i >= [icons count])
    return nil;

  icon = [icons objectAtIndex:i];
  if ([icon isKindOfClass:[NSNull class]])
    return nil;
  else
    return icon;
}

- (NXIconSlot)slotForIcon:(NXIcon *)anIcon
{
  NSUInteger i = [icons indexOfObjectIdenticalTo:anIcon];

  if (i == NSNotFound)
    return NXMakeIconSlot(-1, -1);
  else
    return SlotFromIndex(slotsWide, i);
}

//------------------------------------------------------------------------------
// Sizes and autosizing
//------------------------------------------------------------------------------
- (void)setSlotSize:(NSSize)newSlotSize
{
  CGFloat    viewWidth = 0.0;
  NSUInteger newSlotsWide = 0;;

  slotSize = newSlotSize;

  // NSLog(@"[NXIconView setSlotSize]: view width: %0.f slot width: %0.f "
  //       @"enclosing view:%@",
  //       frame.size.width, slotSize.width,
  //       [[self superview] className]);
  
  // Determine how much slots can contain superview's width.
  if (_autoresizingMask & NSViewWidthSizable)
    {
      NSLog(@"[NXIconView setSlotSize] slotsWide from superview width");
      viewWidth = [[self superview] bounds].size.width;
    }
  else
    {
      NSLog(@"[NXIconView setSlotSize] own width from slotsWide");
      viewWidth = slotsWide * slotSize.width;
    }

  newSlotsWide = floorf(viewWidth / slotSize.width);
  [self setSlotsWide:newSlotsWide];
  
  NSLog(@"[NXIconView] slotsWide: %lu view width:%0.f",
        newSlotsWide, [self frame].size.width);

  // Update collapsed icon labels width
  {
    NXIcon       *icon;
    NSEnumerator *e = [icons objectEnumerator];
    Class        iconClass = [NXIcon class];

    while ((icon = [e nextObject]) != nil)
      {
        if ([icon isKindOfClass:iconClass])
          {
            [icon setMaximumCollapsedLabelWidth:
                    slotSize.width - maximumCollapsedLabelWidthSpace];
          }
      }
  }
}

- (NSSize)slotSize
{
  return slotSize;
}

- (void)setMaximumCollapsedLabelWidthSpace:(float)aValue
{
  NSEnumerator *e;
  NXIcon       *icon;
  float        newWidth;
  Class        iconClass;

  maximumCollapsedLabelWidthSpace = aValue;
  newWidth = slotSize.width - maximumCollapsedLabelWidthSpace;

  iconClass = [NXIcon class];

  e = [icons objectEnumerator];
  while ((icon = [e nextObject]) != nil)
    {
      if ([icon isKindOfClass:iconClass])
	{
	  [icon setMaximumCollapsedLabelWidth:newWidth];
	}
    }
}

- (float)maximumCollapsedLabelWidthSpace
{
  return maximumCollapsedLabelWidthSpace;
}

- (void)setAutoAdjustsToFitIcons:(BOOL)flag
{
  autoAdjustsToFitIcons = flag;
}

- (BOOL)autoAdjustsToFitIcons
{
  return autoAdjustsToFitIcons;
}

- (void)setAutoAdjustsToFillEnclosingScrollView:(BOOL)flag
{
  adjustsToFillEnclosingScrollView = flag;
}

- (BOOL)autoAdjustsToFillEnclosingScrollView
{
  return adjustsToFillEnclosingScrollView;
}

// Override of NSView method.
// when we are resized update the slotsWide ivar, adjust if necessary and
// relayout the icons accordingly
- (void)resizeWithOldSuperviewSize:(NSSize)s
{
  [super resizeWithOldSuperviewSize:s];

  // NSLog(@"[NXIconView -resizeWithOldSuperviewSize] width: %0.f slot width: %0.f", 
  //       [self frame].size.width, slotSize.width);

  if (_autoresizingMask & NSViewWidthSizable)
    {
      slotsWide = floorf([self frame].size.width / slotSize.width);
    }
  else
    {
      slotsWide = ceilf([self frame].size.width / slotSize.width);
    }

  slotsTall = ceilf([self frame].size.height / slotSize.height);
  
  if (autoAdjustsToFitIcons)
    {
      [self adjustToFitIcons];
    }
  else
    {
      [self adjustFrame];
    }
  
  [self relayoutIcons];
}

- (void)adjustToFitIcons
{
  NSRect newFrame = [self frame];

  // NSLog(@">>>>[NXIconView adjustToFitIcons]<<<");

  // The number of columns
  if (adjustsToFillEnclosingScrollView == YES
      && [self enclosingScrollView] != nil)
    {
      NSRect r = [[[self enclosingScrollView] contentView] frame];

      slotsWide = floorf(r.size.width / slotSize.width);
    }
  
  // The number of rows
  if (!isSlotsTallFixed)
    {
      slotsTall = ceilf((float) [icons count] / slotsWide);
    }

  // Height of icon view
  newFrame.size.height = slotSize.height * slotsTall;
  // Width of icon view
  newFrame.size.width = slotSize.width * slotsWide;

  // NSLog(@"[NXIconView] icons: %lu slots: %i slot.width: %f"  \
  //       " width: %f super width: %f",
  //       [icons count], slotsWide, slotSize.width, 
  //       newFrame.size.width,
  //       [[[self enclosingScrollView] contentView] frame].size.width);

  [self setFrame:newFrame];
  [self relayoutIcons];
}

// Honours autoresizingMask, doesn't honour adjustsToFillEnclosingScrollView
- (void)adjustFrame
{
  NSRect newFrame = [self frame];

  // NSLog(@">>>>[NXIconView adjustFrame]<<<");

  if (_autoresizingMask & NSViewWidthSizable)
    {
      newFrame.size.width = [[self superview] bounds].size.width;
    }
  else
    {
      newFrame.size.width = slotSize.width * slotsWide;
    }

  if (_autoresizingMask & NSViewHeightSizable)
    {
      newFrame.size.height = [[self superview] bounds].size.height;
    }
  else
    {
      newFrame.size.height = slotSize.height * slotsTall;
    }

  [self setFrame:newFrame];
  [self relayoutIcons];
}

- (void)setSlotsWide:(unsigned int)newSlotsWide
{
  NSRect frame;

  if (newSlotsWide == 0)
    {
      [NSException raise:NSInvalidArgumentException
  		  format:_(@"NXIconView `-setSlotsWide:' passed "
 			   @"zero width argument")];
    }

  // NSLog(@"[NXIconView] setSlotsWide:%i", newSlotsWide);

  slotsWide = newSlotsWide;
  
  if (autoAdjustsToFitIcons)
    {
      [self adjustToFitIcons];
    }
  else
    {
      [self adjustFrame];
    }
}

- (unsigned int)slotsWide
{
  return slotsWide;
}

- (void)setSlotsTall:(unsigned int)newSlotsTall
{
  slotsTall = newSlotsTall;
}

- (void)setSlotsTallFixed:(BOOL)isFixed
{
  isSlotsTallFixed = isFixed;
}

- (unsigned int)slotsTall
{
  return slotsTall;
}

//------------------------------------------------------------------------------
// Selection
//------------------------------------------------------------------------------

- (void)setSelectable:(BOOL)flag
{
  selectable = flag;
  if (selectable == NO)
    allowsMultipleSelection = NO;
}

- (BOOL)isSelectable
{
  return selectable;
}

- (void)setAllowsMultipleSelection:(BOOL)flag
{
  allowsMultipleSelection = flag;
}

- (BOOL)allowsMultipleSelection
{
  return allowsMultipleSelection;
}

- (void)setAllowsArrowsSelection:(BOOL)flag
{
  allowsArrowsSelection = flag;
}

- (BOOL)allowsArrowsSelection
{
  return allowsArrowsSelection;
}

- (void)setAllowsAlphanumericSelection:(BOOL)flag
{
  allowsAlphanumericSelection = flag;
}

- (BOOL)allowsAlphanumericSelection
{
  return allowsAlphanumericSelection;
}

//------------------------------------------------------------------------------
// Target and actions
//------------------------------------------------------------------------------
- (void)setSendsDoubleActionOnReturn:(BOOL)flag
{
  sendsDoubleActionOnReturn = flag;
}

- (BOOL)sendsDoubleActionOnReturn
{
  return sendsDoubleActionOnReturn;
}

- (void)mouseDown:(NSEvent *)ev
{
  NSPoint      p;
  NSEnumerator *e;
  NXIcon       *icon;
  NSMutableSet *sel;
  unsigned     modifierFlags;

  NSLog(@"NXIV:mouseDown");

  if ([ev clickCount] >= 2)
    return;

  // in case we don't allow multiple selections and we've been
  // clicked, just deselect all icons and return
  if (allowsMultipleSelection == NO)
    {
      [self updateSelectionWithIcons:nil modifierFlags:0];
      return;
    }

  //        haveEnclosingScrollView = ([self enclosingScrollView] != nil);

  p = [self convertPoint:[ev locationInWindow] fromView:nil];
  modifierFlags = [ev modifierFlags];

  selectionRect.origin.x = p.x;
  selectionRect.origin.y = p.y;
  selectionRect.size.width = 0;
  selectionRect.size.height = 0;
  drawSelectionRect = YES;

  while ([(ev = [[self window] nextEventMatchingMask:NSAnyEventMask]) type] 
	 != NSLeftMouseUp)
    {
      if ([ev type] == NSLeftMouseDragged)
	{
	  NSRect oldRect = selectionRect;
	  NSRect redraw1, redraw2;

	  p = [self convertPoint:[ev locationInWindow]
			fromView:nil];

	  [self autoscroll:ev];

	  selectionRect.size.width = p.x - selectionRect.origin.x;
	  selectionRect.size.height = p.y - selectionRect.origin.y;

	  redraw1 = PositiveRect(oldRect);
	  redraw2 = PositiveRect(selectionRect);

	  // only redraw the lines in order to avoid "flashing"
	  // effects on the icons
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw1.origin.x, redraw1.origin.y,
                             redraw1.size.width, 1)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw1.origin.x, redraw1.origin.y,
                             1, redraw1.size.height)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw1.origin.x + redraw1.size.width - 1,
                             redraw1.origin.y, 1, redraw1.size.height)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw1.origin.x,
                             redraw1.origin.y + redraw1.size.height-1,
                             redraw1.size.width, 1)];

	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw2.origin.x, redraw2.origin.y,
                             redraw2.size.width, 1)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw2.origin.x, redraw2.origin.y,
                             1, redraw2.size.height)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw2.origin.x + redraw2.size.width - 1,
                             redraw2.origin.y, 1, redraw2.size.height)];
	  [self setNeedsDisplayInRect:
                  NSMakeRect(redraw2.origin.x,
                             redraw2.origin.y + redraw2.size.height-1,
                             redraw2.size.width, 1)];
	}
    }

  drawSelectionRect = NO;
  [self setNeedsDisplay:YES];

  if (selectionRect.size.width < 0)
    {
      selectionRect.size.width = -selectionRect.size.width;
      selectionRect.origin.x -= selectionRect.size.width;
    }
  if (selectionRect.size.height < 0)
    {
      selectionRect.size.height = -selectionRect.size.height;
      selectionRect.origin.y -= selectionRect.size.height;
    }

  sel = [[NSMutableSet new] autorelease];
  e = [icons objectEnumerator];
  while ((icon = [e nextObject]) != nil)
    {
      NSRect intersect = NSIntersectionRect(selectionRect, [icon frame]);

      if (intersect.size.width == 0)
	{
	  continue;
	}

      [sel addObject:icon];
    }

  [self updateSelectionWithIcons:sel modifierFlags:modifierFlags];
}

- (void)keyDown:(NSEvent *)ev
{
  unichar c = [[ev characters] characterAtIndex:0];

  if (c >= NSUpArrowFunctionKey && c <= NSRightArrowFunctionKey &&
      allowsArrowsSelection)
    {
      NXIconSlot nextIcon = selectedIconSlot;
      NXIcon * icon;
      unsigned flags = [ev modifierFlags];

      nextIcon = selectedIconSlot;

      if (selectedIconSlot.x == -1)
	{
	  NSEnumerator * e = [icons objectEnumerator];
	  while ((icon = [e nextObject]) != nil)
	    {
	      if (![icon isKindOfClass:[NSNull class]])
		{
		  selectedIconSlot = [self slotForIcon:icon];
		  [self updateSelectionWithIcon:icon
				  modifierFlags:0];
		  return;
		}
	    }
	}

      switch (c)
	{
	case NSUpArrowFunctionKey:
	  for (nextIcon.y--; nextIcon.y >= 0; nextIcon.y--)
	    {
	      icon = [self iconInSlot:nextIcon];
	      if (icon != nil)
		{
		  [self updateSelectionWithIcon:icon
				  modifierFlags:flags];
		  selectedIconSlot = nextIcon;
		  break;
		}
	    }
	  break;
	case NSDownArrowFunctionKey:
	  for (nextIcon.y++;(unsigned) nextIcon.y < slotsTall; nextIcon.y++)
	    {
	      icon = [self iconInSlot:nextIcon];
	      if (icon != nil)
		{
		  [self updateSelectionWithIcon:icon
				  modifierFlags:flags];
		  selectedIconSlot = nextIcon;
		  break;
		}
	    }
	  break;
	case NSLeftArrowFunctionKey:
	  for (nextIcon.x--; nextIcon.x >= 0; nextIcon.x--)
	    {
	      icon = [self iconInSlot:nextIcon];
	      if (icon != nil)
		{
		  [self updateSelectionWithIcon:icon
				  modifierFlags:flags];
		  selectedIconSlot = nextIcon;
		  break;
		}
	    }
	  break;
	case NSRightArrowFunctionKey:
	  for (nextIcon.x++;(unsigned) nextIcon.x < slotsWide;nextIcon.x++)
	    {
	      icon = [self iconInSlot:nextIcon];
	      if (icon != nil)
		{
		  [self updateSelectionWithIcon:icon
				  modifierFlags:flags];
		  selectedIconSlot = nextIcon;
		  break;
		}
	    }
	  break;
	}
    }
  else if (c < 0xF700 && allowsAlphanumericSelection)
    {
      if (c == '\r')
	{
	  if (sendsDoubleActionOnReturn)
	    {
	      [self sendDoubleAction:self];
	    }
	}
      else
	{
	  // TODO - implement alphanumeric selection
	}
    }
}

- (void)drawRect:(NSRect)r
{
  // even though I'd like to make this NSDottedFrameRect
  // I can't, cause NSDottedFrameRect is *_SLOW_*
  if (drawSelectionRect)
    {
      NSFrameRect(PositiveRect(selectionRect));
    }
}

- (BOOL)acceptsFirstResponder
{
  return selectable;
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)setTarget:aTarget
{
  target = aTarget;
}

- target
{
  return target;
}

- (void)setDelegate:aDelegate
{
  delegate = aDelegate;
}

- delegate
{
  return delegate;
}

- (void)setAction:(SEL)anAction
{
  action = anAction;
}

- (SEL)action
{
  return action;
}

- (void)setDoubleAction:(SEL)anAction
{
  doubleAction = anAction;
}

- (SEL)doubleAction
{
  return doubleAction;
}

- (void)setDragAction:(SEL)anAction
{
  dragAction = anAction;
}

- (SEL)dragAction
{
  return dragAction;
}

- (void)iconClicked:sender
{
  if (selectable)
    {
      selectedIconSlot = [self slotForIcon:sender];
      [self updateSelectionWithIcon:sender
		      modifierFlags:[sender modifierFlags]];
    }

  if (action != NULL && target != nil)
    {
      if ([target respondsToSelector:action])
	     [target performSelector:action
			  withObject:self];
    }
}

- (void)iconDoubleClicked:sender
{
  if (selectable)
    {
      selectedIconSlot = [self slotForIcon:sender];
      [self updateSelectionWithIcon:sender
		      modifierFlags:[sender modifierFlags]];
    }
  if (doubleAction != NULL && target != nil)
    {
      if ([target respondsToSelector:doubleAction])
	     [target performSelector:doubleAction
			  withObject:self];
    }
}

- (void)iconDragged:sender event:(NSEvent *)ev
{
  if (dragAction != NULL && target != nil)
    {
      if ([target respondsToSelector:dragAction])
	     [target performSelector:dragAction
			  withObject:sender
			  withObject:ev];
    }
}

- (void)sendDoubleAction:sender
{
  [self iconDoubleClicked:self];
}

- (void)selectIcons:(NSSet *)someIcons
{
  [self updateSelectionWithIcons:someIcons modifierFlags:0];
}

- (void)selectIcons:(NSSet *)someIcons withModifiers:(unsigned)flags
{
  [self updateSelectionWithIcons:someIcons modifierFlags:flags];
}

- (NSSet *)selectedIcons
{
  return [[selectedIcons copy] autorelease];
}

- (void)selectAll:sender
{
  if (allowsMultipleSelection) {
    [self updateSelectionWithIcons:[NSSet setWithArray:icons]
		     modifierFlags:NSShiftKeyMask];
  }
}

//-----------------------------------------------------------------------------
// Dragging
//-----------------------------------------------------------------------------

// --- NSDraggingDestination
/*
// - Before the Image is Released
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  if (delegate != nil 
      && [delegate respondsToSelector:@selector(draggingEntered:iconView:)])
    {
      dragEnteredResult = [delegate draggingEntered:sender
					   iconView:self];

      return dragEnteredResult;
    }
  else
    {
      return NSDragOperationNone;
    }
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate respondsToSelector:@selector(draggingUpdated:iconView:)])
    {
      return [delegate draggingUpdated:sender iconView:self];
    }
  else
    {
      return dragEnteredResult;
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate respondsToSelector:@selector(draggingExited:iconView:)])
    {
      [delegate draggingExited:sender iconView:self];
    }
}

// - After the Image is Released
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate 
      respondsToSelector:@selector(prepareForDragOperation:iconView:)])
    {
      return [delegate prepareForDragOperation:sender iconView:self];
    }
  else
    {
      return NO;
    }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate respondsToSelector:@selector(performDragOperation:iconView:)])
    {
      return [delegate performDragOperation:sender iconView:self];
    }
  else
    {
      return NO;
    }
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate respondsToSelector:@selector(concludeDragOperation:iconView:)])
    {
      [delegate concludeDragOperation:sender iconView:self];
    }
}

// --- NSDraggingSource

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
  if (delegate != nil &&
      [delegate respondsToSelector:@selector(draggingEnded:iconView:)])
    {
      [delegate draggingEnded:sender iconView:self];
    }
}

- (void)draggedImage:(NSImage *)image
	     endedAt:(NSPoint)screenPoint
	   operation:(NSDragOperation)operation
{
  if (delegate && 
      [delegate respondsToSelector:@selector(draggedImage:endedAt:operation:)])
    {
      [delegate draggedImage:image
		     endedAt:screenPoint
		   operation:operation];
    }
}
*/

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return [delegate draggingSourceOperationMaskForLocal:isLocal
					      iconView:self];
}

@end

@implementation NXIconView (Private)

- (void)relayoutIcons
{
  unsigned i, n;
  Class    nullClass = [NSNull class];
  unsigned holesLeft = numHoles;

  // no need to relayout - the change wouldn't be visible anyways
  if (slotsWide == 0)
    {
      return;
    }

  for (i = 0, n = [icons count]; i<n; i++)
    {
      NXIcon     *icon = [icons objectAtIndex:i];
      NXIconSlot slot;
      NSPoint    newPoint;
      unsigned   x, y;

      if (holesLeft > 0 && [icon isKindOfClass:nullClass])
	{
	  holesLeft--;
	  continue;
	}

      newPoint = PointForSlot(slotSize, SlotFromIndex(slotsWide, i));

      [icon removeFromSuperview];
      [icon putIntoView:self atPoint:newPoint];
    }
}

// TODO: This method changes view frame in unpredictable manner.
// For example, if icon dragged in/out of view (Shelf in Workspace)
// Maybe i'll return to it during Workspace's Icon Viewer cleanup
// Used only in -removeIcon: (commented out for now)
- (void)checkWrapDown
{
  int   i;
  Class nullClass = [NSNull class];
  BOOL  didChange = NO;
  NXIconSlot slot;

  for (i = [icons count] - 1; i >= 0; i--)
    {
      NXIcon *icon = [icons objectAtIndex:i];

      if ([icon isKindOfClass:nullClass])
	{
	  [icons removeObjectAtIndex:i];
	  numHoles--;
	  didChange = YES;
	} 
      else
	{
	  break;
	}
  }

  if (didChange)
    {
      if (autoAdjustsToFitIcons)
        [self adjustToFitIcons];
      else
        [self adjustFrame];
    }

  //Update lastIcon
  slot = SlotFromIndex(slotsWide, [icons count]-1);
  if (lastIcon.x <= slot.x && lastIcon.y <= slot.y)
    {
      lastIcon = slot;
    }
}

- (void)updateSelectionWithIcon:(NXIcon *)anIcon
       		  modifierFlags:(unsigned)flags
{
  [self updateSelectionWithIcons:[NSSet setWithObject:anIcon]
		   modifierFlags:flags];
}

- (void)updateSelectionWithIcons:(NSSet *)someIcons
		   modifierFlags:(unsigned)flags
{
  NXIconSelectionMode mode;
  NSSet               *sel;

  // if passed a nil argument, assume as if it were an empty set
  if (someIcons == nil) {
    someIcons = [[NSSet new] autorelease];
  }

  if (flags == NSShiftKeyMask) {
    mode = NXIconSelectionAdditiveMode;
  }
  else if (flags == NSControlKeyMask) {
    mode = NXIconSelectionSubtractiveMode;
  }
  else {
    mode = NXIconSelectionExclusiveMode;
  }

  if ([delegate respondsToSelector:
		@selector(iconView:shouldSelectIcons:selectionMode:)]) {
    someIcons = [delegate iconView:self
                          shouldSelectIcons:someIcons
                     selectionMode:mode];
  }

  if (mode == NXIconSelectionSubtractiveMode)
    {
      [someIcons makeObjectsPerform:@selector(deselect:)];
      [selectedIcons minusSet:someIcons];
    }
  else if (allowsMultipleSelection) {
    if (mode == NXIconSelectionAdditiveMode) {
      [someIcons makeObjectsPerform:@selector(select:)];
      [selectedIcons unionSet:someIcons];
    }
    else {
      [selectedIcons makeObjectsPerform:@selector(deselect:)];
      [selectedIcons setSet:someIcons];
      [selectedIcons makeObjectsPerform:@selector(select:)];
    }
  }
  else {
    NXIcon *icon;

    [selectedIcons makeObjectsPerform:@selector(deselect:)];
    [selectedIcons removeAllObjects];

    if ([someIcons count] == 1) {
      icon = [someIcons anyObject];
      [selectedIcons addObject:icon];
      [icon select:nil];
    }
    else if ([someIcons count] > 1) {
      [NSException raise:NSInvalidArgumentException
                  format:_(@"NXIconView:requested the selection "
                           @"of several icons in an icon view "
                           @"which doesn't allow multiple selection")];
    }
  }

  if ([selectedIcons count] != 0) {
      NSEnumerator *e;
      NXIcon       *ic;
      NSRect       r;

      r = [[selectedIcons anyObject] frame];
      e = [selectedIcons objectEnumerator];
      while ((ic = [e nextObject]) != nil) {
  	  r = NSUnionRect(r, NSUnionRect([ic frame], [[ic label] frame]));
	}

      [self scrollRectToVisible:r];
    }

  sel = [[selectedIcons copy] autorelease];

  if ([delegate respondsToSelector:
		@selector(iconView:didChangeSelectionTo:)]) {
      [delegate iconView:self didChangeSelectionTo:sel];
    }

  // [[NSNotificationCenter defaultCenter]
  //   postNotificationName:NXIconViewDidChangeSelectionNotification
  //       	  object:self
  //       	userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
  //                                        sel, @"Selection", nil]];
}

@end

