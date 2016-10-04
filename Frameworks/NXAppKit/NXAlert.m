/*
  Class:               NXAlert
  Inherits from:       NSObject
  Class descritopn:    This implementation of alert panel was created
                       in attempt to mimic the behaviour of OPENSTEP's one.
                       This behaviour can be described as following:
                       - panel width is not changing on autosizing;
                       - panel height is automatically changed but cannot be
                         more than half of screen (2/4 of screen);
                       - top edge of panel automatically placed on the center
                         of topmost 1/4 of screen height;
                       - panel brings application in front of other applications;
                       Such hard limits of panel resizing was set up to push
                       developers make some attention to desing of attantion
                       panels conforming to "NeXT User Interface Guidelines".

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

#import <NXSystem/NXScreen.h>
#import "NXAlert.h"

@implementation NXAlert

- (id)initWithTitle:(NSString *)titleText
            message:(NSString *)messageText
      defaultButton:(NSString *)defaultText
    alternateButton:(NSString *)alternateText
        otherButton:(NSString *)otherText
{
  if ([super init] == nil)
    {
      return nil;
    }
  
  if (![NSBundle loadNibNamed:@"NXAlertPanel" owner:self])
    {
      NSLog(@"Cannot open NXAlertPanel model file!");
      return nil;
    }
  
  [titleField setStringValue:titleText];
  [defaultButton setStringValue:defaultText];
  [alternateButton setStringValue:alternateText];
  [otherButton setStringValue:otherText];

  {
    NSArray *messageLines = [messageText componentsSeparatedByString:@"\n"];
    CGFloat fieldWidth;

    fieldWidth = [messageField bounds].size.width;

    for (NSString *l in messageLines)
      {
        if ([[messageField font] widthOfString:l] > fieldWidth)
          {
            // found line wider then message field
          }
      }
  }
  
  [messageField setStringValue:messageText];
  if ([messageText rangeOfString: @"\n"].location != NSNotFound)
    {
      [messageField setAlignment:NSLeftTextAlignment];
    }
  else
    {
      [messageField setAlignment:NSCenterTextAlignment];
    }
  
  // NSSize  screenSize = [[NXScreen sharedScreen] sizeInPixels];
  // NSPoint panelOrigin;

  // [panel center];
  // panelOrigin = [panel frame].origin;
  // panelOrigin.y =
  //   (screenSize.height - screenSize.height/4) - [panel frame].size.height;
  // [panel setFrameOrigin:panelOrigin];

  // [panel makeFirstResponder:defaultButton];
  
  return self;
}

- (void)awakeFromNib
{
}

- (void)sizeToFit
{
}

- (NSInteger)runModal
{
  return [NSApp runModalForWindow:panel];
}
  
- (void)buttonPressed:(id)sender
{
  if ([NSApp modalWindow] != panel)
    {
      NSLog(@"NXAalert panel button pressed when not in modal loop.");
      return;
    }
  
  [NSApp stopModalWithCode:[sender tag]];
}

@end

NSInteger NXRunAlertPanel(NSString *title,
                          NSString *msg,
                          NSString *defaultButton,
                          NSString *alternateButton,
                          NSString *otherButton, ...)
{
  va_list    ap;
  NSString  *message;
  NXAlert   *alrtPanel;
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

  alrtPanel = [[NXAlert alloc] initWithTitle:title
                                     message:message
                               defaultButton:defaultButton
                             alternateButton:alternateButton
                                 otherButton:otherButton];

  result = [alrtPanel runModal];
  [alrtPanel release];
  
  return result;
}
