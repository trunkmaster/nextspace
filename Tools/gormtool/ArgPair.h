/* ArgPair.h
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#ifndef INCLUDE_ArgPair_H
#define INCLUDE_ArgPair_H

#import <Foundation/NSObject.h>

@class NSString;

@interface ArgPair : NSObject <NSCopying>
{
  NSString *_argument;
  NSString *_value;
}

- (void) setArgument: (NSString *)arg;
- (NSString *) argument;

- (void) setValue: (NSString *)val;
- (NSString *) value;
@end

#endif // INCLUDE_ArgPair_H
