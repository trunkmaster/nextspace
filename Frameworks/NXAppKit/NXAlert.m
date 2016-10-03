/*
  Class:               NXAlert
  Inherits from:       NSObject
  Class descritopn:    Owner of alert panel

  Copyright (C) 2016 Sergii Stoian

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "NXAlert.h"

@implementation NXAlert

- (id)init
{
  if (![NSBundle loadNibNamed:@"NXAlert" owner:self])
    {
      NSLog(@"Cannot open NXAlert panel model file!\n");
      return nil;
    }

  return self;
}

- (void)buttonPressed:(id)sender
{
  if ([NSApp modalWindow] != panel)
    {
      NSLog(@"NXAalert panel buttonAction: when not in modal loop\n");
      return;
    }
  
  [NSApp stopModalWithCode:[sender tag]];
}

@end

NSInteger NSRunAlertPanel(NSString *title,
                          NSString *msg,
                          NSString *defaultButton,
                          NSString *alternateButton,
                          NSString *otherButton, ...)
{
  va_list    ap;
  NSString  *message;
  NXAlert   *panel;
  NSInteger result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat:msg arguments:ap];
  va_end(ap);

  if (NSApp == nil)
    {
      // No NSApp ... not running in a gui application so just log.
      NSLog(@"%@", message);
      return NSAlertDefaultReturn;
    }
  if (defaultButton == nil)
    {
      defaultButton = @"OK";
    }

  panel = getSomePanel(&standardAlertPanel, defaultTitle, title, message,
    defaultButton, alternateButton, otherButton);
  result = [panel runModal];
  NSReleaseAlertPanel(panel);
  
  return result;
}
