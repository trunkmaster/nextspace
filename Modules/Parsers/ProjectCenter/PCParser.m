/*
**  CodeParser.m
**
**  Copyright (c) 2003-2016
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**          Riccardo Mottola <rm@gnu.org>
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

#import <Protocols/CodeParser.h>

#import "PCParser.h"
#import "ObjCClassHandler.h"
#import "ObjCMethodHandler.h"

typedef enum _CodeType {
  StringCodeType,          /* 41-5A, 61-7A, 5F */
  NumberCodeType,          /* 30-39 */
  SpaceAndNewLineCodeType, /* 20, 0a, 0d */
  SymbolCodeType,          /* others */
  InvisibleCodeType        /* before (contain) 1F, except 0a, 0d */
} CodeType;

@implementation PCParser

// ===========================================================================
// ==== Initialisation
// ===========================================================================

- (id)init
{
  self = [super init];
  _handler = nil;
  _uchar = NULL;
  _length = 0;
  return self;
}

- (void)dealloc
{
  NSLog(@"PCParser: dealloc");
  free(_uchar);
  RELEASE(_string);

  [super dealloc];
}

- (id)setString:(NSString *)text
{
  if (_uchar != NULL)
    {
      free(_uchar);
    }

  ASSIGN(_string, text);

  _length = [_string length];
  _uchar = malloc(sizeof(unichar)*_length);
  [_string getCharacters:_uchar];

  return self;
}

- (NSArray *)classNames
{
  _handler = [[ObjCClassHandler alloc] init];
  [self parse];
  AUTORELEASE(_handler);
  
  return [(ObjCClassHandler *)_handler classes];
}

- (NSArray *)methodNames
{
  _handler = [[ObjCMethodHandler alloc] init];
  [self parse];
  AUTORELEASE(_handler);
  
  return [(ObjCMethodHandler *)_handler methods];
}

// ===========================================================================
// ==== Parsing
// ===========================================================================

/* Private function */
CodeType codeType(unichar *ch)
{
  if ( ((*ch > 0x40) && (*ch < 0x5B)) ||
       ((*ch > 0x60) && (*ch < 0x7B)) ||
       (*ch == 0x5F) )
    {
      return StringCodeType;
    }
  else if ((*ch == 0x20) || (*ch == 0x0a) || (*ch == 0x0d))
    {
      return SpaceAndNewLineCodeType;
    }
  else if ((*ch > 0x2F) && (*ch < 0x3A))
    {
      return NumberCodeType;
    }
  else if (*ch < 0x20)
    {
      return InvisibleCodeType;
    }
  else if ((*ch > 0x20) && (*ch < 0x7F))
    {
      return SymbolCodeType;
    }
  else 
    {
      return StringCodeType;
    } 
}

- (void)parse
{
  NSUInteger i, start, end;
  CodeType startType;
  NSString *out;
  SEL selString = @selector(string:);
  SEL selNumber = @selector(number:);
  SEL selSpaceAndNewLine = @selector(spaceAndNewLine:);
  SEL selInvisible = @selector(invisible:);
  SEL selSymbol = @selector(symbol:);
  void (*impString)(id, SEL, id);
  void (*impNumber)(id, SEL, id);
  void (*impSpaceAndNewLine)(id, SEL, unichar); 
  void (*impInvisible)(id, SEL, unichar); 
  void (*impSymbol)(id, SEL, unichar); 


  impString = (void (*)(id, SEL, id))
              [[_handler class] instanceMethodForSelector:selString]; 
  impNumber = (void (*)(id, SEL, id))
              [[_handler class] instanceMethodForSelector:selNumber];
  impSpaceAndNewLine = (void (*)(id, SEL, unichar))
              [[_handler class] instanceMethodForSelector:selSpaceAndNewLine];
  impInvisible = (void (*)(id, SEL, unichar))
              [[_handler class] instanceMethodForSelector:selInvisible];
  impSymbol = (void (*)(id, SEL, unichar))
              [[_handler class] instanceMethodForSelector:selSymbol];

  start = end = 0;
  startType = codeType(_uchar+start);

  for (i = 1; i <= _length; i++)
    {
      end = i;
      
      /* check for end, but check for end char only if not at end */
      if ((end == _length) || (startType != codeType(_uchar+end)) )
        {
          /* Check period in number */
          if ((startType == NumberCodeType) && (_uchar[end] == 0x2E))
            continue;

          if (startType == StringCodeType)
            {
              out = [_string substringWithRange:NSMakeRange(start, end-start)];
              (*impString)(_handler, selString, out);
            }
          else if (startType == NumberCodeType)
            {
              out = [_string substringWithRange: NSMakeRange(start, end-start)];
              (*impNumber)(_handler, selNumber, out);
            }
          else if (startType == SpaceAndNewLineCodeType)
            {
              NSUInteger j, jlen = end-start/*[out length]*/;
              for (j = 0; j < jlen; j++)
                {
		  (*impSpaceAndNewLine)(_handler, 
					selSpaceAndNewLine, _uchar[start+j]);
                }
            }
          else if (startType == SymbolCodeType)
            {
              NSUInteger j, jlen = end-start/*[out length]*/;
              for (j = 0; j < jlen; j++)
                {
                  (*impSymbol)(_handler, selSymbol, _uchar[start+j]);
                }
            }
          else if (startType == InvisibleCodeType)
            {
              NSUInteger j, jlen = end-start/*[out length]*/;
              for (j = 0; j < jlen; j++)
                {
                  (*impInvisible)(_handler, selInvisible, _uchar[start+j]);
                }
            }
          /* if we are at the end, we can getting the last stat char anyway
             and in any case it would not be valid */
          if (end != _length)
            {
              start = i;
              startType = codeType(_uchar+start);
            }
        }
    }
  /* send an extra new line if the file did not terminate with such.
     Forces the parser to close pending actions */
  if (codeType(_uchar+(_length-1)) != SpaceAndNewLineCodeType)
    (*impSpaceAndNewLine)(_handler, selSpaceAndNewLine, 0X0A);
}

@end
