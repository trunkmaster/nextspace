/* All Rights reserved */

#include "Preferences.h"

@interface TitleBarPrefs : NSObject <PrefsModule>
{
  id customTitleBtn;
  id customTitleField;
  id deviceNameBtn;
  id filenameBtn;
  id demoTitleBarField;
  id shellPathBth;
  id window;
  id windowSizeBtn;
  id view;
}
- (void)setElements:(id)sender;

- (void)setDefault:(id)sender;
- (void)showDefault:(id)sender;
- (void)setWindow:(id)sender;
@end
