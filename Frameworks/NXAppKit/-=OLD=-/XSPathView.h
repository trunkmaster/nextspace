
#import "XSIconView.h"

@class NSArray, NSString;
@class NSImage;

@class XSIcon;

 /** @class XSPathView
     @brief A view that represents a horizontal array of icons to show a path.

     This view is a typical horizontal array of icons as we know it from
     the workspace manager's file viewer. It shows small arrows between
     the icons which represent path components.

     @author Saso Kiselkov
 */
@interface XSPathView : XSIconView
{
  // the path displayed
  NSString * path;
  // the trailing names
  NSArray * names;

  NSArray * iconDragTypes;

  XSIcon * multipleSelection;

  Class iconClass;
}

+ (void) setIconClass: (Class) aClass;
+ (Class) iconClass;

 /** Sets the path the receiver is to display. As the receiver will
     be filling itself with icons, it will query it's delegate for
     the images and labels for the icons by sending it messages which
     are declared in the XSPathViewDelegate protocol.

     @param aPath The path to display.
     @param names An array of trailing file names. In case this array has
        one member, that file's icon is displayed as the right most icon.
        In case there are more names a "multiple selection" is appended
        showing the number of names passed to the receiver.

     @see XSPathViewDelegate.
 */
- (void) setPath: (NSString *) aPath
   trailingNames: (NSArray *) names;

 /// Returns the path currently displayed by the receiver.
- (NSString *) path;
 /// Returns the names currently displayed by the receiver.
- (NSArray *) trailingNames;

 /** Returns the paths that are represented in the receiver by the
     specified icon. */
- (NSArray *) pathsForIcon: (XSIcon *) anIcon;

- (void) setIconClass: (Class) aClass;
- (Class) iconClass;

- (void) setIconDragTypes: (NSArray *) types;
- (NSArray *) iconDragTypes;

@end

 /** Methods that a path view delegate should implement in order to
     react to certain situations in the path view. */
@protocol XSPathViewDelegate

 /** This method asks the path view delegate to provide an image
     for the icon image at the specified path.
     
     @param aPathView The path view which made the request.
     @param aPath The path of the icon.
     @return The image to display in the icon. */
- (NSImage *) pathView: (XSPathView *) aPathView
    imageForIconAtPath: (NSString *) aPath;

 /** Simmilar to -[XSPathViewDelegate pathView:imageForIconAtPath:], but
     it asks for the icon label.

     @return The string to use for the icon's label.

     @see -[XSPathViewDelegate pathView:imageForIconAtPath:] */
- (NSString *) pathView: (XSPathView *) aPathView
     labelForIconAtPath: (NSString *) aPath;

 /** Notifies the delegate when the user clicked an icon in the path
     view which caused it to change it's path.
     
     @param aPathView The path view which the change occured in.
     @param newPath The new path in the path view.
 */
- (void) pathView: (XSPathView *) aPathView
  didChangePathTo: (NSString *) newPath;

@end
