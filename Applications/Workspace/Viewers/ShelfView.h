
#import <NXAppKit/NXIconView.h>

@class FileViewer;
@class PathIcon;
@protocol NSDraggingInfo;

/** @class ShelfView
    @brief This class represents a shelf with icons in it.

    It is is very simmilar to the classic shelf of the NeXT workspace
    manager. It is an icon view that contains icons associated with
    various meta-information in order to represent also data other than
    file system paths.
 
    A shelf provides methods to save it's contents (the meta-information
    of each icon) to a dictionary and again re-construct it's contents from
    such information. A shelf remembers the icon slots in which the icons
    were contained.

    @author Saso Kiselkov
*/
@interface ShelfView : NXIconView
{
  FileViewer *_owner;

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

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer;
// - (void)configure;
- (void)checkIfContentsExist;
- (void)shelfAddMountedRemovableMedia;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

/** Instructs the shelf to reconstruct it's contents from the
    provided meta-information dictionary. */
- (void)reconstructFromRepresentation:(NSDictionary *)aDict;
/** Returns a dictionary representation of the shelf's contents, suitable
    to be stored in e.g. a file or the defaults database. */
- (NSDictionary *)storableRepresentation;

- (void)iconSlotWidthChanged:(NSNotification *)notif;

@end

/// Methods for a shelf view's delegate.
@protocol ShelfViewDelegate

/** This method asks the shelf delegate to generate an instance of
    ShelfIcon (or any of its subclasses) to represent the passed
    user info. This method is used during dragging as well as
    reconstruction of the shelf's contents from a stored dictionary
    representation. */
- (PathIcon *)shelf:(ShelfView *)aShelf
 createIconForPaths:(NSArray *)paths;

@end

 /// Methods for handling icon drag-ins on shelves.
@protocol ShelfViewDragging

 /** When a drag-in occurs on the shelf, the shelf asks its delegate
     for the user-info to be associated with the dragged-in icon. If the
     drag is not valid, the delegate should simply return nil. */
- (NSArray *)shelf:(ShelfView *)aShelf
      pathsForDrag:(id <NSDraggingInfo>)draggingInfo;

- (void) shelf:(ShelfView *)aShelf
 didAcceptIcon:(PathIcon *)anIcon
        inDrag:(id <NSDraggingInfo>)draggingInfo;

@end
