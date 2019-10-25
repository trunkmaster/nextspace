/* -*- mode: objc -*- */
//
// Project: Preferences
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

#import <AppKit/AppKit.h>
#import <Preferences.h>
#import "AddLayoutPanel.h"

@interface Keyboard : NSObject <PrefsModule>
{
  NSImage *image;
  
  id window;
  id view;
  id sectionBox;
  id sectionsBtn;

  // Model
  id modelBox;
  id modelBrowser;
  id modelDescription;

  // Key Repeat
  id repeatBox;
  id initialRepeatMtrx;
  id repeatRateMtrx;
  id repeatTestField;

  // Data
  NSArray    	*options;
  
  // -- Layouts
  OSEKeyboard	*keyboard;
  NSArray    	*layouts;
  NSArray    	*variants;
  NSDictionary	*layoutSwitchKeys;
  // GUI
  id layoutsBox;
  NSTableView 		*layoutList;
  AddLayoutPanel	*layoutAddPanel;
  id layoutAddBtn;
  id layoutRemoveBtn;
  id layoutUpBtn;
  id layoutDownBtn;
  id layoutShortcutTypeBtn;
  NSPopUpButton *layoutShortcutBtn;
  id layoutShortcutList;

  // Shortcuts
  id shortcutsBox;

  // Numeric Keypad
  id keypadBox;
  id deleteKeyMtrx;
  id numpadMtrx;
  id numLockStateMtrx;

  // Modifiers
  id modifiersBox;
  id composeKeyBtn;
  id swapCAMtrx;
  id capsLockBtn;
  id capsLockMtrx;
}

- (void)sectionButtonClicked:(id)sender;

@end

@interface Keyboard (KeyRepeat)
- (void)repeatAction:(id)sender;
@end

@interface Keyboard (Layouts)
- (void)updateLayouts;
- (void)addLayout:(NSString *)layout variant:(NSString *)variant;
- (void)initSwitchLayoutShortcuts;
- (void)updateSwitchLayoutShortcuts;
@end

@interface Keyboard (NumPad)
- (void)initNumpad;
@end

@interface Keyboard (Modifiers)
- (void)initModifiers;
@end
