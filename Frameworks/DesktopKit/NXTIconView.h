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

/**
   @class NXTIconView
   @brief This class is a view that allows the comfortable display of icons.

   You use instances of NXTIconView (or simply icon views) to stack icons
   into matrix-like layouts. An icon view is composed of slots, each
   containing one icon. Icons in an icon view need not be linearly following -
   there can be empty slots (holes) in it. The icon view handles the
   correct and efficient layout of icons inside itself.

   The layout starts at the upper left corner (slot 0x0) and continues
   to the right-bottom.

   @author Saso Kiselkov, Sergii Stoian
*/

#import <AppKit/NSView.h>
#import <AppKit/NSDragging.h>

@class NSMutableArray, NXTIcon;
@protocol NSDraggingInfo;

/** @struct NXTIconSlot
    @brief A icon slot inside an icon view.

    Instances of NXTIconView (and its subclasses), or simply icon views,
    indentify the position an icon occupies in the icon view by a slot. */
typedef struct {
    int x, y;
} NXTIconSlot;

/** @enum NXTIconSelectionMode
    @brief The mode by which the icon view should select icons.
*/
typedef enum {
  /** Normal clicking of icons - exclusive selection of only
      these icons. */
  NXTIconSelectionExclusiveMode,
  /** Shift-clicking - addition of the clicked icons to the
      current selection. */
  NXTIconSelectionAdditiveMode,
  /** Control-clicking - removal of the clicked icons from the
      current selection. */
  NXTIconSelectionSubtractiveMode
} NXTIconSelectionMode;

/** A shorthand function to construct an icon slot from provided
    X and Y coordinates. */
static inline NXTIconSlot NXTMakeIconSlot(NSUInteger x, NSUInteger y)
{
  NXTIconSlot slot;

  slot.x = x;
  slot.y = y;

  return slot;
}

@interface NXTIconView : NSView
{
  /** An array that respresents the two-dimensional layout of the
    icons. The length of one row is in the `slotsWide' ivar.
    Empty positions are represented by an NSNull. */
  NSMutableArray * icons;

  /** Marks the number of holes in the `icons' array - if its not
    zero then we can search for holes inside the view when adding
    icons. */
  unsigned int numHoles;

  /** Contains the slot of the last added icon so we can more
    quickly determine the last icon's location without
    having to search the view. */
  NXTIconSlot lastIcon;

  // The number of slots the view is wide.
  unsigned int slotsWide;
  // The number of slots the view is tall.
  unsigned int slotsTall;

  /** The space that we leave empty to the sides of icon's
    collapsed labels (so that the collapsed labels won't touch). */
  float maximumCollapsedLabelWidthSpace;

  // Marks the current slot size.
  NSSize slotSize;

  BOOL autoAdjustsToFitIcons;
  BOOL adjustsToFillEnclosingScrollView;
  BOOL fillWithHoleWhenRemovingIcon;
  BOOL isSlotsTallFixed;

  BOOL selectable;
  BOOL allowsMultipleSelection;
  BOOL allowsEmptySelection;

  id target;
  id delegate;
  SEL action, doubleAction, dragAction;

  /// A set containing all the selected icons.
  NSMutableSet * selectedIcons;

  /// YES when we are to draw the selection rect (in selectionRect).
  BOOL drawSelectionRect;
  /// The rect of the selection box when dragging.
  NSRect selectionRect;

  BOOL allowsArrowsSelection;
  BOOL allowsAlphanumericSelection;
  BOOL sendsDoubleActionOnReturn;

  /** The selected slot. When moving with arrow keys, the move is
    relative to this slot. */
  NXTIconSlot selectedIconSlot;
  /** Selected slot with minimum x and y - top left*/
  NXTIconSlot minSelectedIconSlot;
  /** Selected slot with maximum x and y - bottom right*/
  NXTIconSlot maxSelectedIconSlot;

  NSString *lastAlphaString;
  NSDate   *lastHitDate;

  /// This contains the saved result of draggingEntered...
  unsigned int dragEnteredResult;
}

/** Sets the default slot size that all subsequently created icon
    views will have. */
+ (void)setDefaultSlotSize:(NSSize)newSize;
/** Returns the default slot size. */
+ (NSSize)defaultSlotSize;

/** Sets the default maximum collapsed label width space.
    See -[NXTIconView setMaximumCollapsedLabelWidthSpace:]. */
+ (void)setDefaultMaximumCollapsedLabelWidthSpace:(float)aValue;
/** Returns the default maximum collapsed label width space.
    See -[NXTIconView setMaximumCollapsedLabelWidthSpace:]. */
+ (float)defaultMaximumCollapsedLabelWidthSpace;

/** The designated initializer for icon views. */
- initWithFrame:(NSRect)frame;

