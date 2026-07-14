/* GormFilesOwner.h
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2004
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

#ifndef INCLUDED_GormFilesOwner_h
#define INCLUDED_GormFilesOwner_h

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSMutableArray, NSBrowser, NSString;

/*
 * Each document has a GormFilesOwner object that is used as a placeholder
 * for the owner of the document.
 */
@interface	GormFilesOwner : NSObject
{
  NSString	*className;
}
- (NSString*) className;
- (void) setClassName: (NSString*)aName;
@end

@interface GormFilesOwnerInspector : IBInspector
{
  NSBrowser	        *browser;
  NSMutableArray	*classes;
  BOOL		        hasConnections;
}
- (void) takeClassFrom: (id)sender;
@end

#endif
