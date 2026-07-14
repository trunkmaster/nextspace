/** Category for converting Windows Strings
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: July 2024

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "NSString+Win32Additions.h"

@implementation NSString (Win32Additions)

+ (GS_GENERIC_CLASS(NSArray, NSString *) *) arrayFromWCharList: (wchar_t *)list
						                                length: (unsigned long)length
{
  NSString *string;
  GS_GENERIC_CLASS(NSArray, NSString *) * array;

  string = [[NSString alloc] initWithBytes: list
				                    length: (length - 2) * sizeof(wchar_t)
				                  encoding: NSUTF16LittleEndianStringEncoding];

  array = [string componentsSeparatedByString: @"\0"];
  RELEASE(string);

  return array;
}

@end
