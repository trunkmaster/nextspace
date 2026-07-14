/* Implementation of class NSAutoresizingMaskLayoutConstraint
   Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson <benjaminkylejohnson@gmail.com>
   Date: 2023

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#ifndef _GNUstep_H_NSAutoresizingMaskLayoutConstraint
#define _GNUstep_H_NSAutoresizingMaskLayoutConstraint

#import <AppKit/NSLayoutConstraint.h>
#import <AppKit/NSView.h>
#import <Foundation/NSGeometry.h>

@interface NSAutoresizingMaskLayoutConstraint : NSLayoutConstraint

+ (NSArray *) constraintsWithAutoresizingMask:
                 (NSAutoresizingMaskOptions)autoresizingMask
                                     subitem: (NSView *)subItem
                                       frame: (NSRect)frame
                                   superitem: (NSView *)superItem
                                      bounds: (NSRect)bounds;

@end

#endif /* _GNUstep_H_NSAutoresizingMaskLayoutConstraint */
