/*
  Controller class for Keyboard preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		28 Nov 2015

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
#import <AppKit/AppKit.h>
#import <Preferences.h>
#import "AddLayoutPanel.h"

@interface Keyboard : NSObject <PrefsModule>
{
  id window;
  id view;
  id sectionBox;
  id sectionsMtrx;

  // Key Repeat
  id repeatBox;
  id initialRepeatMtrx;
  id repeatRateMtrx;
  id repeatTestField;

  // Layouts
  NXKeyboard *keyboard;
  id layoutsBox;
  NSTableView 		*layoutList;
  AddLayoutPanel	*layoutAddPanel;
  id layoutAddBtn;
  id layoutRemoveBtn;
  id layoutUpBtn;
  id layoutDownBtn;
  id layoutShortcutSetBtn;
  id layoutShortcutTextField;
  id layoutShortcutList;

  // Shortcuts
  id shortcutsBrowser;
  id shortcutsBox;

  NSImage *image;
}

- (void)sectionButtonClicked:(id)sender;

@end

@interface Keyboard (KeyRepeat)
- (void)repeatAction:(id)sender;
@end
