/* 
   GormViewKnobs.h

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Gregory John Casamento
   Date: 2004
   
   This file is part of the GNUstep Interface Modeller Application.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef	INCLUDED_GormViewKnobs_h
#define	INCLUDED_GormViewKnobs_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

void
GormShowFastKnobFills(void);

void
GormShowFrameWithKnob(NSRect aRect, IBKnobPosition aKnob);

void
GormDrawKnobsForRect(NSRect aRect);

void
GormDrawOpenKnobsForRect(NSRect aRect);

IBKnobPosition
GormKnobHitInRect(NSRect aFrame, NSPoint p);

NSRect
GormExtBoundsForRect(NSRect aRect);

#endif
