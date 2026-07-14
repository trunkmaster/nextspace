/* Definition of class GSControllerTreeProxy
   Copyright (C) 2024 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 24-06-2024

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

#ifndef _GSControllerTreeProxy_h_GNUSTEP_GUI_INCLUDE
#define _GSControllerTreeProxy_h_GNUSTEP_GUI_INCLUDE

#import "AppKit/NSTreeNode.h"

@class NSTreeController;

#if	defined(__cplusplus)
extern "C" {
#endif
  
@interface GSControllerTreeProxy : NSTreeNode
{
  NSTreeController *_controller;
}

- (instancetype) initWithContent: (id)content
                  withController: (id)controller;

- (NSUInteger) count;

- (NSMutableArray *) children;

- (id) value;

- (void) setValue: (id)value;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* _GSControllerTreeProxy_h_GNUSTEP_GUI_INCLUDE */

