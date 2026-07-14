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

#ifndef INCLUDED_IBVIEWPROTOCOL_H
#define INCLUDED_IBVIEWPROTOCOL_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBDefines.h>


// forward references
@class NSColor;

@protocol IBViewProtocol
/**
 * Returns YES, if color can be set at the given point in the view.
 */
- (BOOL) acceptsColor: (NSColor*)color atPoint: (NSPoint)point;

/**
 * Returns YES if receiver can be alt-dragged.
 */
- (BOOL) allowsAltDragging;

/**
 * Sets color at point in the receiver.
 */
- (void) depositColor: (NSColor*)color atPoint: (NSPoint)point;

/**
 * The maximum size for a knob surrounding the receiver.
 */
- (NSSize) maximumSizeFromKnobPosition: (IBKnobPosition)knobPosition;

/**
 * The minimum size for a knob surrounding the receiver.
 */
- (NSSize) minimumSizeFromKnobPosition: (IBKnobPosition)position;

/**
 * Places and resizes the receiver using newFrame.
 */
- (void) placeView: (NSRect)newFrame;
@end

#endif
