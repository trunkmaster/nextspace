/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "ConnectionManager.h"

@implementation ConnectionManager

- (void)showAddConnectionPanel
{
  if (window == nil) {
    if ([NSBundle loadNibNamed:@"AddConnection" owner:self] == NO) {
      NSLog(@"Error loading AddConnection model.");
      return;
    }
  }
  [window center];
  [window makeFirstResponder:connectionName];
  [window makeKeyAndOrderFront:self];
  [NSApp runModalForWindow:window];
}

- (void)awakeFromNib
{
  [deviceList removeAllItems];  
}

- (void)addConnection:(id)sender
{
  /* insert your code here */
}

- (void)setName:(id)sender
{
  /* insert your code here */
}

- (void)setDevice:(id)sender
{
  /* insert your code here */
}

@end
