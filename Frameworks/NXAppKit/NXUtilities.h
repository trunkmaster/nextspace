/** @brief The various utility functions wich can't be assigned to some class.

    @author Sergii Stoian
*/

#import <AppKit/AppKit.h>

typedef enum {
  NXDotsAtLeft = 0,
  NXDotsAtCenter = 1,
  NXDotsAtRight = 2
} NXDotsPosition;

typedef enum {
  NXSymbolElement = 0,
  NXPathElement = 1,
  NXWordElement = 2
} NXElementType;

NSString *shortenString(NSString *fullString,
                        CGFloat viewWidth, 
                        NSFont *font,
                        NXElementType elementType, 
                        NXDotsPosition dotsPosition);

// NSInteger NXRunAlertPanel(NSString *title,
//                           NSString *msg,
//                           NSString *defaultButton,
//                           NSString *alternateButton,
//                           NSString *otherButton, ...);
