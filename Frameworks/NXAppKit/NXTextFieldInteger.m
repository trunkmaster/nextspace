/*
  Class:               NXTextFieldInteger
  Inherits from:       NSTextField
  Class descritopn:    NSTextField wich accepts only digits.

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

#import "NXTextFieldInteger.h"

@implementation NXTextFieldInteger

/* Field editor (NSTextView) designates us as delegate. So we use delegate 
   methods to validate entered or pasted values. */
- (BOOL)	textView:(NSTextView *)textView
 shouldChangeTextInRange:(NSRange)affectedCharRange
       replacementString:(NSString *)replacementString
{
  if (!replacementString || [replacementString length] == 0)
    return YES;
  else
    return [self validateString:replacementString];
}

- (BOOL)validateString:(NSString *)text
{
  NSCharacterSet *digitsCharset = [NSCharacterSet decimalDigitCharacterSet];
  
  NSLog(@"NXTextFieldDemo: validateString");
  
  // Not a digit
  for (int i = 0; i < [text length]; ++i)
    {
      if ([digitsCharset characterIsMember:[text characterAtIndex:i]] == NO)
        {
          NSBeep();
          return NO;
        }
    }

  return YES;
}

@end
