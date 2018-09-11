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

#import <AppKit/NSView.h>
#import <AppKit/NSDragging.h>

@class NSMutableArray, NXIcon;
@protocol NSDraggingInfo;

/** @struct NXIconSlot
    @brief A icon slot inside an icon view.

    Instances of NXIconView (and its subclasses), or simply icon views,
    indentify the position an icon occupies in the icon view by a slot. */
typedef struct {
    int x, y;
} NXIconSlot;

/** @enum NXIconSelectionMode
    @brief The mode by which the icon view should select icons.
*/
typedef enum {
  /** Normal clicking of icons - exclusive selection of only
      these icons. */
  NXIconSelectionExclusiveMode,
  /** Shift-clicking - addition of the clicked icons to the
      current selection. */
  NXIconSelectionAdditiveMode,
  /** Control-clicking - removal of the clicked icons from the
      current selection. */
  NXIconSelectionSubtractiveMode
} NXIconSelectionMode;

/** A shorthand function to construct an icon slot from provided
    X and Y coordinates. */
static inline NXIconSlot NXMakeIconSlot(NSUInteger x, NSUInteger y)
{
  NXIconSlot slot;

  slot.x = x;
  slot.y = y;

  return slot;
}

@interface NXIconView : NSView
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
  NXIconSlot lastIcon;

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
  NXIconSlot selectedIconSlot;

  NSString * lastAlphaString;
  NSDate * lastHitDate;

  /// This contains the saved result of draggingEntered...
  unsigned int dragEnteredResult;
}

/** Sets the default slot size that all subsequently created icon
    views will have. */
+ (void)setDefaultSlotSize:(NSSize)newSize;
/** Returns the default slot size. */
+ (NSSize)defaultSlotSize;

/** Sets the default maximum collapsed label width space.
    See -[NXIconView setMaximumCollapsedLabelWidthSpace:]. */
+ (void)setDefaultMaximumCollapsedLabelWidthSpace:(float)aValue;
/** Returns the default maximum collapsed label width space.
    See -[NXIconView setMaximumCollapsedLabelWidthSpace:]. */
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
- (void)addIcon:(NXIcon *)anIcon;

/** Empties the receiver and puts all icons in a linear way, resizing
    as necessary after all icons have been added. This is faster than
    continuos sending of -addIcon: . */
- (void)fillWithIcons:(NSArray *)icons;

/** Removes the given icon from the receiver.
    Do not use the icon's `-removeFromSuperview' for this
    purpose, it must be properly deregistered. */
- (void)removeIcon:(NXIcon *)anIcon;

/** Removes all icons in the `icons' from the receiver. */
- (void)removeIcons:(NSArray *)icons;

/** Removes the icon in slot `aSlot' from the receiver. */
- (void)removeIconInSlot:(NXIconSlot)aSlot;

/** Removes all icons from the receiver. */
- (void)removeAllIcons;

/** Puts the given icon at the desired slot position, removing the
    icon that was there before if necessary.
  
    @param anIcon The icon to put into the receiver.
    @param aSlot The slot into which to put the icon.
*/
- (void)putIcon:(NXIcon *)anIcon
       intoSlot:(NXIconSlot)aSlot;

/** Gets the icon which is in a certain slot in the receiver.

    @param aSlot The slot from the icon is to be gotten.
    @returns The icon in the slot, or `nil' if there is nothing in the
    passed slot. */
- (NXIcon *)iconInSlot:(NXIconSlot)aSlot;

/** Looks up `anIcon' and returns the slot which it is contained in.
    If the icon can't be found, the returned slot will have both
    `x' and `y' coordinates set to NSNotFound. */
- (NXIconSlot)slotForIcon:(NXIcon *)anIcon;

- (NXIcon *)iconWithLabelString:(NSString *)label;

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
/** Returns the maximum collapsed label width space. See -[NXIconView
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
    For various icon selection modes see "NXIconSelectionMode".*/
