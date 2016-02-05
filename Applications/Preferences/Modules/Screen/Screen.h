/*
  Screen.m

  Controller class for Screen preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/

#import <AppKit/NSImage.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSTextField.h>

#import <NXSystem/NXScreen.h>

#import <Preferences.h>

@interface DisplayBox : NSBox
{
  NSTextField *nameField;
  
  BOOL isMainDisplay;
  BOOL isSelected;
}

- (void)setName:(NSString *)name;

- (void)setMainDisplay:(BOOL)isMain;
- (void)setSelected:(BOOL)selected;
@end

@interface ScreenCanvas : NSBox
{
}
@end

@interface ScreenPreferences: NSObject <PrefsModule>
{
  id view;
  id window;
  id canvas;

  NSImage *image;

  NSMutableArray *displayBoxList;
  CGFloat scaleFactor;
}

- (void)updateDisplayBoxList;
- (void)arrangeDisplayBoxes;

- (void)displayBoxClicked:(DisplayBox *)sender;

@end


