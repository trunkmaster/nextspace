/* GormPalettesManager.h
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999, 2003
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef INCLUDED_GormPalettesManager_h
#define INCLUDED_GormPalettesManager_h

#include <Foundation/Foundation.h>

@class NSMutableArray, NSMutableDictionary, NSDictionary, NSArray, NSBundle;
@class NSPanel, NSMatrix, NSView;

@interface GormPalettesManager : NSObject
{
  NSPanel		*panel;
  NSMatrix		*selectionView;
  NSView		*dragView;
  NSMutableArray	*bundles;
  NSMutableArray	*palettes;
  int			current;
  BOOL			hiddenDuringTest;
  NSMutableDictionary   *importedClasses;
  NSMutableArray        *importedImages;
  NSMutableArray        *importedSounds;
  NSMutableDictionary   *substituteClasses;
}

// methods for loading and display the palette panels
- (BOOL) loadPalette: (NSString*)path;
- (id) openPalette: (id) sender;
- (NSPanel*) panel;
- (void) setCurrentPalette: (id)anObject;

// methods for importing stuff from palettes
- (void) importClasses: (NSArray *)classes withDictionary: (NSDictionary *)dict;
- (NSDictionary *) importedClasses;
- (void) importImages: (NSArray *)images withBundle: (NSBundle *) bundle;
- (NSArray *) importedImages;
- (void) importSounds: (NSArray *)sounds withBundle: (NSBundle *) bundle;
- (NSArray *) importedSounds;
- (NSDictionary *) substituteClasses;
@end

#endif
