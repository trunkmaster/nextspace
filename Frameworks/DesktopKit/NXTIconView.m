/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2005 Saso Kiselkov
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "NXTIconView.h"

#import <math.h>
#import <AppKit/AppKit.h>

#import "NXTIcon.h"
#import "NXTIconLabel.h"

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

static inline NSPoint PointForSlot(NSSize slotSize, NXTIconSlot slot)
{
  return NSMakePoint(floorf(slot.x * slotSize.width + slotSize.width / 2),
		     floorf(slot.y * slotSize.height + slotSize.height / 2));
}

static inline unsigned int IndexFromSlot(unsigned slotsWide, NXTIconSlot slot)
{
  return (slot.x + slotsWide * slot.y);
}

static inline NXTIconSlot SlotFromIndex(unsigned slotsWide, unsigned i)
{
  unsigned int x;

  x = i % slotsWide;

  return NXTMakeIconSlot(x, (i - x) / slotsWide);
}

/// Private NXTIconView methods.
@interface NXTIconView (Private)

/* Removes all icons from the superview and puts them at recomputed
   positions where they belong. This method is invoked e.g. after a
   slot size change, when the icon positions need to be updated. */
- (void)relayoutIcons;

/* Does a reverse search in the receiver's list of icons and removes
   any trailing holes and if autoAdjustsToFitIcons is YES, then it
   also invokes adjustToFitIcons. */
- (void)checkWrapDown;

/* Invokes updateSelectionWithIcons:modifierFlags:with a single icon. 
   Returns selection rectangle.
 */
- (void)updateSelectionWithIcon:(NXTIcon *)anIcon
                  modifierFlags:(unsigned)flags;

/* Changes the selection of icons.

   This method is invoked every time a selection change occurs.
     
   @param someIcons A set of icons with which to do the change.
   @param flags Keyboard modifier flags which change the operation
   type. See NXTIconSelectionMode. */
- (void)updateSelectionWithIcons:(NSSet *)someIcons
                   modifierFlags:(unsigned)flags;

@end

@implementation NXTIconView

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
  allowsEmptySelection = YES;
  allowsArrowsSelection = YES;
  allowsAlphanumericSelection = YES;

  slotsWide = roundf(r.size.width / slotSize.width);
  if (slotsWide == 0)
    slotsWide = 1;
  if (slotsTall == 0)
    slotsTall = 1;
  
  lastIcon = NXTMakeIconSlot(-1, 0);

  selectedIconSlot.x = -1;
  selectedIconSlot.y = -1;

  maximumCollapsedLabelWidthSpace = defaultMaximumCollapsedLabelWidthSpace;

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
  BOOL saved = autoAdjustsToFitIcons;

  autoAdjustsToFitIcons = NO;
  [self removeAllIcons];

  for (NXTIcon *icon in someIcons) {
    [self addIcon:icon];
  }

  autoAdjustsToFitIcons = saved;
  if (autoAdjustsToFitIcons) {
    [self adjustToFitIcons];
  }
}

- (void)addIcons:(NSArray *)someIcons
{
  BOOL saved = autoAdjustsToFitIcons;

  autoAdjustsToFitIcons = NO;
  for (NXTIcon *icon in someIcons) {
    [self addIcon:icon];
  }
  autoAdjustsToFitIcons = saved;
  
  if (autoAdjustsToFitIcons) {
    [self adjustToFitIcons];
  }
}

