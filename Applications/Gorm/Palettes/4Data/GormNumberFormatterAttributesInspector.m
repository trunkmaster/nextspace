/* inspectors - Various inspectors for data elements

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001   
   Author:  Gregory Casamento <greg_casamento@yahoo.com>
   Date: Nov 2003,2004,2005
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormNumberFormatterAttributesInspector.h"

/* this macro makes sure that the string contains a value, even if @"" */
#define VSTR(str) ({id _str = (id)str; (_str) ? (id)_str : (id)(@"");})

extern NSArray *predefinedNumberFormats;

@implementation GormNumberFormatterAttributesInspector

- (id) init
{
  if ([super init] != nil)
    {
      if ([NSBundle loadNibNamed: @"GormNSNumberFormatterInspector"
		    owner: self] == NO)
	{
	  NSLog(@"Could not gorm GormNumberFormatterInspector");
	  return nil;
	}
      else
	{
	  NSNumberFormatter *fmtr = [[NSNumberFormatter alloc] init];
	  
	  [fmtr setFormat: [NSNumberFormatter defaultFormat]];	  
	  [[positiveField cell] setFormatter: fmtr];
	  [[zeroField cell] setFormatter: fmtr];
	  [[negativeField cell] setFormatter: fmtr];
	}
    }  
  return self;
}

- (void) updateAppearanceFieldsWithFormat: (NSString *)format;
{
  [[[positiveField cell] formatter] setFormat: format];
  [[positiveField cell] setObjectValue:
			  [NSDecimalNumber decimalNumberWithString: @"123456.789"]];

  [[[zeroField cell] formatter] setFormat: format];
  [[zeroField cell] setObjectValue:
		      [NSDecimalNumber decimalNumberWithString: @"0.000"]];

  [[[negativeField cell] formatter] setFormat: format];
  [[negativeField cell] setObjectValue:
			  [NSDecimalNumber decimalNumberWithString: @"-123456.789"]];
}

- (void) ok: (id)sender
{
  NSString *positiveFmt, *negativeFmt, *zeroFmt, *fullFmt;
  NSString *minValue, *maxValue;
  NSCell   *cell = [object cell];
  NSNumberFormatter *fmtr = [cell formatter];

  // Mark as changed...
  [[(id<IB>)[NSApp delegate] activeDocument] touch];

  if (sender == detachButton)
    { 
      [cell setFormatter: nil];
      [[(id<IB>)[NSApp delegate] activeDocument] setSelectionFromEditor: nil];
    }
  else
    {
      if (sender == formatTable)
        {
          int row;

          if ((row = [sender selectedRow]) != -1)
            {
              positiveFmt = [NSNumberFormatter positiveFormatAtIndex:row];
              zeroFmt     = [NSNumberFormatter zeroFormatAtIndex:row];
              negativeFmt = [NSNumberFormatter negativeFormatAtIndex:row];
              fullFmt     = [NSNumberFormatter formatAtIndex:row];

	      // Update Appearance samples
	      [self updateAppearanceFieldsWithFormat: fullFmt];

	      // Update editable format fields
	      [[formatForm cellAtIndex:0] setStringValue: VSTR(positiveFmt)];
	      [[formatForm cellAtIndex:1] setStringValue: VSTR(zeroFmt)];
	      [[formatForm cellAtIndex:2] setStringValue: VSTR(negativeFmt)];

	      [fmtr setFormat:fullFmt];
            }
         }
      else if (sender == formatForm)
        {
          NSUInteger idx;
          
          positiveFmt = [[sender cellAtIndex: 0] stringValue];
          zeroFmt     = [[sender cellAtIndex: 1] stringValue];
          negativeFmt = [[sender cellAtIndex: 2] stringValue];
          minValue    = [[sender cellAtIndex: 3] stringValue];
          maxValue    = [[sender cellAtIndex: 4] stringValue];
          NSDebugLog(@"min,max: %@, %@", minValue, maxValue);
          
          fullFmt = [NSString stringWithFormat:@"%@;%@;%@",
                              positiveFmt, zeroFmt, negativeFmt];

          // If the 3 formats correspond to a predefined set  then highlight it in
          // number Format table view above
          if ( (idx = [NSNumberFormatter indexOfFormat: fullFmt]) == NSNotFound)
            {
              [formatTable deselectAll:self];
            }
          else
            {
              [formatTable selectRow:idx byExtendingSelection:NO];
              NSDebugLog(@"format found at index: %d", (int)idx);
            }

          // Update Appearance samples
          [self updateAppearanceFieldsWithFormat: fullFmt];

          [fmtr setFormat: fullFmt];

          if (minValue != nil)
	    {
	      [fmtr setMinimum: 
		      [NSDecimalNumber decimalNumberWithString: 
					 minValue]];
	    }

          if (maxValue != nil)
	    {
	      [fmtr setMaximum: 
		      [NSDecimalNumber decimalNumberWithString: 
					 maxValue]]; 
	    }
        }
      else if (sender == localizeSwitch)
        {
          [fmtr setLocalizesFormat:([sender state] == NSOnState)];
        }
      else if (sender == negativeRedSwitch)
        {
          NSMutableDictionary *newAttrs = [NSMutableDictionary dictionary];

          [newAttrs setObject:[NSColor redColor] forKey:@"NSColor"];
          [fmtr setTextAttributesForNegativeValues:newAttrs];
        }
      else if (sender == addThousandSeparatorSwitch)
        {
          [fmtr setHasThousandSeparators:([sender state] == NSOnState)];
        }
      else if (sender == commaPointSwitch)
        {
         [fmtr setDecimalSeparator:
		 ([sender state] == NSOnState) ? @"," : @"."];
         }
    }  
}

