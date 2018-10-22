/*
  Tests for NSTextField, NSText and so on.
*/

#import <AppKit/AppKit.h>
#import <NXAppKit/NXAppKit.h>

@interface TextTest : NSObject
{
  id window;
  id textToShrink;
  id shrinkedText;
  id shrinkType;
  id leftArr;
  id rightArr;
  id elementType;
  id dotsPosition;
}

- (void)show;

@end