- (void)addIcon:(NXTIcon *)anIcon
{
  NXTIconSlot slot;
  NSUInteger i, n;

  slot.x = 0;
  slot.y = 0;

  if (numHoles != 0) {
    // find a free spot - there _must_ be something, because
    // we remember to have some holes somewhere
    // NSLog(@"[NXTIconView] icons: %@", icons);
    for (i = 0, n = [icons count]; i < n; i++) {
      if ([[icons objectAtIndex:i] isKindOfClass:[NSNull class]]) {
        slot = SlotFromIndex(slotsWide, i);
        break;
      }
    }
    if (i >= n) {
      [NSException raise:NSInternalInconsistencyException
                  format:_(@"NXTIconView:tried to pack "
                           @"a icon into free slots, but "
                           @"none were found (even though "
                           @"I thought there were!)")];
    }
    // NSLog(@"[NXTIconView] found hole at index: %lu", i);
  }
  else {
    // NSLog(@"[NXTIconView] no holes! lastIcon.x=%i, lastIcon.y=%i",
    //       lastIcon.x, lastIcon.y);
    slot = lastIcon;
    slot.x++;
    if (slot.x >= slotsWide) {
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

- (void)putIcon:(NXTIcon *)anIcon
       intoSlot:(NXTIconSlot)aSlot
{
  unsigned index;

  // constrain the x coord to the current width
  if (aSlot.x >= (int)slotsWide) {
    aSlot.x = slotsWide-1;
  }

  if (lastIcon.x <= aSlot.x || lastIcon.y <= aSlot.y) {
    lastIcon = aSlot;
  }

  index = IndexFromSlot(slotsWide, aSlot);

  if (index >= [icons count]) {
    // enlarge - the slot is greater than our current height
    unsigned i;

    slotsTall = aSlot.y + 1;
    for (i = [icons count]; i < index; i++) {
      [icons addObject:[NSNull null]];
      numHoles++;
    }
    [icons addObject:anIcon];
    if (autoAdjustsToFitIcons) {
      [self adjustToFitIcons];
    }
  }
  else {
    // put into an existing slot
    NXTIcon *oldIcon;

    oldIcon = [icons objectAtIndex:index];
    if ([oldIcon isKindOfClass:[NSNull class]]) {
      numHoles--;
    }
    else {
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

- (void)removeIcon:(NXTIcon *)anIcon
{
  NSUInteger i;

//  NSLog(@"[NXTIconView -removeIcon] icons count: %i", [icons count]);

//  for (i=0; i<[icons count]; i++)
//    {
//      NSLog(@"+ %@", [[icons objectAtIndex:i] labelString]);
//    }

  i = [icons indexOfObjectIdenticalTo:anIcon];
  if (i == NSNotFound) {
    NSLog(@"[NXTIconView] failed to remove icon: icon not found!");
    return;
  }

  [selectedIcons removeObject:anIcon];
  [anIcon removeFromSuperview];
  if (fillWithHoleWhenRemovingIcon) {
    [icons replaceObjectAtIndex:i withObject:[NSNull null]];
    numHoles++;
  }
  else {
    [icons removeObjectAtIndex:i];
  }

  // [self checkWrapDown];
}

- (void)removeIcons:(NSArray *)someIcons
{
  NSEnumerator *e;
  NXTIcon      *icon;
  BOOL         saved;

  saved = autoAdjustsToFitIcons;
  autoAdjustsToFitIcons = NO;
  e = [someIcons objectEnumerator];
  while ((icon = [e nextObject]) != nil) {
    [self removeIcon:icon];
  }

  autoAdjustsToFitIcons = saved;
  if (autoAdjustsToFitIcons) {
    [self adjustToFitIcons];
  }
}

- (void)removeIconInSlot:(NXTIconSlot)aSlot
{
  unsigned i;
  NXTIcon  *icon;

  if (aSlot.x >= (int) slotsWide) {
    return;
  }

  i = IndexFromSlot(slotsWide, aSlot);
  if (i >= [icons count]) {
    return;
  }

  icon = [icons objectAtIndex:i];

  if (![icon isKindOfClass:[NXTIcon class]]) {
    return;
  }

  [self removeIcon:icon];
}

- (void)removeAllIcons
{
  for (NXTIcon *icon in icons) {
    if (icon && ![icon isKindOfClass:[NSNull class]]) {
      [icon removeFromSuperview];
    }
  }
  [icons removeAllObjects];
  [selectedIcons removeAllObjects];

  slotsTall = 0;
  numHoles = 0;
  lastIcon = NXTMakeIconSlot(-1, 0);

  selectedIconSlot.x = -1;
  selectedIconSlot.y = -1;

  if (autoAdjustsToFitIcons) {
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
  NXTIcon        *icon;
  Class          iconClass = [NXTIcon class];

  while ((icon = [e nextObject]) != nil) {
    if ([icon isKindOfClass:iconClass]) {
      [array addObject:icon];
    }
  }

  return [[array copy] autorelease];
}

- (NXTIcon *)iconInSlot:(NXTIconSlot)aSlot
{
  NXTIcon * icon;
  unsigned i;

  if (aSlot.x >= (int) slotsWide)
    return nil;

  i = IndexFromSlot(slotsWide, aSlot);

  if (i >= [icons count]) {
    return nil;
  }

  icon = [icons objectAtIndex:i];
  if ([icon isKindOfClass:[NSNull class]]) {
    return nil;
  }
  else {
    return icon;
  }
}

- (NXTIconSlot)slotForIcon:(NXTIcon *)anIcon
{
  NSUInteger i = [icons indexOfObjectIdenticalTo:anIcon];

  if (i == NSNotFound) {
    return NXTMakeIconSlot(-1, -1);
  }
  else {
    return SlotFromIndex(slotsWide, i);
  }
}

- (NXTIcon *)iconWithLabelString:(NSString *)label
{
  NXTIcon *iconFound = nil;
  
  for (NXTIcon *icon in icons) {
    if (icon && ![icon isKindOfClass:[NSNull class]]
        && [[icon labelString] isEqualToString:label]) {
      iconFound = icon;
      break;
    }
  }

  return iconFound;
}

//------------------------------------------------------------------------------
// Sizes and autosizing
//------------------------------------------------------------------------------
- (void)setSlotSize:(NSSize)newSlotSize
{
  CGFloat    viewWidth = 0.0;
  NSUInteger newSlotsWide = 0;;

  slotSize = newSlotSize;

  // NSLog(@"[NXTIconView setSlotSize]: view width: %0.f slot width: %0.f "
  //       @"enclosing view:%@",
  //       frame.size.width, slotSize.width,
  //       [[self superview] className]);
  
  // Determine how much slots can contain superview's width.
  if (_autoresizingMask & NSViewWidthSizable) {
    // NSLog(@"[NXTIconView] set slot size from superview width");
    viewWidth = [[self superview] bounds].size.width;
  }
  else {
    // NSLog(@"[NXTIconView] set slot size from slotsWide");
    viewWidth = slotsWide * slotSize.width;
  }

  newSlotsWide = floorf(viewWidth / slotSize.width);
  [self setSlotsWide:newSlotsWide];
  
  // NSLog(@"[NXTIconView] slotsWide: %lu view width:%0.f",
  //       newSlotsWide, [self frame].size.width);

  // Update collapsed icon labels width
  {
    NXTIcon       *icon;
    NSEnumerator *e = [icons objectEnumerator];
    Class        iconClass = [NXTIcon class];

    while ((icon = [e nextObject]) != nil) {
      if ([icon isKindOfClass:iconClass]) {
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
  NXTIcon      *icon;
  float        newWidth;
  Class        iconClass;

  maximumCollapsedLabelWidthSpace = aValue;
  newWidth = slotSize.width - maximumCollapsedLabelWidthSpace;

  iconClass = [NXTIcon class];

  e = [icons objectEnumerator];
  while ((icon = [e nextObject]) != nil) {
    if ([icon isKindOfClass:iconClass]) {
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

  // NSLog(@"[NXTIconView -resizeWithOldSuperviewSize] width: %0.f slot width: %0.f", 
  //       [self frame].size.width, slotSize.width);

  if (_autoresizingMask & NSViewWidthSizable) {
    slotsWide = floorf([self frame].size.width / slotSize.width);
  }
  else {
    slotsWide = ceilf([self frame].size.width / slotSize.width);
  }

  slotsTall = ceilf([self frame].size.height / slotSize.height);
  
  if (autoAdjustsToFitIcons) {
    [self adjustToFitIcons];
  }
  else {
    [self adjustFrame];
  }
  
  [self relayoutIcons];
}

- (void)adjustToFitIcons
{
  NSRect       newFrame = [self frame];
  NSScrollView *scrollView = [self enclosingScrollView];
  NSRect       contentFrame;

  // NSLog(@">>>>[NXTIconView adjustToFitIcons]<<<");

  if (scrollView != nil) {
    contentFrame = [[scrollView contentView] frame];
  }

  // Width of icon view
  if (adjustsToFillEnclosingScrollView == YES && scrollView != nil) {
    slotsWide = floorf(contentFrame.size.width / slotSize.width);
    newFrame.size.width = contentFrame.size.width;
  }
  else {
    newFrame.size.width = slotSize.width * slotsWide;
  }
  
  // Height of icon view
  if (isSlotsTallFixed == NO) {
    slotsTall = ceilf((float)[icons count] / slotsWide);
  }
  newFrame.size.height = slotSize.height * slotsTall;
  
  if (adjustsToFillEnclosingScrollView == YES &&
      newFrame.size.height < contentFrame.size.height) {
    newFrame.size.height = contentFrame.size.height;
  }

  [self setFrame:newFrame];
  [self relayoutIcons];
}

// Honours autoresizingMask, doesn't honour adjustsToFillEnclosingScrollView
- (void)adjustFrame
{
  NSRect       newFrame = [self frame];
  NSScrollView *sv = [self enclosingScrollView];

  // NSLog(@">>>>[NXTIconView adjustFrame]<<<");

  if (_autoresizingMask & NSViewWidthSizable) {
    if (sv)
      newFrame.size.width = [[sv contentView] frame].size.width;
    else
      newFrame.size.width = [[self superview] bounds].size.width;
  }
  else {
    newFrame.size.width = slotSize.width * slotsWide;
  }

  if (_autoresizingMask & NSViewHeightSizable) {
    if (sv)
      newFrame.size.height = [[sv contentView] frame].size.height;
    else
      newFrame.size.height = [[self superview] bounds].size.height;
  }
  else {
    newFrame.size.height = slotSize.height * slotsTall;
  }

  [self setFrame:newFrame];
  [self relayoutIcons];
}

- (void)setSlotsWide:(unsigned int)newSlotsWide
{
  NSRect frame;

  if (newSlotsWide == 0) {
    [NSException raise:NSInvalidArgumentException
                format:_(@"NXTIconView `-setSlotsWide:' passed "
                         @"zero width argument")];
  }

  // NSLog(@"[NXTIconView] setSlotsWide:%i", newSlotsWide);

  slotsWide = newSlotsWide;
  
  if (autoAdjustsToFitIcons) {
    [self adjustToFitIcons];
  }
  else {
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

- (unsigned int)slotsTallVisible
{
  NSScrollView *sv = (NSScrollView *)[self superview];
  NSUInteger   svHeight = [sv documentVisibleRect].size.height;

  return (unsigned int)(svHeight / slotSize.height);
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

- (void)setAllowsEmptySelection:(BOOL)flag
{
  allowsEmptySelection = flag;
}

- (BOOL)allowsEmptySelection
{
  return allowsEmptySelection;
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
  NSMutableSet *sel;
  NSRect       intersect;
  unsigned     modifierFlags;

  // NSLog(@"NXIV:mouseDown: %@", icons);

  if ([ev clickCount] >= 2) {
    return;
  }

  // In this case only direct icon click allowed
  if (allowsMultipleSelection == NO) {
    return;
  }

  p = [self convertPoint:[ev locationInWindow] fromView:nil];
  modifierFlags = [ev modifierFlags];

  selectionRect.origin.x = p.x;
  selectionRect.origin.y = p.y;
  selectionRect.size.width = 0;
  selectionRect.size.height = 0;
  drawSelectionRect = YES;

  while ([(ev = [[self window] nextEventMatchingMask:NSAnyEventMask]) type]
	 != NSLeftMouseUp) {
    if ([ev type] == NSLeftMouseDragged) {
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

  if (selectionRect.size.width < 0) {
    selectionRect.size.width = 0;
    selectionRect.origin.x -= selectionRect.size.width;
  }
  if (selectionRect.size.height < 0) {
    selectionRect.size.height = 0;
    selectionRect.origin.y -= selectionRect.size.height;
  }

  sel = [[NSMutableSet new] autorelease];
  for (NXTIcon *icon in icons) {
    if (!icon || [icon isKindOfClass:[NSNull class]])
      continue;
    
    intersect = NSIntersectionRect(selectionRect, [icon frame]);
    if (intersect.size.width == 0)
      continue;
    
    [sel addObject:icon];
  }

  if ([sel count] > 0 || allowsEmptySelection == YES) {
    [self updateSelectionWithIcons:sel modifierFlags:modifierFlags];
  }
}

- (void)keyDown:(NSEvent *)ev
{
  unichar    c = [[ev characters] characterAtIndex:0];
  NSUInteger flags = [ev modifierFlags];
  BOOL       noModifiersPressed = (!(flags & NSShiftKeyMask) &&
                                   !(flags & NSControlKeyMask) &&
                                   !(flags & NSAlternateKeyMask) &&
                                   !(flags & NSCommandKeyMask));
  NXTIcon     *icon = nil;
  NXTIconSlot nextIcon = selectedIconSlot;
  NSRect     selRect = NSMakeRect(0,0,0,0);

  // NSLog(@"[NXTIconView] keyDown: %c (%x) modifiers: %lu slot: %i.%i",
  //       c, c,flags, selectedIconSlot.x, selectedIconSlot.y);

  // Arrows and Shift + Arrows selection
  if (allowsArrowsSelection &&
      (noModifiersPressed || (flags & NSShiftKeyMask)) &&
      c >= NSUpArrowFunctionKey && c <= NSRightArrowFunctionKey) {

    // No selection was set before - select first available icon from left to
    // right, from top to bottom
    if (nextIcon.x == -1 && nextIcon.y == -1) {
      while (!icon || [icon isKindOfClass:[NSNull class]]) {
        nextIcon.x++;
        if (nextIcon.x == slotsWide) {
          nextIcon.x = 0;
          nextIcon.y++;
          if (nextIcon.y > slotsTall) {
            break;
          }
        }
        icon = [self iconInSlot:nextIcon];
      }
      if (icon && ![icon isKindOfClass:[NSNull class]]) {
        [self updateSelectionWithIcon:icon modifierFlags:0];
      }
      return;
    }

    switch (c)
      {
      case NSUpArrowFunctionKey:
        if (nextIcon.x == -1) nextIcon.x = 0;
        if (flags & NSShiftKeyMask) {
          if (minSelectedIconSlot.y > 0) {
            int max_x = maxSelectedIconSlot.x;
            nextIcon.x = minSelectedIconSlot.x;
            nextIcon.y = minSelectedIconSlot.y - 1;
            while (nextIcon.x <= max_x) {
              selectedIconSlot = nextIcon;
              icon = [self iconInSlot:nextIcon];
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              nextIcon.x++;
            }
          }
        }
        else {
          for (nextIcon.y--; nextIcon.y >= 0; nextIcon.y--) {
            icon = [self iconInSlot:nextIcon];
            if (icon != nil) {
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              selectedIconSlot = nextIcon;
              break;
            }
          }
        }
        break;
      case NSDownArrowFunctionKey:
        if (flags & NSShiftKeyMask) {
          if (maxSelectedIconSlot.y < slotsTall-1) {
            int max_x = maxSelectedIconSlot.x;
            nextIcon.x = minSelectedIconSlot.x;
            nextIcon.y = maxSelectedIconSlot.y + 1;
            while (nextIcon.x <= max_x) {
              selectedIconSlot = nextIcon;
              icon = [self iconInSlot:nextIcon];
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              nextIcon.x++;
            }
          }
        }
        else {
          if (nextIcon.x == -1) nextIcon.x = 0;
          for (nextIcon.y++;(unsigned) nextIcon.y <= slotsTall; nextIcon.y++) {
            icon = [self iconInSlot:nextIcon];
            if (icon != nil) {
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              selectedIconSlot = nextIcon;
              break;
            }
          }
        }
        break;
      case NSLeftArrowFunctionKey:
        if (flags & NSShiftKeyMask) {
          if (minSelectedIconSlot.x > 0) {
            int max_y = maxSelectedIconSlot.y;
            nextIcon.x = minSelectedIconSlot.x - 1;
            nextIcon.y = minSelectedIconSlot.y;
            while (nextIcon.y <= max_y) {
              selectedIconSlot = nextIcon;
              icon = [self iconInSlot:nextIcon];
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              nextIcon.y++;
            }
          }
        }
        else {
          if (nextIcon.y == -1) nextIcon.y = 0;
          for (nextIcon.x--; nextIcon.x >= 0; nextIcon.x--) {
            icon = [self iconInSlot:nextIcon];
            if (icon != nil) {
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              selectedIconSlot = nextIcon;
              break;
            }
          }
        }
        break;
      case NSRightArrowFunctionKey:
        if (flags & NSShiftKeyMask) {
          if (maxSelectedIconSlot.x < slotsWide-1) {
            int max_y = maxSelectedIconSlot.y;
            nextIcon.x = maxSelectedIconSlot.x + 1;
            nextIcon.y = minSelectedIconSlot.y;
            while (nextIcon.y <= max_y) {
              selectedIconSlot = nextIcon;
              icon = [self iconInSlot:nextIcon];
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              nextIcon.y++;
            }
          }
        }
        else {
          if (nextIcon.y == -1) nextIcon.y = 0;
          for (nextIcon.x++; (unsigned)nextIcon.x < slotsWide; nextIcon.x++) {
            icon = [self iconInSlot:nextIcon];
            if (icon != nil) {
              [self updateSelectionWithIcon:icon modifierFlags:flags];
              selectedIconSlot = nextIcon;
              break;
            }
          }
        }
        break;
      }
  }
  else if (c == NSHomeFunctionKey) {
    if (flags & NSShiftKeyMask) {
      while (nextIcon.x-- != 0) {
        [self updateSelectionWithIcon:[self iconInSlot:nextIcon]
                        modifierFlags:flags];
      }
    }
    else {
      [self updateSelectionWithIcon:[self iconInSlot:NXTMakeIconSlot(0,0)]
                      modifierFlags:0];
    }
  }
  else if (c == NSEndFunctionKey) {
    if (flags & NSShiftKeyMask) {
      if (nextIcon.y == -1) {
        nextIcon.x = nextIcon.y = 0;
        [self updateSelectionWithIcon:[self iconInSlot:nextIcon]
                        modifierFlags:flags];
      }
      while (nextIcon.x++ < slotsWide ) {
        [self updateSelectionWithIcon:[self iconInSlot:nextIcon]
                        modifierFlags:flags];
      }
    }
    else {
      nextIcon.x = slotsWide - 1;
      nextIcon.y = slotsTall - 1;
      for (; nextIcon.x >= 0; nextIcon.x--) {
        icon = [self iconInSlot:nextIcon];
        if (icon != nil) {
          selectedIconSlot = nextIcon;
          break;
        }
      }

      [self updateSelectionWithIcon:icon modifierFlags:0];
    }
  }
  else if (c == NSPageUpFunctionKey) {
    NSScrollView *sv = [self enclosingScrollView];
    if (sv) {
      [sv scrollPageUp:self];
    }
  }
  else if (c == NSPageDownFunctionKey) {
    NSScrollView *sv = [self enclosingScrollView];
    if (sv) {
      [sv scrollPageDown:self];
    }
  }
  else if (c < 0xF700 && allowsAlphanumericSelection) {
    if (sendsDoubleActionOnReturn &&
        (c == NSCarriageReturnCharacter ||
         c == NSNewlineCharacter ||
         c == NSEnterCharacter)) {
      for (NXTIcon *icon in [self selectedIcons]) {
        [self iconDoubleClicked:icon];
      }
    }
    else {
      if (delegate && [delegate respondsToSelector:@selector(keyDown:)]) {
        [delegate keyDown:ev];
      }
    }
  }
  else {
    if (delegate && [delegate respondsToSelector:@selector(keyDown:)]) {
      [delegate keyDown:ev];
    }    
  }
}

- (void)drawRect:(NSRect)r
{
  if (drawSelectionRect) {
    NSFrameRect(PositiveRect(selectionRect));
  }
}

- (BOOL)acceptsFirstResponder
{
  return selectable;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
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
  if (selectable) {
    selectedIconSlot = [self slotForIcon:sender];
    [self updateSelectionWithIcon:sender modifierFlags:[sender modifierFlags]];
  }
  
  if (action != NULL && target != nil) {
    if ([target respondsToSelector:action]) {
      [target performSelector:action withObject:self];
    }
  }
}

- (void)iconDoubleClicked:sender
{
  if (selectable) {
    selectedIconSlot = [self slotForIcon:sender];
    [self updateSelectionWithIcon:sender modifierFlags:[sender modifierFlags]];
  }
  
  if (doubleAction != NULL && target != nil) {
    if ([target respondsToSelector:doubleAction]) {
      [target performSelector:doubleAction withObject:self];
    }
  }
}

- (void)iconDragged:sender event:(NSEvent *)ev
{
  if (dragAction != NULL && target != nil) {
    if ([target respondsToSelector:dragAction])
      [target performSelector:dragAction
                   withObject:sender
                   withObject:ev];
  }
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
// - Before the Image is Released
/*
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

@implementation NXTIconView (Private)

- (void)relayoutIcons
{
  unsigned i, n;
  Class    nullClass = [NSNull class];
  unsigned holesLeft = numHoles;

  // no need to relayout - the change wouldn't be visible anyways
  if (slotsWide == 0) {
    return;
  }

  for (i = 0, n = [icons count]; i<n; i++) {
    NXTIcon     *icon = [icons objectAtIndex:i];
    NXTIconSlot slot;
    NSPoint     newPoint;
    unsigned    x, y;

    if (holesLeft > 0 && [icon isKindOfClass:nullClass]) {
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
  int         i;
  Class       nullClass = [NSNull class];
  BOOL        didChange = NO;
  NXTIconSlot slot;

  for (i = [icons count] - 1; i >= 0; i--) {
    NXTIcon *icon = [icons objectAtIndex:i];

    if ([icon isKindOfClass:nullClass]) {
      [icons removeObjectAtIndex:i];
      numHoles--;
      didChange = YES;
    } 
    else {
      break;
    }
  }

  if (didChange) {
    if (autoAdjustsToFitIcons) {
      [self adjustToFitIcons];
    }
    else {
      [self adjustFrame];
    }
  }

  //Update lastIcon
  slot = SlotFromIndex(slotsWide, [icons count]-1);
  if (lastIcon.x <= slot.x && lastIcon.y <= slot.y) {
    lastIcon = slot;
  }
}

- (void)updateSelectionWithIcon:(NXTIcon *)anIcon
                  modifierFlags:(unsigned)flags
{
  return [self updateSelectionWithIcons:[NSSet setWithObject:anIcon]
                          modifierFlags:flags];
}

- (void)updateSelectionWithIcons:(NSSet *)someIcons
                   modifierFlags:(unsigned)flags
{
  NXTIconSelectionMode mode;
  SEL                 shouldSelectIconsSEL;

  // if passed a nil argument, assume as if it were an empty set
  if (someIcons == nil) {
    someIcons = [[NSSet new] autorelease];
    selectedIconSlot.x = -1;
    selectedIconSlot.y = -1;
  }

  if (flags & NSShiftKeyMask) {
    mode = NXTIconSelectionAdditiveMode;
  }
  else if (flags & NSControlKeyMask) {
    mode = NXTIconSelectionSubtractiveMode;
  }
  else {
    mode = NXTIconSelectionExclusiveMode;
  }

  shouldSelectIconsSEL = @selector(iconView:shouldSelectIcons:selectionMode:);
  if (delegate && [delegate respondsToSelector:shouldSelectIconsSEL]) {
    someIcons = [delegate iconView:self
                          shouldSelectIcons:someIcons
                     selectionMode:mode];
  }

  if (mode == NXTIconSelectionSubtractiveMode) {
    for (NXTIcon *icon in someIcons) {
      if (icon && ![icon isKindOfClass:[NSNull class]])
        [icon deselect:self];
    }
    [selectedIcons minusSet:someIcons];
  }
  else if (allowsMultipleSelection) {
    if (mode == NXTIconSelectionAdditiveMode) {
      for (NXTIcon *icon in someIcons) {
        if (icon && ![icon isKindOfClass:[NSNull class]])
          [icon select:self];
      }
      [selectedIcons unionSet:someIcons];
    }
    else {
      for (NXTIcon *icon in selectedIcons) {
        if (icon && [icon isKindOfClass:[NXTIcon class]]) {
          [icon deselect:self];
        }
      }
      [selectedIcons removeAllObjects];
      
      for (NXTIcon *icon in someIcons) {
        if (icon && [icon isKindOfClass:[NXTIcon class]]) {
          [icon select:self];
          [selectedIcons addObject:icon];
        }
      }
    }
  }
  else {
    for (NXTIcon *icon in selectedIcons) {
      if (icon && [icon isKindOfClass:[NXTIcon class]]) {
        [icon deselect:nil];
      }
    }
    [selectedIcons removeAllObjects];

    if ([someIcons count] == 1) {
      NXTIcon *icon = [someIcons anyObject];
      if (icon && [icon isKindOfClass:[NXTIcon class]]) {
        [icon select:nil];
        [selectedIcons addObject:icon];
      }
    }
    else if ([someIcons count] > 1) {
      [NSException raise:NSInvalidArgumentException
                  format:_(@"NXTIconView:requested the selection "
                           @"of several icons in an icon view "
                           @"which doesn't allow multiple selection")];
    }
  }

  if ([selectedIcons count] > 0) {
    NSRect     r = NSMakeRect(0,0,0,0);
    NXTIconSlot lastSlot = NXTMakeIconSlot(INT_MAX,INT_MAX), newSlot;
    NXTIconSlot minOldSlot = NXTMakeIconSlot(minSelectedIconSlot.x, minSelectedIconSlot.y);
    NXTIconSlot maxOldSlot = NXTMakeIconSlot(maxSelectedIconSlot.x, maxSelectedIconSlot.y);

    minSelectedIconSlot = NXTMakeIconSlot(INT_MAX,INT_MAX);
    maxSelectedIconSlot = NXTMakeIconSlot(0,0);
    for (NXTIcon *icon in selectedIcons) {
      if (icon && [icon isKindOfClass:[NXTIcon class]]) {
        newSlot = [self slotForIcon:icon];
        if (newSlot.y < lastSlot.y || newSlot.x < lastSlot.x) {
          selectedIconSlot = newSlot;
        }
        if (newSlot.y < minSelectedIconSlot.y) {
          minSelectedIconSlot = newSlot;
        }
        if (newSlot.y > maxSelectedIconSlot.y) {
          maxSelectedIconSlot = newSlot;
        }
        else if (newSlot.y == maxSelectedIconSlot.y && newSlot.x > maxSelectedIconSlot.x) {
          maxSelectedIconSlot = newSlot;
        }
        else if (newSlot.y == minSelectedIconSlot.y && newSlot.x < minSelectedIconSlot.x) {
          minSelectedIconSlot = newSlot;
        }
        r = NSUnionRect(r, NSUnionRect([icon frame], [[icon label] frame]));
      }
    }
    // NSLog(@"[NXTIconView] top left slot: (%i, %i) bottom right: (%i, %i)",
    //       minSelectedIconSlot.x, minSelectedIconSlot.y,
    //       maxSelectedIconSlot.x, maxSelectedIconSlot.y);
    NSRect f = [[self enclosingScrollView] documentVisibleRect];
      
    if (minOldSlot.y >= minSelectedIconSlot.y) { // Shift+UpArrow or UpArrow
      // NSLog(@"===>>> Up");
      if (r.size.height > f.size.height) {
        r.origin.y = [[self iconInSlot:minSelectedIconSlot] frame].origin.y;
        r.size.height = f.size.height;
      }
      if (r.origin.y < slotSize.height) { // first row
        r.origin.y = 0;
      }
    }
    else if (maxOldSlot.y < maxSelectedIconSlot.y) { // Shift+Down or DownArrow
      // NSLog(@"===>>> Down");
      if (maxSelectedIconSlot.y == slotsTall-1) {
        NXTIcon *icon = [self iconInSlot:maxSelectedIconSlot];
        r.origin.y = [icon frame].origin.y;
        r.size.height = slotSize.height + 5;
      }
      if (r.size.height > f.size.height) {
        r.origin.y += (r.size.height - f.size.height);
      }
    }
    else { // single icon click, End - last row
      // NSLog(@"===>>> Single Icon");
      r.origin.y = [[self iconInSlot:maxSelectedIconSlot] frame].origin.y;
      r.size.height = slotSize.height;
    }
    
    [self scrollRectToVisible:r];
  }
  else {
    selectedIconSlot.x = -1;
    selectedIconSlot.y = -1;
    minSelectedIconSlot = NXTMakeIconSlot(0,0);
    maxSelectedIconSlot = NXTMakeIconSlot(0,slotsTall-1);
  }

  if ([delegate respondsToSelector:@selector(iconView:didChangeSelectionTo:)]) {
    [delegate iconView:self didChangeSelectionTo:selectedIcons];
  }
}

@end

