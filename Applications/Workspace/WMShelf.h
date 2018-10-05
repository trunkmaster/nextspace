/** @class WMShelf

    Inherits From:	NXIconView

    Declared In:	WMShelf.h

    Class Description

    Represents a Workspace Manager Shelf with icons in it.

    Fundamental characteristics of the WMShelf as a subclass of NXIconView:
    - holds icons of applications and directories with retrievable and
      restorable state;
    - can temporarily hold multi-selection icon;
    - icons can be moved around the Shelf;
    - dragging icon out removes icon from the Shelf;
    - no persistant visible selection of icons;
    - doesn't accept FirstResponder state.

    @author 2018 Sergii Stoian
*/

#import <NXAppKit/NXIconView.h>

@class FileViewer;
@class PathIcon;

@interface WMShelf : NXIconView
{
  // Dragging
  NXIconView *draggedSource;
  NSArray    *draggedPaths;
  PathIcon   *draggedIcon;
  NXIconSlot lastSlotDragEntered;
  NXIconSlot lastSlotDragExited;
  NSPoint    dragPoint;
  NSUInteger draggedMask;

  BOOL       isRootIconDragged;
}

- (PathIcon *)iconInSlot:(NXIconSlot)slot;

- (void)checkIfContentsExist;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

/** Instructs the shelf to reconstruct it's contents from the
    provided meta-information dictionary. */
- (void)reconstructFromRepresentation:(NSDictionary *)aDict;
/** Returns a dictionary representation of the shelf's contents, suitable
    to be stored in e.g. a file or the defaults database. */
- (NSDictionary *)storableRepresentation;

// --- Drag and Drop
- (BOOL)acceptsDragFromSource:(id)dSource
                    withPaths:(NSArray *)dPaths;

@end
