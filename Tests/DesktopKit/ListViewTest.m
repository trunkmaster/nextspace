#import "ListViewTest.h"

@implementation ListViewTest : NSObject

- (id)init
{
  self = [super init];

  if (![NSBundle loadNibNamed:@"ListView" owner:self]) {
    NSLog (@"ListViewTest: Could not load nib, aborting.");
    return nil;
  }

  return self;
}

- (void)awakeFromNib
{
  [window center];  
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
