/* All Rights reserved */

#include "Preferences.h"

@interface WindowPrefs : NSObject <PrefsModule>
{
  id columnsField;
  id fontField;
  id rowsField;
  id setFontBtn;
  id shellExitMatrix;
  id useBoldBtn;
  id window;
  id view;
}
- (void)setFont:(id)sender;

- (void)setDefault:(id)sender;
- (void)showDefault:(id)sender;
- (void)setWindow:(id)sender;
@end
