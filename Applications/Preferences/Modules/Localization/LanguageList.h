/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface LanguageList : NSMatrix
{
  NSScrollView *scrollView;
}

- (void)loadRowsFromArray:(NSArray *)array;
- (void)setScrollView:(NSScrollView *)view;

@end
