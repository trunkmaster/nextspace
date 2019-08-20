/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: This implementation of alert panel was created
//              in attempt to mimic the behaviour of OPENSTEP's one.
//              This behaviour can be described as following:
//                - panel width is not changing on autosizing;
//                - panel height is automatically changed but cannot be
//                  more than half of screen;
//                - top edge of panel automatically placed on the center
//                  of topmost 1/4 of screen height;
//                - panel brings application in front of other applications;
//                  Such hard limits of panel resizing was set up to push
//                  developers make some attention to desing of alert
//                  panels conforming to "NeXT User Interface Guidelines".
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#include <AppKit/AppKit.h>

@interface NXTAlert : NSObject
{
  NSPanel        *panel;
  NSTextField    *titleField;
  NSImageView    *icon;
  NSTextView     *messageView;
  NSButton       *defaultButton;
  NSButton       *alternateButton;
  NSButton       *otherButton;

  NSString       *titleString;
  NSString       *messageString;
  NSString       *defaultString;
  NSString       *alternateString;
  NSString       *otherString;

  NSMutableArray *buttons;
  NSUInteger     maxButtonWidth;
  NSUInteger     minButtonWidth;
}

- (id)initWithTitle:(NSString *)titleText
            message:(NSString *)messageText
      defaultButton:(NSString *)defaultText
    alternateButton:(NSString *)alternateText
        otherButton:(NSString *)otherText;

- (void)createPanel;
- (void)setTitle:(NSString *)titleText
         message:(NSString *)messageText
       defaultBT:(NSString *)defaultText
     alternateBT:(NSString *)alternateText
         otherBT:(NSString *)otherText;

- (NSPanel *)panel;
- (void)show;
- (NSInteger)runModal;

- (void)buttonPressed:(id)sender;
@end

extern void NXTRunExceptionPanel(NSString *title,
                                 NSString *msg,
                                 NSString *defaultButton,
                                 NSString *alternateButton,
                                 NSString *otherButton, ...);

extern NSInteger NXTRunAlertPanel(NSString *title,
                                  NSString *msg,
                                  NSString *defaultButton,
                                  NSString *alternateButton,
                                  NSString *otherButton, ...);