- (void) revert: (id)sender
{
  NSUInteger idx;
  NSNumberFormatter *fmtr = [[object cell] formatter];

  // Format form
  NSDebugLog(@"format from object: %@", [fmtr format]);
  [[formatForm cellAtIndex:0] setStringValue: [fmtr positiveFormat]];
  [[formatForm cellAtIndex:1] setStringValue: [fmtr zeroFormat]];
  [[formatForm cellAtIndex:2] setStringValue: [fmtr negativeFormat]];
  [[formatForm cellAtIndex:3] setObjectValue: [fmtr minimum]];
  [[formatForm cellAtIndex:4] setObjectValue: [fmtr maximum]];

  // If the string typed is a predefined one then highligh it in
  // Number Format table view above  
  if ( (idx = [NSNumberFormatter indexOfFormat: [fmtr format]]) == NSNotFound)
    {
      [formatTable deselectAll:self];
    }
  else
    {
      [formatTable selectRow:idx byExtendingSelection:NO];
    }

  // Option switches
  [localizeSwitch setState: 
		    ([fmtr localizesFormat] == YES) ? NSOnState : NSOffState];

  [addThousandSeparatorSwitch setState: 
				([fmtr hasThousandSeparators] == YES) ? 
			      NSOnState : NSOffState];

  if ([[fmtr decimalSeparator] isEqualToString: @","] )
    [commaPointSwitch setState: NSOnState];
  else 
    [commaPointSwitch setState: NSOffState];

  if ( [[[fmtr textAttributesForNegativeValues] objectForKey: @"NSColor"] 
	 isEqual: [NSColor redColor] ] )
      [negativeRedSwitch setState: NSOnState];
  else
      [negativeRedSwitch setState: NSOffState];
  
}

/* Positive/Negative Format table data source */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [NSNumberFormatter formatCount];
}

- (id)tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
  row:(NSInteger)rowIndex
{  
  if ( [[aTableColumn identifier] isEqualToString: @"positive"] )
    {
      return [NSNumberFormatter positiveValueAtIndex:rowIndex];
    }
  else if ( [[aTableColumn identifier] isEqualToString: @"negative"] )
    {
      return [NSNumberFormatter negativeValueAtIndex:rowIndex];
    }
  else 
    {
      // Huuh?? Only 2 columns
      NSLog(@"Number table view doesn't known column identifier: %@", 
	    [aTableColumn identifier]);
    }
  
  return nil;
  
}

/* Positive/Negative Format table Delegate */

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  // When a row is selected update the rest of the inspector accordingly
  [self ok: formatTable];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell
   forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  NSNumberFormatter *fmtr;
  
  // Adjust the cell formatter before it is displayed
  fmtr = [[NSNumberFormatter alloc] init];
  [fmtr setFormat: [NSNumberFormatter formatAtIndex:rowIndex]];
  [aCell setFormatter: fmtr];
}

@end
