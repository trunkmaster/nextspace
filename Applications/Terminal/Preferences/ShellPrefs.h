/* All Rights reserved */

#import "Preferences.h"

@interface ShellPrefs : NSObject <PrefsModule>
{
  id loginShellBtn;
  id shellField;
  id window;
  id view;
}
- (void) setLoginShell: (id)sender;
@end