/** This method initializes the icon view to be "newSlotsWide" slots wide. */
- initSlotsWide:(unsigned int)newSlotsWide;

/** Returns an array of contained icons. */
- (NSArray *)icons;

- (void)addIcons:(NSArray *)someIcons;

/** Puts the icon at the first free slot, enlarging the receiver
    vertically if there is no free spot. */
- (void)addIcon:(NXTIcon *)anIcon;

/** Empties the receiver and puts all icons in a linear way, resizing
    as necessary after all icons have been added. This is faster than
    continuos sending of -addIcon: . */
- (void)fillWithIcons:(NSArray *)icons;

/** Removes the given icon from the receiver.
    Do not use the icon's `-removeFromSuperview' for this
    purpose, it must be properly deregistered. */
- (void)removeIcon:(NXTIcon *)anIcon;

/** Removes all icons in the `icons' from the receiver. */
- (void)removeIcons:(NSArray *)icons;

/** Removes the icon in slot `aSlot' from the receiver. */
- (void)removeIconInSlot:(NXTIconSlot)aSlot;

/** Removes all icons from the receiver. */
- (void)removeAllIcons;

/** Puts the given icon at the desired slot position, removing the
    icon that was there before if necessary.
  
    @param anIcon The icon to put into the receiver.
    @param aSlot The slot into which to put the icon.
*/
- (void)putIcon:(NXTIcon *)anIcon
       intoSlot:(NXTIconSlot)aSlot;

/** Gets the icon which is in a certain slot in the receiver.

    @param aSlot The slot from the icon is to be gotten.
    @returns The icon in the slot, or `nil' if there is nothing in the
    passed slot. */
- (NXTIcon *)iconInSlot:(NXTIconSlot)aSlot;

/** Looks up `anIcon' and returns the slot which it is contained in.
    If the icon can't be found, the returned slot will have both
    `x' and `y' coordinates set to NSNotFound. */
- (NXTIconSlot)slotForIcon:(NXTIcon *)anIcon;

- (NXTIcon *)iconWithLabelString:(NSString *)label;

/** Sets a new slot size in the receiver and repositions all
    icons accordingly. */
- (void)setSlotSize:(NSSize)newSlotSize;
/** Returns the current slot size. */
- (NSSize)slotSize;

/** Defines the ammount of space that the icon's maximum collapsed
    label string width will be set lower than the slot size, i.e.
    the ammount of space around the icon's label when it's collapsed.
    This makes sure the icon labels won't touch. */
- (void)setMaximumCollapsedLabelWidthSpace:(float)aValue;
/** Returns the maximum collapsed label width space. See -[NXTIconView
    setMaximumCollapsedLabelWidthSpace. */
- (float)maximumCollapsedLabelWidthSpace;

/** Sets whether the receiver is supposed to automatically adjusts its size
    to fit it's contents. */
- (void)setAutoAdjustsToFitIcons:(BOOL)flag;
/** Returns YES if the receiver automatically adjusts its size to fit
    its contents. */
- (BOOL)autoAdjustsToFitIcons;
 
/** Sets whether the receiver should enlarge its height to fill
    the enclosing scroll view if it is too small. */
- (void)setAutoAdjustsToFillEnclosingScrollView:(BOOL)flag;
/** Returns YES if the receiver automatically adjusts to fill an enclosing
    scroll view, and NO otherwise. */
- (BOOL)autoAdjustsToFillEnclosingScrollView;

/** Sets whether the receiver should when an icon is removed, leave
    the slot empty (insert a hole) or instead shift any further icons
    one position backwards. */
- (void)setFillsWithHoleWhenRemovingIcon:(BOOL)flag;
/** Returns YES if the receiver fills slots from which icons have been
    removed with holes, and NO if it shifts the icons that follow
    that slot backwards. */
- (BOOL)fillsWithHoleWhenRemovingIcon;

/** Makes the receiver to adjusts its vertical size to be completed filled
    with icons. */
- (void)adjustToFitIcons;

/** Honours autoresizingMask, doesn't honour adjustsToFillEnclosingScrollView */
- (void)adjustFrame;

/** Manually sets how wide the receiver is. This also resizes it and
    the icons get shifted in the way characters would in a text view. */
- (void)setSlotsWide:(unsigned int)newSlotsWide;
/** Returns the number of slots of the receiver horizontal size. */
- (unsigned int)slotsWide;

/** Returns the number of slots the receiver vertical size. */
- (void)setSlotsTall:(unsigned int)newSlotsTall;
/** Set to YES if you eant receiver to contain one horizontal line of icons.
    Set to NO otherwise (default). */
- (void)setSlotsTallFixed:(BOOL)isFixed;
/** Returns the number of rows the receiver is tall. */
- (unsigned int)slotsTall;
- (unsigned int)slotsTallVisible;

