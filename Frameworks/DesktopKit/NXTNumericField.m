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

#include <values.h>
#import "NXTNumericField.h"

@implementation NXTNumericField (Private)

- (void)_setup
{
  [self setAlignment:NSRightTextAlignment];
  minimumValue = MININT;
  maximumValue = MAXINT;

  formatter = [[NSNumberFormatter alloc] init];
  // [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
  // [formatter setLocalizesFormat:NO];
  // [formatter setHasThousandSeparators:NO];
  [formatter setMinimumIntegerDigits:1];
  [formatter setMinimumFractionDigits:0];
}

// Check for digits (0-9), minus (-) and period (.) signs.
- (BOOL)_isValidString:(NSString *)text
{
  NSCharacterSet *digitsCharset = [NSCharacterSet decimalDigitCharacterSet];
  
  for (int i = 0; i < [text length]; ++i) {
    if (([digitsCharset characterIsMember:[text characterAtIndex:i]] == NO)
        && ([text characterAtIndex:i] != '-')
        && ([text characterAtIndex:i] != '.')) {
      return NO;
    }
  }

  return YES;
}

@end

@implementation NXTNumericField

//----------------------------------------------------------------------------
#pragma mark | Overridings
//----------------------------------------------------------------------------

- (id)init
{
  self = [super init];
  [self _setup];
  return self;}

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

- (void)dealloc
{
  [formatter release];
  [super dealloc];
}

- (void)setFormatter:(NSFormatter*)newFormatter
{
  // It's not designed to use other formatter - do nothing here
}

- (id)formatter
{
  return formatter;
}

- (void)setStringValue:(NSString *)aString
{
  NSNumber *number = [formatter numberFromString:aString];
  
  [super setStringValue:[formatter stringFromNumber:number]];
}

- (void)setFloatValue:(float)aFloat
{
  NSNumber *number = [NSNumber numberWithFloat:aFloat];
  
  [super setStringValue:[formatter stringFromNumber:number]];
}

- (BOOL)textShouldEndEditing:(NSText*)textObject
{
  CGFloat  val = [[textObject string] floatValue];

  if (val < minimumValue) val = minimumValue;
  if (val > maximumValue) val = maximumValue;

  [super
    setStringValue:[formatter stringFromNumber:[NSNumber numberWithFloat:val]]];
  
  return YES;
}

- (void)keyUp:(NSEvent*)theEvent
{
  NSRange range;
  
  // 'Home' key places insertion point at the beginning and selects inegral
  // part of number.
  if ([[theEvent characters] characterAtIndex:0] == NSHomeFunctionKey) {
    range = [[self stringValue] rangeOfString:@"."];  
    if (range.location != NSNotFound) {
      // Select fraction part
      range.length = range.location;
      range.location = 0;
      [[[self window] fieldEditor:NO forObject:self]
        setSelectedRange:range];
    }
  }  
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
  BOOL    isDecimal = NO;
  BOOL    result = YES;
  NSRange range;

  if (!replacementString || [replacementString length] == 0) {
    // Prevent deletion of '.' symbol
    range = [[self stringValue] rangeOfString:@"."];
    if (NSIntersectionRange(range, affectedCharRange).length > 0) {
      return NO;
    }
    else {
      return YES;
    }
  }

  if ([formatter minimumFractionDigits] > 0 ||
      [formatter maximumFractionDigits] > 0) {
    isDecimal = YES;
  }
  
  if ([self _isValidString:replacementString] == YES) {
    for (int i = 0; i < [replacementString length]; ++i) {
      if ([replacementString characterAtIndex:i] == '-') {
        if (i != 0 || affectedCharRange.location != 0
            || [[self stringValue] rangeOfString:@"-"].location != NSNotFound) {
          result = NO;
          break;
        }
      }
      else if ([replacementString characterAtIndex:i] == '.') {
        if (!isDecimal) {
          result = NO;
          break;
        }
        else {
          range = [[self stringValue] rangeOfString:@"."];
          // Extra '.' want to be added
          if (range.location != NSNotFound
              && NSIntersectionRange(range, affectedCharRange).length == 0) {
            // Select fraction part
            range.location += 1;
            range.length = [[self stringValue] length] - range.location;
            [[[self window] fieldEditor:NO forObject:self]
              setSelectedRange:range];
            result = NO;
            break;
          }
        }
      }
    }
  }
  else { // Invalid text was entered
    result = NO;
  }
  
  return result;
}


//----------------------------------------------------------------------------
#pragma mark | NSTextField additions
//----------------------------------------------------------------------------

- (void)setMinimumValue:(CGFloat)min
{
  minimumValue = min;
}

- (void)setMaximumValue:(CGFloat)max
{
  maximumValue = max;
}

@end
