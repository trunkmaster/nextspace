/* GormObjectInspector.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
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

#ifndef INCLUDED_GormObjectInspector_h
#define INCLUDED_GormObjectInspector_h

#include "GormPrivate.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-variable"
static NSString	*typeId = @"Object";
static NSString	*typeChar = @"Character or Boolean";
static NSString	*typeUChar = @"Unsigned character/bool";
static NSString	*typeInt = @"Integer";
static NSString	*typeUInt = @"Unsigned integer";
static NSString	*typeFloat = @"Float";
static NSString	*typeDouble = @"Double";
#pragma GCC diagnostic pop

@interface GormObjectInspector : IBInspector
{
  NSBrowser		*browser;
  NSMutableArray	*sets;
  NSMutableDictionary	*gets;
  NSMutableDictionary	*types;
  NSButton		*label;
  NSTextField		*value;
  BOOL			isString;
}

- (void) update: (id)sender;

@end

#endif

