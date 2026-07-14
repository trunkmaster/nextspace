/* GormProtocol.h
 *
 * Copyright (C) 1999, 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2005
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

#ifndef INCLUDED_GormProtocol_h
#define INCLUDED_GormProtocol_h

#include <Foundation/Foundation.h>

@class GormClassManager;
@class GormInspectorsManager;
@class GormPalettesManager;
@class GormPluginManager;

@class NSMenu;
@class NSString;

@protocol GormAppDelegate

// Connections
- (id) connectSource;
- (id) connectDestination;
- (void) displayConnectionBetween: (id)source and: (id)destination;
- (BOOL) isConnecting;
- (void) stopConnecting;

- (GormPalettesManager*) palettesManager;
- (GormInspectorsManager*) inspectorsManager;
- (GormPluginManager*) pluginManager;

// added for classes support
- (GormClassManager*) classManager;
- (NSMenu*) classMenu;

// Check if we are in the app or the tool
- (BOOL) isInTool;

// Delegate methods to handle issues that may occur
- (BOOL) shouldUpgradeOlderArchive;
- (BOOL) shouldLoadNewerArchive;
- (BOOL) shouldBreakConnectionsForClassNamed: (NSString *)className;
- (BOOL) shouldRenameConnectionsForClassNamed: (NSString *)className toClassName: (NSString *)newName;
- (BOOL) shouldBreakConnectionsModifyingLabel: (NSString *)name isAction: (BOOL)action prompted: (BOOL)prompted;
- (void) couldNotParseClassAtPath: (NSString *)path;
- (void) exceptionWhileParsingClass: (NSException *)localException;
- (BOOL) shouldBreakConnectionsReparsingClass: (NSString *)className;
- (void) exceptionWhileLoadingModel: (NSString *)errorMessage;

@end

#endif
