/* All Rights reserved */

#include <AppKit/AppKit.h>

#include "Preferences.h"

@interface ColorsPrefs : NSObject <PrefsModule>
{
  id windowBGColorBtn;
  id blinkTextColorBtn;
  id boldTextColorBtn;
  id useBoldBtn;
  id cursorBlinkingBtn;
  id cursorColorBtn;
  id cursorStyleMatrix;
  id inverseTextBGColorBtn;
  id inverseTextFGColor;
  id inverseTextLabel;
  id normalTextColorBtn;
  id windowSelectionColorBtn;
  id window;

  id view;
}
- (void) setDefault: (id)sender;
- (void) setWindow: (id)sender;
- (void) showDefault: (id)sender;
@end
