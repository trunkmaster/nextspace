/*
  Class:               CursorsTest
  Inherits from:       NSObject
  Class descritopn:    Testing GNUstep mouse cursors operations.

  Copyright (c) 2017 Sergii Stoian

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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface CursorBox : NSBox
{
  NSCursor *_cursor;
}

- (void)setCursor:(NSCursor *)c;

@end

@interface CursorsTest : NSObject
{
  id window;
  CursorBox *arrowField;
  CursorBox *IBeamField;
  CursorBox *closedHandField;
  CursorBox *conextualMenuField;
  CursorBox *crosshairField;
  CursorBox *disappearingItemField;
  CursorBox *dragCopyField;
  CursorBox *dragLinkField;
  CursorBox *openHandField;
  CursorBox *operationNotAllowedField;
  CursorBox *pointingHandField;
  CursorBox *resizeDownField;
  CursorBox *resizeLeftField;
  CursorBox *resizeLeftRightField;
  CursorBox *resizeRightField;
  CursorBox *resizeUpDownField;
  CursorBox *resizeUpField;
}

- (void)show;

@end
