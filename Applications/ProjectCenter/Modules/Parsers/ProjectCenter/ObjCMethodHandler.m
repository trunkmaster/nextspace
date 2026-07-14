/*
**  ObjCMethodHandler.m
**
**  Copyright (c) 2003-2013
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <AppKit/AppKit.h>

#import "ObjCMethodHandler.h"

@implementation ObjCMethodHandler

- (id)init
{
  self = [super init];
  position = 0;
  nameBeginPosition = 0;
  nameEndPosition = 0;
  bodyBeginPosition = 0;
  bodySymbolCount = -1;

  inSpace = NO;
  method = [[NSMutableString alloc] init];
  methods = [[NSMutableArray alloc] init];

  prev_step = step = MethodNone;
  _preSymbol = 0;

  return self;
}

- (void)dealloc
{
  NSLog(@"MethodHandler: dealloc");
  RELEASE(method);
  RELEASE(methods);
  [super dealloc];
}

- (NSArray *)methods
{
  return methods;
}

- (void)addMethodToArray
{
  if ([method length])
    {
      NSDictionary *dict;
      NSString     *dMethod;
      NSString     *dNRange;
      NSString     *dBRange;

      dMethod = [method copy];
      dNRange = NSStringFromRange(NSMakeRange(nameBeginPosition,
			  		      nameEndPosition-nameBeginPosition));
      dBRange = NSStringFromRange(NSMakeRange(bodyBeginPosition,
			  		      position-bodyBeginPosition));

      dict = [NSDictionary dictionaryWithObjectsAndKeys:
	dMethod, @"MethodName",
	dNRange, @"MethodNameRange",
	dBRange, @"MethodBodyRange",
	nil];

      [methods addObject:dict];
      RELEASE(dMethod);
    }
  [method setString:@""];
}

#define NotMethod {step = MethodNone; [method setString: @""];}

- (void)string:(NSString *)element
{
  NSUInteger len = [element length];

  [super string:element];

  /* Comments */
  if (_commentType != NoComment)
    {
    }
  else if (_stringBegin/* != NoString*/)
    {
    }
  else
    {
      inSpace = NO;

      if (step == MethodStart)
        {
          NotMethod;
        }
      else if (step == MethodName)
        {
          [method appendString:element];
        }
      else if (step == MethodParameterStart)
	{
	  step = MethodParameter;
	}
    }

  position += len;
  _preChar = 0;
}

- (void)number:(NSString *)element 
{
  [super number:element];

  /* Comments */
  if (_commentType != NoComment)
    {
    }
  else if (_stringBegin)
    {
    }
  else
    {
      inSpace = NO;

      if (step == MethodStart)
        {
          NotMethod;
        }
      else if (step == MethodSymbol)
        {
          NotMethod;
        }
      else if (step == MethodReturnValue)
        {
          NotMethod;
        }
      else if (step == MethodName)
        {
          [method appendString:element];
        }
    }

  position += [element length];
  _preChar = 0;
}

- (void)spaceAndNewLine:(unichar)element 
{
  BOOL newline = NO;

  [super spaceAndNewLine: element];

  if ((element == 0x0A) || (element == 0x0D))
    {
      newline = YES;
    }

  /* Comments */
  if (_commentType != NoComment)
    {
    }
  else if (_stringBegin)
    {
    }
  else
    {
      if (step != MethodNone)
        {
/*          if ((!newline) && (!inSpace))
            {
              [method appendString:[NSString stringWithFormat:@"%c",element]];
            }*/
          if (element == ' ' || newline)
            {
	      if (step == MethodParameter)
		{
		  step = MethodName;
		  prev_step = MethodNone;
		}
              inSpace = YES;
            }
        }

      // Method name should start from beginning of line 
      // (some spaces may prepend "+" or "-" symbol)
      if (newline && (step == MethodNone))
        {
          step = MethodStart;
        }
    }

  position++;
  _preChar = element;
}

- (void)symbol:(unichar)element 
{
  [super symbol:element];

  /* Comments */
  if (_commentType != NoComment)
    {
    }
  else if (_stringBegin)
    {
    }
  else
    {
      inSpace = NO;
      _preSymbol = element;

      if (step == MethodStart)
        {
	  if ((element == '+') || (element == '-'))
	    {
	      step = MethodName;
	      [method appendString:[NSString stringWithFormat: @"%c", element]];
	      nameBeginPosition = position;
	    }
        }
      else if ((step == MethodName) || (step == MethodParameterStart))
        {
          if (element == '(')
            {
	      if (step == MethodParameterStart)
		{
		 prev_step = step; 
		}
	      step = MethodReturnValue;
            }
	  else if (element == ':')
	    {
	      step = MethodName;
    	      [method appendString:@":"];
	    }
        }
      else if (step == MethodReturnValue && element == ')')
        {
	  if (prev_step == MethodParameterStart)
	    {
	      step = prev_step;
	    }
	  else
	    {
	      step = MethodName;
	    }
//          [method appendString:[NSString stringWithFormat: @"%c", element]];
        }
      else if ((step == MethodName) && (element != '{') && (element != ';')) 
        {
	  [method appendString:[NSString stringWithFormat: @"%c", element]];
        }

      if (element == '{')
	{
	  if ((step == MethodName) && (bodySymbolCount == -1)) 
	    { // Method body starts
	      step = MethodBody;
	      nameEndPosition = position - 1;
	      bodyBeginPosition = position;
	      bodySymbolCount += 2; // -1 + 2 = 1
//	      NSLog(@"methodBodyStart: %i", bodySymbolCount);
	    }
	  else if (step == MethodBody)
	    {
	      bodySymbolCount++;
//	      NSLog(@"symbolCount++: %i", bodySymbolCount);
	    }
	}

      if ((element == '}') && ((step == MethodBody) || (step == MethodBody)))
	{
	  bodySymbolCount--;
//	  NSLog(@"symbolCount--: %i", bodySymbolCount);
	}

      // Method definition (header files)
      if ((step == MethodName) && (element == ';'))
	  {
	    nameEndPosition = position;
	    bodyBeginPosition = position - 1;
	    [self addMethodToArray];
	    step = MethodNone;
	  }

      // Method implemenation (class files)
      if ((step == MethodBody) && (bodySymbolCount == 0))
        {
	  [self addMethodToArray];
	  step = MethodNone;
	  bodySymbolCount = -1;
        }
    }

  position++;
  _preChar = element;
}

- (void)invisible:(unichar)element
{
  [super invisible: element];
  position ++;
  _preChar = element;
}

@end

