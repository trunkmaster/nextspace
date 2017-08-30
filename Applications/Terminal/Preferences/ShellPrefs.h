/* All Rights reserved */

#import "Preferences.h"

@interface ShellPrefs : NSObject <PrefsModule>
{
  id shellPopup;
  id loginShellBtn;
  id shellField; //
  id commandLabel;
  id commandField;
  id window;
  id view;
}
- (void) setLoginShell: (id)sender;
@end
