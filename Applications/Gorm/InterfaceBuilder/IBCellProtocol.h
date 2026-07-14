/* IBViewProtocol.h
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef INCLUDED_IBCELLPROTOCOL_H
#define INCLUDED_IBCELLPROTOCOL_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBDefines.h>

@protocol IBCellProtocol
/**
 * Called when the cell is about to be alt-dragged.
 */
- (void) cellWillAltDragWithSize: (NSSize)size;

/**
 * Maximum size for the cell.
 */
- (NSSize) maximumSizeForCellSize: (NSSize)size 
                     knobPosition: (IBKnobPosition)position;

/**
 * Minimum size for the cell.
 */
- (NSSize) minimumSizeForCellSize: (NSSize)size 
                     knobPosition: (IBKnobPosition)position;
@end

#endif
