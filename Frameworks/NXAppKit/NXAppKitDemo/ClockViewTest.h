 /*
  Class:               ClockViewTest
  Inherits from:       NSObject
  Class descritopn:    NXClockView demo for testing purposes.

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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <NXAppKit/NXClockView.h>
#import <NXAppKit/NXNumericField.h>

@interface ClockViewTest : NSObject
{
  id window;
  NXClockView *clockView;
  id yearField;
  id monthField;
  id dayField;
  
  id hourField;
  id minuteField;
  id secondField;
  
  id hour24Btn;
  id showYearBtn;
  id makeAliveBtn;

  id languageList;

  NSInteger year;
  NSUInteger month, day, hour, minute, second;
}

- (void)show;

- (void)setDate:(id)sender;

- (void)set24Hour:(id)sender;
- (void)setShowYear:(id)sender;
- (void)setAlive:(id)sender;

@end
