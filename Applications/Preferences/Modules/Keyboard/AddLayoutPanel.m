/* -*- mode: objc -*- */
//
// Project: Preferences
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

#import "Keyboard.h"
#import "AddLayoutPanel.h"

@implementation AddLayoutPanel

- initWithKeyboard:(OSEKeyboard *)k
{
  self = [super init];
  
  keyboard = [k retain];
  
  if (!panel)
    {
      if (![NSBundle loadNibNamed:@"AddLayoutPanel" owner:self])
        {
          NSLog (@"Could not load AddLayoutPanel.gorm file.");
          return nil;
        }
    }

  return self;
}

- (void)awakeFromNib
{
  // [panel setResizeIncrements:NSMakeSize(271,1)];
  // [panel makeFirstResponder:browser];

  layoutDict = [keyboard availableLayouts];
  [layoutDict retain];
  layoutList = [layoutDict keysSortedByValueUsingSelector:@selector(compare:)];
  [layoutList retain];

  [browser loadColumnZero];
  [browser selectRow:0 inColumn:0];
  [browser setTarget:self];
  [browser setAction:@selector(click:)];
  [browser setTitle:@"Language" ofColumn:0];
  [browser setTitle:@"Variant" ofColumn:1];
  [browser setTakesTitleFromPreviousColumn:NO];
  // [browser addColumn];
  // [browser scrollColumnToVisible:0];
  [browser setAcceptsArrowKeys:YES];
  [browser setSendsActionOnArrowKeys:YES];

  [infoField setStringValue:@""];

  [panel makeFirstResponder:browser];
}

- (NSWindow *)panel
{
  return panel;
}

- (void)orderFront:(Keyboard *)kPreferences
{
  kPrefs = kPreferences;
  [panel center];
  [panel makeKeyAndOrderFront:self];
}

//
// NSBrowser delegate
// 
- (NSInteger) browser:(NSBrowser *)sender
 numberOfRowsInColumn:(NSInteger)column
{
  if (column == 0)
    {
      return [layoutList count];
    }
  else
    {
      NSString *layoutTitle = [[browser selectedCellInColumn:0] title];
  
      if (variantDict)
        [variantDict release];
      
      variantDict = [[keyboard variantListForLanguage:layoutTitle] copy];
      // [variantDict retain];

      return [[variantDict allKeys] count];
    }
}

- (void) browser:(NSBrowser *)sender
 willDisplayCell:(id)cell
           atRow:(NSInteger)row
          column:(NSInteger)column
{
  NSString *layout = nil;
  
  [cell setLeaf:YES];

  if (column == 0)
    {
      layout = [layoutList objectAtIndex:row];
      [cell setRepresentedObject:layout];
      layout = [layoutDict objectForKey:layout];
      [cell setTitle:layout];

      if ([[[keyboard variantListForLanguage:layout] allKeys] count] > 0)
        [cell setLeaf:NO];
    }
  else if (column == 1)
    {
      NSArray      *keyList;
      NSString     *key;

      keyList = [variantDict
                  keysSortedByValueUsingSelector:@selector(compare:)];
      key = [keyList objectAtIndex:row];
      
      [cell setTitle:[variantDict objectForKey:key]];
      [cell setRepresentedObject:key];
    }
}

- (void)click:sender
{
  NSString *info, *layoutTitle;
  
  [browser setTitle:@"Variant" ofColumn:1];
  
  layoutTitle = [[browser selectedCellInColumn:0] title];
  
  if (![[browser selectedCellInColumn:1] title])
    {
      info = [NSString stringWithFormat:@"%@ -- [%@]",
                       layoutTitle,
                       [[browser selectedCellInColumn:0] representedObject]];
    }
  else
    {
      info = [NSString stringWithFormat:@"%@ (%@) -- [%@, %@]",
                       layoutTitle,
                       [[browser selectedCellInColumn:1] title],
                       [[browser selectedCellInColumn:0] representedObject],
                       [[browser selectedCellInColumn:1] representedObject]];
    }
  [infoField setStringValue:info];
}

//
// Actions
//
- (void)addLayout:(id)sender
{
  [kPrefs addLayout:[[browser selectedCellInColumn:0] representedObject]
            variant:[[browser selectedCellInColumn:1] representedObject]];
}

@end
