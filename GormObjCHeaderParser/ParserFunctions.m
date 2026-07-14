/* ParserFunctions.m
 *
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	Jan 2005
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
#include "ParserFunctions.h"

BOOL lookAhead(NSString *stringToScan, NSString *stringToFind)
{
  NSRange range;
  return (NSEqualRanges((range = [stringToScan rangeOfString: stringToFind]),
			NSMakeRange(NSNotFound,0)) == NO);
}

BOOL lookAheadForToken(NSString *stringToScan, NSString *stringToFind)
{
  NSScanner *scanner = [NSScanner scannerWithString: stringToScan];
  NSString *resultString = @"";
  
  [scanner setCharactersToBeSkipped: nil];
  [scanner scanString: stringToFind intoString: &resultString];
  if([resultString isEqualToString: stringToFind])
    {
      NSString *postTokenString = @"";
      NSCharacterSet *wsnl = [NSCharacterSet whitespaceAndNewlineCharacterSet];

      [scanner scanCharactersFromSet: wsnl intoString: &postTokenString];
      if([postTokenString length] == 0)
	{
	  return NO;
	}
      
      return YES;
    }

  return NO;
}

