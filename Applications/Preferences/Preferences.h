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
/**
   Preferences.h declares a category that adds four methods to the Application 
   class of the Application Kit. These methods make it easier for your 
   Preferences module to:

   - Locate its interface when the module is loaded
   - Enable and disable items in the Windows and Edit menus of the Preferences
     application
   - Access the views contained in the Preferences window
*/

#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSApplication.h>

@protocol PrefsModule <NSObject>

- (NSString *)buttonCaption;
- (NSImage *)buttonImage;
- (NSView *)view;

@end

// @interface NSApplication (Preferences)

// /** Returns the id of the Preferences window, enabling you to alter its content 
//     view, for example. */
// - (NSWindow *)appWindow;

// /** Enables and disables menu items in Preferences' Edit menu. 
//     aMask specifies which items are to be enabled.  
//     For example, this message enables the Cut and Copy commands:

//     [NSApp enableEdit: CUT_ITEM|COPY_ITEM];

//     The permitted values for aMask are:
//     CUT_ITEM
//     COPY_ITEM
//     PASTE_ITEM
//     SELECTALL_ITEM
//     EDIT_ALL_ITEMS */
// - (void)enableEdit:(NSUInteger)aMask;

// /** Enables and disables menu items in Preferences' Window menu.
//     aMask specifies which items are to be enabled. The permitted values for 
//     aMask are:

//     MINIATURIZE_ITEM
//     CLOSE_ITEM
//     WINDOW_ALL_ITEMS */
// - (void)enableWindow:(NSUInteger)aMask;

// /** Loads the nib file named "name.nib" and makes anOwner its owner.  

//     This is a convenience method that searches for the nib file in the 
//     appropriate language subproject of the bundle from which the class of 
//     anOwner was loaded. */
// - loadNibForLayout:(const char *)name owner:anOwner;

// @end
