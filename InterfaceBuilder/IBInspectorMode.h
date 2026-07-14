/* IBInspectorMode
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
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

#ifndef IBINSPECTORMODE_H
#define IBINSPECTORMODE_H

#include <Foundation/Foundation.h>

@class NSString;

@interface IBInspectorMode : NSObject
{
  NSString *identifier;
  NSString *localizedLabel;
  NSString *inspectorClassName;
  id object;
  float ordering;
}
- (id) initWithIdentifier: (NSString *)ident
                forObject: (id)obj
           localizedLabel: (NSString *)lab
       inspectorClassName: (NSString *)cn
		 ordering: (float)ord;
- (void) setIdentifier: (NSString *)ident;
- (NSString *) identifier;
- (void) setObject: (id)obj;
- (id) object;
- (void) setLocalizedLabel: (NSString *)label;
- (NSString *) localizedLabel;
- (void) setInspectorClassName: (NSString *)className;
- (NSString *) inspectorClassName;
- (void) setOrdering: (float)ord;
- (float) ordering;
@end

#endif
