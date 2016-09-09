/*
  Class:               NXNumericTextField
  Inherits from:       NSTextField
  Class descritopn:    NSTextField wich accepts only digits.
                       By default entered value interpreted as integer.
                       Otherwise it must be set as float via setIsFloat:YES method.

  Copyright (C) 2016 Sergii Stoian

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "NXNumericTextField.h"

@implementation NXNumericTextField (Private)

- (void)_setup
{
  [self setAlignment:NSRightTextAlignment];
  isFloat = NO;
}

- (BOOL)_isValidString:(NSString *)text
{
  NSCharacterSet *digitsCharset = [NSCharacterSet decimalDigitCharacterSet];
  BOOL           isDigit = NO;
  
  // Not a digit
  for (int i = 0; i < [text length]; ++i)
    {
      isDigit = [digitsCharset characterIsMember:[text characterAtIndex:i]];
      if (isFloat)
        {
          if (([text characterAtIndex:i] != '.') && !isDigit)
            {
              return NO;
            }
        }
      else if (!isDigit)
        {
          return NO;
        }
    }

  return YES;
}

@end

@implementation NXNumericTextField

//----------------------------------------------------------------------------
#pragma mark | Overridings
//----------------------------------------------------------------------------

- (id)init
{
  self = [super init];
  [self _setup];
  return self;
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self _setup];
  return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
  self = [super initWithCoder:aDecoder];
  [self _setup];
  return self;
}

- (BOOL)textShouldEndEditing:(NSText*)textObject
{
  NSString *string;

  if ([super textShouldEndEditing:textObject] == NO)
    {
      return NO;
    }

  string = [textObject string];
  if (isFloat)
    {
      [self setFloatValue:[string floatValue]];
    }
  else
    {
      [self setIntValue:[string intValue]];
    }

  return YES;
}

//----------------------------------------------------------------------------
#pragma mark | NSTextView delegate
//----------------------------------------------------------------------------

/* Field editor (NSTextView) designates us as delegate. So we use delegate 
   methods to validate entered or pasted values. */
- (BOOL)	textView:(NSTextView *)textView
 shouldChangeTextInRange:(NSRange)affectedCharRange
       replacementString:(NSString *)replacementString
{
  BOOL    result = NO;
  NSRange range;
  
  if (!replacementString || [replacementString length] == 0)
    {
      result = YES;
    }
  else if ([self _isValidString:replacementString])
    {
      if (isFloat && [replacementString rangeOfString:@"."].location != NSNotFound)
        {
          range = [[self stringValue] rangeOfString:@"."];
          if (range.location == NSNotFound
              || NSIntersectionRange(range, affectedCharRange).length > 0)
            {// Field already contains '.' but will be replaced by string with '.' in it
              result = YES;
            }
        }
      else
        {
          result = YES;
        }
    }

  return result;
}


//----------------------------------------------------------------------------
#pragma mark | NSTextField additions
//----------------------------------------------------------------------------

- (void)setIsFloat:(BOOL)yn
{
  isFloat = yn;
}

@end
