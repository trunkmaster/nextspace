/* OCClass.m
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

#include "GormObjCHeaderParser/OCClass.h"
#include "GormObjCHeaderParser/OCMethod.h"
#include "GormObjCHeaderParser/OCProperty.h"
#include "GormObjCHeaderParser/OCIVar.h"
#include "GormObjCHeaderParser/OCIVarDecl.h"
#include "GormObjCHeaderParser/NSScanner+OCHeaderParser.h"
#include "GormObjCHeaderParser/ParserFunctions.h"

@implementation OCClass
- (id) initWithString: (NSString *)string
{
  if ((self = [super init]) != nil)
    {
      _methods = [[NSMutableArray alloc] init];
      _ivars = [[NSMutableArray alloc] init];
      _properties = [[NSMutableArray alloc] init];
      _protocols = [[NSMutableArray alloc] init];
      _superClassName = nil;
      ASSIGN(_classString, string);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_methods);
  RELEASE(_ivars);
  RELEASE(_properties);
  RELEASE(_protocols);  
  RELEASE(_classString);
  RELEASE(_className);
  RELEASE(_superClassName);
  [super dealloc];
}

- (NSArray *) methods
{
  return _methods;
}

- (void) addMethod: (NSString *)name isAction: (BOOL) flag
{
  OCMethod *method = AUTORELEASE([[OCMethod alloc] init]);
  [method setName: name];
  [method setIsAction: flag];
  [_methods addObject: method];
}

- (NSArray *) ivars
{
  return _ivars;
}

- (void) addIVar: (NSString *)name isOutlet: (BOOL) flag
{
  OCIVar *ivar = AUTORELEASE([[OCIVar alloc] init]);
  [ivar setName: name];
  [ivar setIsOutlet: flag];
  [_ivars addObject: ivar];
}

- (NSString *) className
{
  return _className;
}

- (void) setClassName: (NSString *)name
{
  ASSIGN(_className, name);
}

- (NSString *) superClassName
{
  return _superClassName;
}

- (void) setSuperClassName: (NSString *)name
{
  ASSIGN(_superClassName,name);
}

- (BOOL) isCategory
{
  return _isCategory;
}

- (void) setIsCategory: (BOOL)flag
{
  _isCategory = flag;
}

- (NSArray *) properties
{
  return _properties;
}

- (void) _strip
{
  NSScanner *stripScanner = [NSScanner scannerWithString: _classString];
  NSString *resultString = @"";
  NSCharacterSet *wsnl = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  while(![stripScanner isAtEnd])
    {
      NSString *string = nil;
      [stripScanner scanUpToCharactersFromSet: wsnl intoString: &string];
      resultString = [resultString stringByAppendingString: string];
      if (![stripScanner isAtEnd])
	{
	  resultString = [resultString stringByAppendingString: @" "];
	}
    }
  
  ASSIGN(_classString, resultString);
}

- (void) parse
{
  NSScanner *scanner = nil; 
  NSScanner *iscan = nil;
  NSString *interfaceLine = nil;
  NSString *methodsString = nil;
  NSString *ivarsString = nil;
  NSCharacterSet *wsnl = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSCharacterSet *pmcs = [NSCharacterSet characterSetWithCharactersInString: @"+-"];

  // get the interface line... look ahead...  
  [self _strip];
  NSDebugLog(@"_classString = %@", _classString);
  scanner = [NSScanner scannerWithString: _classString];
  if (lookAhead(_classString, @"@implementation"))
    {
      NSString *cn = nil;
      
      [scanner scanUpToAndIncludingString: @"@implementation" intoString: NULL];
      [scanner scanUpToCharactersFromSet: wsnl intoString: &cn];
      _className = [cn stringByTrimmingCharactersInSet: wsnl];
      RETAIN(_className);
      NSDebugLog(@"_className = %@", _className);
    }
  else
    {
      if (lookAhead(_classString, @"{")) 
	{
	  [scanner scanUpToString: @"@interface" intoString: NULL]; 
	  [scanner scanUpToString: @"{" intoString: &interfaceLine];
	  iscan = [NSScanner scannerWithString: interfaceLine]; // reset scanner... 
	}
      else // if there is no "{", then there are no ivars...
	{
	  [scanner scanUpToString: @"@interface" intoString: NULL]; 
	  [scanner scanUpToCharactersFromSet: pmcs intoString: &interfaceLine];
	  iscan = [NSScanner scannerWithString: interfaceLine]; // reset scanner... 
	}
      
      // look ahead...  
      if (lookAhead(interfaceLine, @":"))
	{
	  NSString *cn = nil, *scn = nil;
	  
	  [iscan scanUpToAndIncludingString: @"@interface" intoString: NULL];
	  [iscan scanUpToString: @":" intoString: &cn];
	  _className = [cn stringByTrimmingCharactersInSet: wsnl];
	  RETAIN(_className);
	  [iscan scanString: @":" intoString: NULL];
	  [iscan scanUpToCharactersFromSet: wsnl intoString: &scn];
	  [self setSuperClassName: [scn stringByTrimmingCharactersInSet: wsnl]];
	}
      else // category...
	{
	  NSString *cn = nil;
	  
	  [iscan scanUpToAndIncludingString: @"@interface" intoString: NULL];
	  [iscan scanUpToCharactersFromSet: wsnl intoString: &cn];
	  _className = [cn stringByTrimmingCharactersInSet: wsnl];
	  RETAIN(_className);
	  
	  // check to see if it's a category on an existing interface...
	  if (lookAhead(interfaceLine,@"("))
	    {
	      _isCategory = YES;
	    }
	}
      
      if (_isCategory == NO)
	{          
	  NSScanner *ivarScan = nil;
	  
	  // put the ivars into a a string...
	  [scanner scanUpToAndIncludingString: @"{" intoString: NULL];
	  [scanner scanUpToString: @"}" intoString: &ivarsString];
	  [scanner scanString: @"}" intoString: NULL];
	  
	  if (ivarsString != nil)
	    {
	      // scan each ivar...
	      ivarScan = [NSScanner scannerWithString: ivarsString];
	      while(![ivarScan isAtEnd])
		{
		  NSString *ivarLine = nil;
		  OCIVarDecl *ivarDecl = nil;
		  
		  [ivarScan scanUpToString: @";" intoString: &ivarLine];
		  [ivarScan scanString: @";" intoString: NULL];
		  ivarDecl = AUTORELEASE([[OCIVarDecl alloc] initWithString: ivarLine]); 
		  [ivarDecl parse];
		  [_ivars addObjectsFromArray: [ivarDecl ivars]];
		}
	    }
	}
      else
	{
	  NSString *cn = nil;
	  NSScanner *cs = [NSScanner scannerWithString: _classString];

	  [cs scanUpToAndIncludingString: @"@interface" intoString: NULL];
	  [cs scanUpToCharactersFromSet: wsnl intoString: &cn];
	  _className = [cn stringByTrimmingCharactersInSet: wsnl];
	  RETAIN(_className);
	  NSDebugLog(@"_className = %@", _className);
	}
      
      // put the methods into a string...
      if (ivarsString != nil)
	{
	  [scanner scanUpToString: @"@end" intoString: &methodsString];
	}
      else // 
	{
	  scanner = [NSScanner scannerWithString: _classString];
	  [scanner scanUpToAndIncludingString: interfaceLine intoString: NULL];
	  [scanner scanUpToString: @"@end" intoString: &methodsString];
	}
    }
  
  if (_classString != nil)
    {
      NSScanner *propertiesScan = [NSScanner scannerWithString: _classString];
      while ([propertiesScan isAtEnd] == NO)
	{
	  NSString *propertiesLine = nil;
	  OCProperty *property = nil;

	  [propertiesScan scanUpToString: @";" intoString: &propertiesLine];
	  [propertiesScan scanString: @";" intoString: NULL];
	  property = AUTORELEASE([[OCProperty alloc] initWithString: propertiesLine]);
	  [property parse];
	  [_properties addObject: property];
	}
    }
  
  // scan each method...
  if (methodsString != nil)
    {
      NSScanner *methodScan = [NSScanner scannerWithString: methodsString];
      while ([methodScan isAtEnd] == NO)
	{
	  NSString *methodLine = nil;
	  OCMethod *method = nil;
	  
	  [methodScan scanUpToString: @";" intoString: &methodLine];
	  [methodScan scanString: @";" intoString: NULL];
	  method = AUTORELEASE([[OCMethod alloc] initWithString: methodLine]);       
	  [method parse];
	  [_methods addObject: method];
	}      
    }
}
@end
