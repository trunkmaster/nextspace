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

/*
  Class:               NXTNumericField
  Inherits from:       NSTextField
  Class descritopn:    NSTextField wich accepts only digits.
                       By default entered value interpreted as integer.
                       Otherwise it must be set as float via 
                       setMinimum.../setMaximum... methods.
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NXTNumericField : NSTextField
{
  NSNumberFormatter *formatter;
  
  CGFloat  minimumValue;
  CGFloat  maximumValue;
}

- (void)setMinimumValue:(CGFloat)min;
- (void)setMaximumValue:(CGFloat)max;

@end