- (void)setAllowsMultipleSelection:(BOOL)flag;
/** Returns YES if the receiver allows multiple selection, and NO otherwise.*/
- (BOOL)allowsMultipleSelection;

/** Sets whether the user can selection icons using the arrow keys. */
- (void)setAllowsArrowsSelection:(BOOL)flag;
/** Returns YES if the user can selection icons using arrow keys, and
    NO otherwise. */
- (BOOL)allowsArrowsSelection;

/** Sets whether the user can select an icon by simply typing the
    label of the icon. The selection will be updated continuosly as
    the user types. */
- (void)setAllowsAlphanumericSelection:(BOOL)flag;
/** Returns YES if the user can select an icon by typing it's label, and
    NO otherwise. */
- (BOOL)allowsAlphanumericSelection;

/** Sets whether the receiver should send a double action to its target
    when the user hits the return key in it. */
- (void)setSendsDoubleActionOnReturn:(BOOL)flag;
/** Returns YES if the receiver should send double actions on return key
    presses, and NO otherwise. See -[NXIconView
    setSendsDoubleActionOnReturn:]. */
- (BOOL)sendsDoubleActionOnReturn;

/** Sets the action target. */
- (void)setTarget:aTarget;
/** Returns the action target. */
- target;

/** Sets the delegate object. */
- (void)setDelegate:aDelegate;
/** Returns the delegate object. */
- delegate;

/** Sets the message to send to the target when an icon is clicked. */
- (void)setAction:(SEL)anAction;
/** Returns the icon click message. See -[NXIconView setAction:]. */
- (SEL)action;

/** Sets the message to send to the target when an icon is double-clicked.*/
- (void)setDoubleAction:(SEL)anAction;
/** Returns the icon double-click message. See -[NXIconView setDoubleAction:]. */
- (SEL)doubleAction;

/** Sets the message to send to the target when a drag action in an
    icon occurs. Also the "sender" and "event" arguments passed are
    those of the sending icon. */
- (void)setDragAction:(SEL)anAction;
/** Returns the current drag-action for icon dragging. */
- (SEL)dragAction;

/** Makes the receiver select the passed icons in exclusive mode. */
- (void)selectIcons:(NSSet *)someIcons;

/** Returns the currently selected icons. */
- (NSSet *)selectedIcons;
- (void)selectIcons:(NSSet *)someIcons withModifiers:(unsigned)flags;

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

/** @brief NXIconView delegate methods. */
@protocol NXIconViewDelegate

/** This method asks the delegate how to modify a selection.

    The delegate can return an arbitrarily modified set of icons
    to control how this selection attempt is handled. If no icons
    are to be selected (the selection attempt should be ignored),
    the delegate should return `nil'. */
- (NSSet *) iconView:(NXIconView *)anIconView
   shouldSelectIcons:(NSSet *)icons
       selectionMode:(NXIconSelectionMode)mode;

/** Notifies the delegate when a selection change occurs. */
- (void)     iconView:(NXIconView*)anIconView
 didChangeSelectionTo:(NSSet *)selectedIcons;

@end

/** This protocol lists methods an icon view delegate should implement
    in order to be correctly notified of dragging-destination activity
    inside an icon view. They behave identically to those declared
    in NSDraggingDestination, with the exception that they have an
    additional argument which tells which icon view the drag event
    originated from. */
@protocol NXIconViewDraggingDestination

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
                       iconView:(NXIconView *)iconView;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
                       iconView:(NXIconView *)iconView;
- (void)draggingExited:(id <NSDraggingInfo>)sender
              iconView:(NXIconView *)iconView;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
                       iconView:(NXIconView *)iconView;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
                    iconView:(NXIconView *)iconView;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                     iconView:(NXIconView *)iconView;

- (void)draggingEnded:(id <NSDraggingInfo>)sender
             iconView:(NXIconView *)iconView;

@end

/** Same as NXIconViewDraggingDestination, but for the dragging source. */
@protocol NXIconViewDraggingSource

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXIconView *)anIconView;

@end
