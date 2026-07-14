// Author: Andrew E. Ruder
// Copyright (C) 2003 by Free Software Foundation, Inc

#include <AppKit/AppKit.h>

#include "GormSetNameController.h"

@implementation GormSetNameController : NSObject
- (NSInteger)runAsModal
{
  NSInteger result;
  
  if (!window)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if (![bundle loadNibNamed: @"GormSetName" owner: self topLevelObjects: NULL])
        {
          return NSAlertAlternateReturn;
        }
    }
  
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: textField];
  
  result = [NSApp runModalForWindow: window];

  return result;
}
- (NSTextField *) textField
{
  return textField;
}
- (void) cancelHit: (id)sender
{
  [window close];
  [NSApp stopModalWithCode: NSAlertAlternateReturn];
}
- (void) okHit: (id)sender
{
  [window close];
  [NSApp stopModalWithCode: NSAlertDefaultReturn];
}
@end
