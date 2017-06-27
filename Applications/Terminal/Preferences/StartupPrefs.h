/* All Rights reserved */

#include "Preferences.h"

@interface StartupPrefs : NSObject <PrefsModule>
{
  id actionsMatrix;
  id autolaunchBtn;
  id filePathField;
  id window;
  id view;

  Defaults *defs;
}
- (void) setFilePath: (id)sender;
- (void) setAction: (id)sender;
- (void) setAutolaunch: (id)sender;
@end
