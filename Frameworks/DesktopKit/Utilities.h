/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

/** @brief The various utility functions wich can't be assigned to some class.

    @author Sergii Stoian
*/

#import <AppKit/AppKit.h>

typedef enum {
  NXTDotsAtLeft = 0,
  NXTDotsAtCenter = 1,
  NXTDotsAtRight = 2
} NXTDotsPosition;

typedef enum {
  NXSymbolElement = 0,
  NXPathElement = 1,
  NXWordElement = 2
} NXTElementType;

NSString *NXTShortenString(NSString *fullString,
                          CGFloat viewWidth, 
                          NSFont *font,
                          NXTElementType elementType, 
                          NXTDotsPosition dotsPosition);
