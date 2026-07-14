/*
**  ObjCClassHandler.m
**
**  Copyright (c) 2003-2016 The Free Software Foundation
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

#import "ObjCClassHandler.h"

@implementation ObjCClassHandler

- (id)init
{
  self = [super init];
  position = 0;
  nameBeginPosition = 0;
  nameEndPosition = 0;
  bodyBeginPosition = 0;
  bodySymbolCount = -1;

  inSpace = NO;
  keyword = [[NSMutableString alloc] init];
  class = [[NSMutableString alloc] init];
  classes = [[NSMutableArray alloc] init];

  prev_step = ClassNone;
  step = ClassNone;
  _preSymbol = 0;

  return self;
}

- (void)dealloc
{
  RELEASE(keyword);
  RELEASE(class);
  RELEASE(classes);
  [super dealloc];
}

- (NSArray *)classes
{
  return classes;
}

- (void)addClassToArray
{
  NSLog(@"OCCH: class: %@", class);
  if ([class length])
    {
      NSDictionary *dict;
      NSString     *dClass;
      NSString     *dNRange;
      NSString     *dBRange;

      dClass = [class copy];
      dNRange = NSStringFromRange(NSMakeRange(nameBeginPosition,
			  		      nameEndPosition-nameBeginPosition));
      dBRange = NSStringFromRange(NSMakeRange(bodyBeginPosition,
			  		      position-bodyBeginPosition));

      dict = [NSDictionary dictionaryWithObjectsAndKeys:
	dClass, @"ClassName",
	dNRange, @"ClassNameRange",
	dBRange, @"ClassBodyRange",
	nil];

      [classes addObject:dict];
      RELEASE(dClass);
    }
  [class setString:@""];
}

#define NotClass {step = ClassNone; [class setString: @""];}

- (void)string:(NSString *)element
{
  NSUInteger len = [element length];

  [super string:element];

  /* Comments */
  if (_commentType != NoComment)
    {
    }
  else if (_stringBegin)
    {
    }
  else if (step != ClassNone)
    {
      inSpace = NO;

      if (step == ClassStart)
        {
          NotClass;
        }
      else if (step == ClassSymbol)
        {
    	  [keyword appendString:element];
        }
      else if ((step == ClassName) || (step == ClassCategory))
        {
      	  [class appendString:element];
	  if (prev_step == ClassNone)
	    {
	      prev_step = ClassName;
	    }
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

      if (step == ClassStart)
        {
          NotClass;
        }
/*      else if (step == ClassSymbol)
        {
          NotClass;
        }
      else if (step == ClassCategory)
        {
          NotClass;
        }*/
      else if (step == ClassName)
        {
          [class appendString:element];
        }
    }

  position += [element length];
  _preChar = 0;
}

- (void)spaceAndNewLine:(unichar)element 
{
  BOOL newline = NO;

  [super spaceAndNewLine:element];

  if ((element == 0x0A) || (element == 0x0D) || (element == 0x04))
    {
//      NSLog(@"Newline");
//      if(element == 0x04)
//	NSLog(@"and EOF");
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
      if (step != ClassNone)
        {
/*          if ((!newline) && (!inSpace))
            {
              [class appendString:[NSString stringWithFormat:@"%c",element]];
            }
	  else*/
	  if ((newline || element == ' ') && (step == ClassSymbol))
    	    {
	      if ([keyword isEqualToString:@"end"])
		{
		  [self addClassToArray];
		  step = ClassNone;
		}
	      else if ([keyword isEqualToString:@"interface"] || 
	     	       [keyword isEqualToString:@"implementation"])
		{
		  [class appendString:@"@"];
		  step = ClassName;
		  prev_step = ClassNone;
		  nameBeginPosition = position+1;
		}
	      [keyword setString:@""];
	      
      	      if (prev_step == ClassBody)
		{
		  step = ClassBody;
		  prev_step = ClassNone;
		}

	      inSpace = YES;
	    }
	  else if (newline && (step == ClassName))
	    {
//	      NSLog(@"Class body start: \"%@\"", class);
	      step = ClassBody;
	      nameEndPosition = position;
	      bodyBeginPosition = position+1;
	    }
	  else if ((element == ' ') && (step == ClassName) 
		   && (prev_step != ClassName))
	    {
	      nameBeginPosition++;
	    }
        }

      // Class name should start from beginning of line 
      // (some spaces may prepend "@" symbol)
      if (newline && (step == ClassNone))
        {
          step = ClassStart;
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

      if ((step == ClassStart) || (step == ClassBody))
        {
	  if (element == '@')
	    {
	      prev_step = step;
	      step = ClassSymbol;
	    }
        }
      else if (step == ClassName)
        {
          if (element == '(')
            {
	      step = ClassCategory;
	      [class appendString:[NSString stringWithFormat:@"%c",element]];
            }
	  else if (element == '<')
	    {
	      step = ClassProto;
	    }
	  else if (element == ':')
	    {
	      [class appendString:[NSString stringWithFormat:@"%c",element]];
	    }
        }
      else if (step == ClassCategory)
        {
          if (element == ')')
            {
              step = ClassName;
            }
          [class appendString:[NSString stringWithFormat:@"%c",element]];
        }
      else if (step == ClassProto)
	{
          if (element == '>')
            {
              step = ClassName;
            }
	}
    }

  position++;
  _preChar = element;
}

- (void)invisible:(unichar)element
{
  [super invisible:element];
  position++;
  _preChar = element;
}

@end

