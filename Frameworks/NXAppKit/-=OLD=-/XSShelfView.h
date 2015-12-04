
#import "XSIconView.h"

@class XSShelfIcon;
@protocol NSDraggingInfo;

/** @class XSShelfView
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
@interface XSShelfView : XSIconView
{
  BOOL savedDragResult;
  XSShelfIcon * draggedIcon;
}

 /** Instructs the shelf to reconstruct it's contents from the
     provided meta-information dictionary. */
- (void) reconstructFromRepresentation: (NSDictionary *) aDict;
 /** Returns a dictionary representation of the shelf's contents, suitable
     to be stored in e.g. a file or the defaults database. */
- (NSDictionary *) storableRepresentation;

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

@end

 /// Methods for a shelf view's delegate.
@protocol XSShelfViewDelegate

 /** This method asks the shelf delegate to generate an instance of
     XSShelfIcon (or any of its subclasses) to represent the passed
     user info. This method is used during dragging as well as
     reconstruction of the shelf's contents from a stored dictionary
     representation. */
- (XSShelfIcon *)  shelf: (XSShelfView *) aShelf
 generateIconFromUserInfo: (NSDictionary *) userInfo;

@end

 /// Methods for handling icon drag-ins on shelves.
@protocol XSShelfViewDragging

 /** When a drag-in occurs on the shelf, the shelf asks its delegate
     for the user-info to be associated with the dragged-in icon. If the
     drag is not valid, the delegate should simply return nil. */
- (NSDictionary *) shelf: (XSShelfView *) aShelf
         userInfoForDrag: (id <NSDraggingInfo>) draggingInfo;

- (void) shelf: (XSShelfView *) aShelf
 didAcceptIcon: (XSShelfIcon *) anIcon
        inDrag: (id <NSDraggingInfo>) draggingInfo;

@end
