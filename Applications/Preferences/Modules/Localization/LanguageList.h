/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface LanguageList : NSMatrix
{
  NSScrollView *scrollView;
  NSTextField  *draggedRow;
}

- (void)loadRowsFromArray:(NSArray *)array;
- (NSArray *)arrayFromRows;
- (void)setScrollView:(NSScrollView *)view;

@end
