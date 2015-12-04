/**
   @class NXSplitView
   @brief NSSplitView modifications

   @author Sergii Stoian
*/

#import <AppKit/NSSplitView.h>

extern NSString *NXSplitViewDividerDidDraw;

@interface NXSplitView : NSSplitView
{
  NSRect    dividerRect;
  NSInteger resizableState;
}

- (NSRect)dividerRect;

- (void)setResizableState:(NSInteger)state;
- (NSInteger)resizableState;

@end

