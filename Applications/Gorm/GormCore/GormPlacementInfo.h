/* GormPlacementInfo.h
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	2002
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
#ifndef	INCLUDED_GormPlacementInfo_h
#define	INCLUDED_GormPlacementInfo_h

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSView, NSMutableArray;

@interface GormPlacementInfo : NSObject
{
@public
  NSView *resizingIn;
  NSRect oldRect;
  BOOL firstPass;
  BOOL hintInitialized;
  NSMutableArray *leftHints;
  NSMutableArray *rightHints;
  NSMutableArray *topHints;
  NSMutableArray *bottomHints;
  NSRect lastLeftRect;
  NSRect lastRightRect;
  NSRect lastTopRect;
  NSRect lastBottomRect;
  NSRect hintFrame;
  NSRect lastFrame;
  IBKnobPosition knob;
}
@end

typedef enum _GormHintBorder
{
  Top, Bottom, Left, Right
} GormHintBorder;

@interface GormPlacementHint : NSObject
{
  GormHintBorder _border;
  float _position;
  float _start;
  float _end;
  NSRect _frame;
}
- (id) initWithBorder: (GormHintBorder) border
	     position: (float) position
	validityStart: (float) start
	  validityEnd: (float) end
		frame: (NSRect) frame;
- (NSRect) rectWithHalfDistance: (int) halfDistance;
- (int) distanceToFrame: (NSRect) frame;
- (float) position;
- (float) start;
- (float) end;
- (NSRect) frame;
- (GormHintBorder) border;
@end

#endif