/** Sets whether the receiver allows the user to select icons in it. */
- (void)setSelectable:(BOOL)flag;
/** Returns YES if the user can select icons in the receiver, and NO otherwise.*/
- (BOOL)isSelectable;

/** Sets whether the user can select multiple icons by dragging
    a selection rectangle around them or shift-clicking.
    For various icon selection modes see "NXTIconSelectionMode".*/
- (void)setAllowsMultipleSelection:(BOOL)flag;
- (BOOL)allowsMultipleSelection;

- (void)setAllowsEmptySelection:(BOOL)flag;
- (BOOL)allowsEmptySelection;

/** Sets whether the user can selection icons using the arrow keys. */
- (void)setAllowsArrowsSelection:(BOOL)flag;
- (BOOL)allowsArrowsSelection;

/** Sets whether the user can select an icon by simply typing the
    label of the icon. The selection will be updated continuosly as
    the user types. */
- (void)setAllowsAlphanumericSelection:(BOOL)flag;
- (BOOL)allowsAlphanumericSelection;

/** Sets whether the receiver should send a double action to its target
    when the user hits the return key in it. */
- (void)setSendsDoubleActionOnReturn:(BOOL)flag;
- (BOOL)sendsDoubleActionOnReturn;

/** Sets the action target. */
- (void)setTarget:aTarget;
- (id)target;

/** Sets the delegate object. */
- (void)setDelegate:aDelegate;
/** Returns the delegate object. */
- (id)delegate;

/** Sets the message to send to the target when an icon is clicked. */
- (void)setAction:(SEL)anAction;
- (SEL)action;

/** Sets the message to send to the target when an icon is double-clicked.*/
- (void)setDoubleAction:(SEL)anAction;
- (SEL)doubleAction;

/** Sets the message to send to the target when a drag action in an
    icon occurs. Also the "sender" and "event" arguments passed are
    those of the sending icon. */
- (void)setDragAction:(SEL)anAction;
- (SEL)dragAction;

/** Makes the receiver select the passed icons in exclusive mode. */
- (void)selectIcons:(NSSet *)someIcons;
- (void)selectIcons:(NSSet *)someIcons withModifiers:(unsigned)flags;

/** Returns the currently selected icons. */
- (NSSet *)selectedIcons;

/** Causes the receiver to select all icons it contains. */
- (void)selectAll:sender;

/** Must have NSDraggingSource protocol method*/
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;

/** Invoked when an icon is clicked. Override to change selection behavior. */
- (void)iconClicked:sender;
/** Invoked when an icon is double-clicked. */
- (void)iconDoubleClicked:sender;
/** Invoked when an icon is dragged. By default, it just forwards the drag
    action to the receiver's target. */
- (void)iconDragged:sender event:(NSEvent *)ev;

/** Draws the selection rectangle.

    @bugs This method should draw the rectangle in "dotted" way, but
    the GNUstep implementation of NSDottedFrameRect is _SLOW_. */
- (void)drawRect:(NSRect)r;

@end

/** @brief NXTIconView delegate methods. */
@protocol NXTIconViewDelegate

/** This method asks the delegate how to modify a selection.

    The delegate can return an arbitrarily modified set of icons
    to control how this selection attempt is handled. If no icons
    are to be selected (the selection attempt should be ignored),
    the delegate should return `nil'. */
- (NSSet *) iconView:(NXTIconView *)anIconView
   shouldSelectIcons:(NSSet *)icons
       selectionMode:(NXTIconSelectionMode)mode;

/** Notifies the delegate when a selection change occurs. */
- (void)     iconView:(NXTIconView*)anIconView
 didChangeSelectionTo:(NSSet *)selectedIcons;

@end

/** This protocol lists methods an icon view delegate should implement
    in order to be correctly notified of dragging-destination activity
    inside an icon view. They behave identically to those declared
    in NSDraggingDestination, with the exception that they have an
    additional argument which tells which icon view the drag event
    originated from. */
@protocol NXTIconViewDraggingDestination

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
                       iconView:(NXTIconView *)iconView;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
                       iconView:(NXTIconView *)iconView;
- (void)draggingExited:(id <NSDraggingInfo>)sender
              iconView:(NXTIconView *)iconView;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
                       iconView:(NXTIconView *)iconView;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
                    iconView:(NXTIconView *)iconView;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                     iconView:(NXTIconView *)iconView;

- (void)draggingEnded:(id <NSDraggingInfo>)sender
             iconView:(NXTIconView *)iconView;

@end

/** Same as NXTIconViewDraggingDestination, but for the dragging source. */
@protocol NXTIconViewDraggingSource

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXTIconView *)anIconView;

@end
