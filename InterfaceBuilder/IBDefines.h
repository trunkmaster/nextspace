/* IBDefines.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003
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

#ifndef INCLUDED_IBDEFINES_H
#define INCLUDED_IBDEFINES_H

/*
 * Positions of handles for resizing items.
 */
typedef enum {
  IBBottomLeftKnobPosition = 0,
  IBMiddleLeftKnobPosition = 1,
  IBTopLeftKnobPosition = 2,
  IBTopMiddleKnobPosition = 3,
  IBTopRightKnobPosition = 4,
  IBMiddleRightKnobPosition = 5,
  IBBottomRightKnobPosition = 6,
  IBBottomMiddleKnobPosition = 7,
  IBNoneKnobPosition = -1
} IBKnobPosition;

#endif
