/*
  Class:               SetTitlePanel
  Inherits from:       NSObject
  Class descritopn:    Panel for setting cutom title to terminal window.
                       Called from menu Shell->Set Title...

  Copyright (C) 2017 Sergii Stoian

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

#import "SetTitlePanel.h"
#import "Defaults.h"

@implementation SetTitlePanel : NSObject

- (void)activatePanel
{
  if (titlePanel == nil)
    {
      [NSBundle loadNibNamed:@"SetTitlePanel" owner:self];
    }

  [titlePanel makeKeyAndOrderFront:self];
  [titleField
    setStringValue:[[[NSApp delegate] preferencesForWindow:[NSApp mainWindow] live:YES] customTitle]];
}

- (void)awakeFromNib
{
  [titlePanel makeFirstResponder:titleField];
}

- (void)setTitle:(id)sender
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSUInteger     titleBarMask = [Defaults titleBarElementsMask];

  titleBarMask |= TitleBarCustomTitle;
  [ud setInteger:titleBarMask forKey:TitleBarElementsMaskKey];
  
  [ud setObject:[titleField stringValue]
         forKey:TitleBarCustomTitleKey];

  [ud synchronize];
  [Defaults readTitleBarDefaults];

  [titlePanel close];
}

- (void)closeSetTitlePanel:(id)sender
{
  [titlePanel close];
}

@end
