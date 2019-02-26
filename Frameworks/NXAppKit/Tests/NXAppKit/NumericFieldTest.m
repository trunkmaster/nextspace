/*
  Class:               NumericFieldTest
  Inherits from:       NSObject
  Class descritopn:    NXNumericField demo for testing purposes.

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

#import "NumericFieldTest.h"

@implementation NumericFieldTest : NSObject

- (id)init
{
  self = [super init];

  if (![NSBundle loadNibNamed:@"NumericField" owner:self])
    {
      NSLog (@"NumericFieldTest: Could not load nib, aborting.");
      return nil;
    }

  return self;
}

- (void)awakeFromNib
{
  [window center];
  
  [[floatTextField formatter] setMinimumIntegerDigits:1];
  [[floatTextField formatter] setMinimumFractionDigits:2];
  [floatTextField setStringValue:@"0.0"];
  [floatTextField setMinimumValue:-100.0];

  NSString *textPath = [[NSBundle mainBundle] pathForResource:@"NumericField"
                                             ofType: @"rtf"];
  NSData   *text = [NSData dataWithContentsOfFile:textPath];
  [testDescription replaceCharactersInRange:NSMakeRange(0, 0)
                              withRTF:text];
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
