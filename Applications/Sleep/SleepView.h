#import <AppKit/AppKit.h>

@interface SleepView : NSView
{
  id target;
  SEL action;
}
- (void)setTarget:(id)object action:(SEL)selector;
@end
