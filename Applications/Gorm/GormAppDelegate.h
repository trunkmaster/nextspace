/* GormAppDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
 *
 * This file is part of GNUstep.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#ifndef GormAppDelegate_H_INCLUDE
#define GormAppDelegate_H_INCLUDE

#import <AppKit/NSSavePanel.h>

#import <GormCore/GormCore.h>
#import <GormCore/GormPrefs.h>

#import <GNUstepBase/GSObjCRuntime.h>

@class NSDictionary;
@class NSImage;
@class NSMenu;
@class NSMutableArray;
@class NSSet;
@class GormLanguageViewController;

@interface GormAppDelegate : GormAbstractDelegate <NSOpenSavePanelDelegate>
{
  @private
    GormLanguageViewController *_vc;
}

// preferences
- (IBAction) preferencesPanel: (id) sender;

// Cut/Paste operations
- (IBAction) copy: (id)sender;
- (IBAction) cut: (id)sender;
- (IBAction) paste: (id)sender;
- (IBAction) delete: (id)sender;
- (IBAction) selectAllItems: (id)sender;

// palettes/inspectors.
- (IBAction) inspector: (id) sender;
- (IBAction) palettes: (id) sender;
- (IBAction) loadPalette: (id) sender;

// sound & images
- (IBAction) loadSound: (id) sender;
- (IBAction) loadImage: (id) sender;

// grouping/layout
- (IBAction) groupSelectionInSplitView: (id)sender;
- (IBAction) groupSelectionInBox: (id)sender;
- (IBAction) groupSelectionInScrollView: (id)sender;
- (IBAction) ungroup: (id)sender;

// Classes actions
- (IBAction) createSubclass: (id)sender;
- (IBAction) loadClass: (id)sender;
- (IBAction) createClassFiles: (id)sender;
- (IBAction) instantiateClass: (id)sender;
- (IBAction) addAttributeToClass: (id)sender;
- (IBAction) remove: (id)sender;

// Palettes Actions...
- (IBAction) inspector: (id) sender;
- (IBAction) palettes: (id) sender;
- (IBAction) loadPalette: (id) sender;

// Translation
- (IBAction) importXLIFFDocument: (id)sender;
- (IBAction) exportXLIFFDocument: (id)sender;
- (IBAction) translate: (id)sender;
- (IBAction) exportStrings: (id)sender;

// Print
- (IBAction) print: (id)sender;

@end

#endif // GormAppDelegate_H_INCLUDE
