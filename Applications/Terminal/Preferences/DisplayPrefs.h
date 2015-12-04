/* All Rights reserved */

#import <AppKit/AppKit.h>

#import "Preferences.h"

@interface DisplayPrefs : NSObject <PrefsModule>
{
  id bufferEnabledBtn;
  id bufferLengthMatrix;
  id bufferLengthField;
  id scrollBottomBtn;
  id window;
  id view;
}
- (void)setBufferEnabled:(id)sender;

- (void)setDefault:(id)sender;
- (void)showDefault:(id)sender;
- (void)setWindow:(id)sender;
@end
