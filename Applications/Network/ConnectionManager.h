/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface ConnectionManager : NSObject
{
  id deviceList;
  id connectionName;
  id window;
}
- (void)showAddConnectionPanel;
@end
