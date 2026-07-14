/* Interface of class NSTableViewRowAction
   Copyright (C) 2022 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 04-09-2022

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

#ifndef _NSTableViewRowAction_h_GNUSTEP_GUI_INCLUDE
#define _NSTableViewRowAction_h_GNUSTEP_GUI_INCLUDE

#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@interface NSTableViewRowAction : NSObject

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSTableViewRowAction_h_GNUSTEP_GUI_INCLUDE */

