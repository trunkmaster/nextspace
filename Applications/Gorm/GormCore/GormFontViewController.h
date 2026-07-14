/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface GormFontViewController : NSObject
{
  id fontSelector;
  id view;
  id encodeButton;
}
+ (GormFontViewController *) sharedGormFontViewController;
- (NSFont *) convertFont: (NSFont *)oldFont;
- (void) selectFont: (id)sender;
- (id) view;
// - (void) changeFont: (id)sender;
@end
