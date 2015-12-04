/* All Rights reserved */

#include <AppKit/AppKit.h>

#include "Preferences.h"

@interface LinuxPrefs : NSObject <PrefsModule>
{
  id charsetBtn;
  id handleMulticellBtn;
  id commandKeyBtn;
  id escapeKeyBtn;
  id window;
  id view;
}
- (void)setDefault:(id)sender;
- (void)showDefault:(id)sender;
- (void)setWindow:(id)sender;
@end
