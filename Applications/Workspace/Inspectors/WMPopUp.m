/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <GNUstepGUI/GSTheme.h>
#import <AppKit/NSAttributedString.h>
#import "WMPopUp.h"

@implementation PopUpListCell

- (void)drawBorderAndBackgroundWithFrame:(NSRect)cellFrame
                                  inView:(NSView *)controlView
{
  // NSLog(@"PopUpListCell: drawBorderAndBackgroundWithFrame:inView:!");
  if (!_cell.is_disabled)
    {
      [super drawBorderAndBackgroundWithFrame:cellFrame
                                       inView:controlView];
    }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView*)controlView
{
  // NSLog(@"PopUpListCell: drawInteriorWithFrame:inView:! %@, %@, %@",
  //       [self title], [_contents className], [self attributedTitle]);
  
  if (_cell.is_disabled)
    {
      NSMutableAttributedString  *t = [[self attributedTitle] mutableCopy];
      NSRange r;
      NSMutableDictionary *md;

      md = [[t attributesAtIndex:0 effectiveRange:&r] mutableCopy];
      
      [md setObject:[NSColor controlTextColor]
             forKey:NSForegroundColorAttributeName];
      
      [md setObject:[NSParagraphStyle defaultParagraphStyle]
             forKey:NSParagraphStyleAttributeName];

      [t setAttributes:md range:r];
      [md release];
      
      [self _drawAttributedText:t inFrame:cellFrame];
      [t release];
    }
  else
    {
      [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end
