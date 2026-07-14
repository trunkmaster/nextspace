/* OCHeaderParser.m
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

#include <GormObjCHeaderParser/OCMethod.h>
#include <GormObjCHeaderParser/NSScanner+OCHeaderParser.h>

@implementation OCMethod

- (id) initWithString: (NSString *)string
{
  if((self = [super init]) != nil)
    {
      ASSIGN(methodString, string);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(methodString);
  RELEASE(name);
  [super dealloc];
}

- (NSString *) name
{
  return name;
}

- (void) setName: (NSString *)aName
{
  ASSIGN(name,aName);
}

- (BOOL) isAction
{
  return isAction;
}

- (void) setIsAction: (BOOL)flag
{
  isAction = flag;
}

- (BOOL) isClassMethod
{
  return isClassMethod;
}

- (void) setIsClassMethod: (BOOL) flag
{
  isClassMethod = flag;
}

- (void) _strip
{
  NSScanner *stripScanner = [NSScanner scannerWithString: methodString];
  NSString *resultString = @""; // [NSString stringWithString: @""];
  NSCharacterSet *wsnl = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  while(![stripScanner isAtEnd])
    {
      NSString *string = nil;
      [stripScanner scanUpToCharactersFromSet: wsnl intoString: &string];
      resultString = [resultString stringByAppendingString: string];
      if(![stripScanner isAtEnd])
	{
	  resultString = [resultString stringByAppendingString: @" "];
	}
    }

  ASSIGN(methodString, resultString);
}

/**
 * Parse the method.
 */ 
- (void) parse
{
  NSRange notFound = NSMakeRange(NSNotFound,0);
  NSCharacterSet *wsnl = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSScanner *scanner = nil;
  NSString *tempSelector = nil;
  NSString *selectorPart = nil;
  NSString *returnPart = nil;
  NSString *argPart = nil;
  NSRange range;

  [self _strip];
  scanner = [NSScanner scannerWithString: methodString]; // stringByTrimmingCharactersInSet: wsnl]];
  isClassMethod = ([methodString compare: @"+" options: NSLiteralSearch range: NSMakeRange(0,1)] == NSOrderedSame);
  if(isClassMethod)
    {
      [scanner scanString: @"+" intoString: NULL];
      [scanner scanCharactersFromSet: wsnl intoString: NULL];
    }
  else
    {
      [scanner scanString: @"-" intoString: NULL];
      [scanner scanCharactersFromSet: wsnl intoString: NULL];
    }
  
  if(NSEqualRanges((range = [methodString rangeOfString: @":"]),notFound) == NO &&
     isClassMethod == NO)
    {
      [scanner scanUpToAndIncludingString: @":" intoString: &tempSelector];
      argPart = [methodString substringFromIndex: (range.location + 1)]; // the rest of the line...
      if(NSEqualRanges([tempSelector rangeOfString: @"("],notFound) == NO)
	{
	  NSScanner *selScanner = [NSScanner scannerWithString: tempSelector];
	  
	  [selScanner scanUpToAndIncludingString: @"(" intoString: NULL];
	  [selScanner scanUpToString: @")" intoString: &returnPart];
	  [selScanner scanString: @")" intoString: NULL];

	  [selScanner scanUpToAndIncludingString: @":" intoString: &selectorPart];
	  if([returnPart isEqual: @"IBAction"] || 
	     [returnPart isEqual: @"id"] || 
	     [returnPart isEqual: @"void"])
	    {
	      BOOL noMoreArgs = NSEqualRanges([argPart rangeOfString: @":"],notFound);
	      if(NSEqualRanges([argPart rangeOfString: @"("],notFound) == NO && noMoreArgs)
		{
		  NSString *argType = nil;
		  NSScanner *argScanner = [NSScanner scannerWithString: argPart];

		  [argScanner scanUpToAndIncludingString: @"(" intoString: NULL];
		  [argScanner scanUpToString: @")" intoString: &argType];
		  [argScanner scanString: @")" intoString: NULL];

		  if([argType isEqual: @"id"])
		    {
		      isAction = YES;
		    }
		}
	      else if(noMoreArgs)
		{
		  isAction = YES;
		}
	      else
		{
		  selectorPart = [selectorPart stringByAppendingString: argPart];
		}
	    }
	  
	  ASSIGN(name, [selectorPart stringByTrimmingCharactersInSet: wsnl]);
	}
      else // No return type specified.  The default is id, so we must treat it as a potential action...
	{
	  BOOL noMoreArgs = NSEqualRanges([argPart rangeOfString: @":"],notFound);
	  NSScanner *selScanner = [NSScanner scannerWithString: tempSelector];

	  [selScanner scanUpToAndIncludingString: @":" intoString: &selectorPart];
	  if(NSEqualRanges([argPart rangeOfString: @"("],notFound) == NO && noMoreArgs)
	    {
	      NSString *argType = nil;
	      NSScanner *argScanner = [NSScanner scannerWithString: argPart];

	      [argScanner scanUpToAndIncludingString: @"(" intoString: NULL];
	      [argScanner scanUpToString: @")" intoString: &argType];
	      [argScanner scanString: @")" intoString: NULL];
	      
	      if([argType isEqual: @"id"])
		{
		  isAction = YES;
		}
	    }
	  else if(noMoreArgs)
	    {
	      isAction = YES;
	    }
	  else
	    {
	      selectorPart = [selectorPart stringByAppendingString: argPart];
	    }

	  ASSIGN(name, [selectorPart stringByTrimmingCharactersInSet: wsnl]);
	}
    }
  else
    {
      [scanner scanUpToCharactersFromSet: wsnl intoString: &tempSelector];
      if(NSEqualRanges([tempSelector rangeOfString: @"("],notFound) == NO)
	{
	  NSScanner *selScanner = [NSScanner scannerWithString: tempSelector];
	  [selScanner scanUpToAndIncludingString: @")" intoString: NULL];
	  [selScanner scanUpToCharactersFromSet: wsnl intoString: &selectorPart];
	  ASSIGN(name, [selectorPart stringByTrimmingCharactersInSet: wsnl]);
	}
    }
}
@end
