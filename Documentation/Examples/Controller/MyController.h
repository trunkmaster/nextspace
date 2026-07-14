/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "WinController.h"

@interface MyController : NSObject
{
  id value;
  WinController *winController;
}
- (void) buttonPressed: (id)sender;
@end
