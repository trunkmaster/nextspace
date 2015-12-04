
#import "XSIcon.h"

/** @class XSShelfIcon
    @brief An icon used in an XSShelf.
 
    This class adds the ability to carry user information dictionaries
    in the icon. This is required inside shelves, which have no other
    way of storting information about the icons.

    @author Saso Kiselkov
 */
@interface XSShelfIcon : XSIcon
{
  NSDictionary *userInfo;
}

 /// Sets the receiver's user info.
- (void)setUserInfo:(NSDictionary *)ui;

 /// Returns the receiver's user info.
- (NSDictionary *)userInfo;

@end
