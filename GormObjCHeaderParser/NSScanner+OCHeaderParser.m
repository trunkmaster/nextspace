/* NSScanner+OCHeaderParser.h
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2002
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
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */


#include <Foundation/Foundation.h>

#include <GormObjCHeaderParser/NSScanner+OCHeaderParser.h>

@implementation NSScanner (OCHeaderParser)
- (void) scanUpToAndIncludingString: (NSString *)string 
			 intoString: (NSString **)buffer
{
  NSString *buffer2 = nil;
  [self scanUpToString: string intoString: buffer];
  [self scanString: string intoString: &buffer2];

  if(buffer != NULL)
    {
      if(*buffer != NULL)
	{
	  *buffer = [*buffer stringByAppendingString: buffer2];
	}
    }
}

- (void) scanUpToAndIncludingCharactersFromSet: (NSCharacterSet *)set 
				    intoString: (NSString **)buffer
{
  NSString *buffer2 = nil;  
  [self scanUpToCharactersFromSet: set intoString: buffer];
  [self scanCharactersFromSet: set intoString: &buffer2]; 
  if(buffer != NULL)
    {
      if(*buffer != NULL)
	{
	  *buffer = [*buffer stringByAppendingString: buffer2];
	}
    }
}
@end
