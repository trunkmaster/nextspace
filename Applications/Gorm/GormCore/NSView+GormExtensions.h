/* NSView+GormExtensions.h
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2004
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

#ifndef INCLUDED_NSView_GormExtensions_h
#define INCLUDED_NSView_GormExtensions_h

#include <AppKit/AppKit.h>

@class NSArray;

@interface NSView (GormExtensions)
/**
 * All superviews of the receiver.
 */
- (NSArray *) superviews;

/**
 * Returns YES if the receiver has an instance of the Class cls 
 * as a superview.
 */
- (BOOL) hasSuperviewKindOfClass: (Class)cls;

/**
 * Move the subview sv in reciever to the end of the reciever's
 * display list.   This has the effect of making it appear in front
 * of the other views.
 */
- (void) moveViewToFront: (NSView *)sv;

/**
 * Move the subview sv in reciever to the beginning of the reciever's
 * display list.   This has the effect of making it appear in back
 * of the other views.
 */
- (void) moveViewToBack: (NSView *)sv;
@end

#endif
