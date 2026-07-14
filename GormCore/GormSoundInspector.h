/** <title>GormSoundInspector</title>

   <abstract>allow user to inspect sound files in Gorm</abstract>

   Copyright (C) 2002 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: September 2002

   This file is part of GNUstep.

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
#ifndef	INCLUDED_GormSoundInspector_h
#define	INCLUDED_GormSoundInspector_h

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class GormClassManager;
@class GormSoundView;

@interface GormSoundInspector : IBInspector
{
  GormSoundView *soundView;
}
- (void) stop: (id)sender;
- (void) play: (id)sender;
- (void) pause: (id)sender;
- (void) record: (id)sender;
@end

#endif
