/* NSFontManager+GormExtensions.h
 *
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2005
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

#ifndef INCLUDED_NSFontManager_GormExtensions_h
#define INCLUDED_NSFontManager_GormExtensions_h

#include <AppKit/AppKit.h>

@interface NSFontManager (GormExtensions)

/**
 * Override for sendAction in NSFontManager.  This method calls the action on the 
 * last edited object if the attempt to send the action to the first responder is
 * unsuccessful.   This allows the font to be more easily set.
 */
- (BOOL) sendAction;

@end

#endif
