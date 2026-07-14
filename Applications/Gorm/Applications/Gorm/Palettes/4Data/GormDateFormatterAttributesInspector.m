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

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

#include "GormDateFormatterAttributesInspector.h"

/* this macro makes sure that the string contains a value, even if @"" */
#define VSTR(str) ({id _str = (id)str; (_str) ? (id)_str : (id)(@"");})

extern NSArray *predefinedDateFormats;

@implementation GormDateFormatterAttributesInspector
- (id) init
{
  if ([super init] != nil)
    {
      if ([NSBundle loadNibNamed: @"GormNSDateFormatterInspector" 
		    owner: self] == NO)
	{
	  NSLog(@"Could not gorm GormDateFormatterInspector");
	  return nil;
	}
    }
  return self;
}

- (void) ok: (id)sender
{
  BOOL allowslanguage = NO;
  NSString *dateFmt = nil;
  NSDateFormatter *fmtr;
  
  // Set the document as modifed...
  [[(id<IB>)[NSApp delegate] activeDocument] touch];
  
  if (sender == detachButton)
    {
      [[object cell] setFormatter: nil];
      [[(id<IB>)[NSApp delegate] activeDocument] setSelectionFromEditor: nil];
    }
  else
    {
      NSCell *cell = [object cell];

      if (sender == formatTable)
        {
          int row;
          
          if ((row = [sender selectedRow]) != -1)
            {
              dateFmt = [NSDateFormatter formatAtIndex: row];            
            }
          
          [formatField setStringValue: VSTR(dateFmt) ];
        }
      else if (sender == formatField)
        {
          NSInteger idx;
          
          dateFmt = [sender stringValue];

          // If the string typed is a predefined one then highligh it in
          // table dateFormat table view above
          if ( (idx = [NSDateFormatter indexOfFormat: dateFmt]) == NSNotFound)
            {
              [formatTable deselectAll:self];
            }
          else
            {
              [formatTable selectRow:idx byExtendingSelection:NO];
            }
          
        }
      else if (sender == languageSwitch)
        {
	  dateFmt = [formatField stringValue];
          allowslanguage = ([sender state] == NSOnState);
        }

      // Update the Formatter and refresh the Cell value
      fmtr = [[NSDateFormatter alloc] initWithDateFormat:dateFmt
                                      allowNaturalLanguage:allowslanguage];
      [cell setFormatter:fmtr];
      RELEASE(fmtr);
      
      [cell setObjectValue: [cell objectValue]];
      
    }

  [super ok: sender];
}

- (void) revert: (id)sender
{
  NSInteger idx;
  NSDateFormatter *fmtr = [[object cell] formatter];
  
  // If the string typed is a predefined one then highligh it in
  // table dateFormat table view above
  if ( (idx = [NSDateFormatter indexOfFormat: [fmtr dateFormat]]) == NSNotFound)
    {
      [formatTable deselectAll:self];
    }
  else
    {
      [formatTable selectRow:idx byExtendingSelection:NO];
    }

  [formatField setStringValue: VSTR([fmtr dateFormat]) ];
  [languageSwitch setState: [fmtr allowsNaturalLanguage]];
  
  [super revert: sender]; 
}

/* NSDateFormatter inspector: table view delegate and data source */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [NSDateFormatter formatCount];
}

- (id)tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
  row:(NSInteger)rowIndex
{
  NSString *fmt = [NSDateFormatter formatAtIndex:rowIndex];
  
  if ( [[aTableColumn identifier] isEqualToString: @"format"] )
    {
      return fmt;
    }
  else if ( [[aTableColumn identifier] isEqualToString: @"date"] )
    {
      return [[NSDateFormatter defaultFormatValue]
               descriptionWithCalendarFormat:fmt ];
    }
  else 
    {
      // Huuh?? Only 2 columns
      NSLog(@"Date table view only doesn't known column identifier: %@", [aTableColumn identifier]);
    }
  
  return nil;
  
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  [self ok: formatTable];
}

@end
