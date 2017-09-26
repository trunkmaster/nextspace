/*
  Copyright (C) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>

#import "TerminalServices.h"
#import "TerminalServicesPanel.h"

@implementation TerminalServicesPanel

// --- Utility
/* Update selected service's dictionary */
- (void)_update
{
  NSString *name, *new_name;
  NSMutableDictionary *d;
  int i;

  if (current < 0)
    return;

  name = [serviceList objectAtIndex:current];
  if ([nameChangeTF superview] != nil)
    {
      new_name = [nameChangeTF stringValue];
      if (![new_name length])
        new_name = name;
    }
  else
    {
      new_name = name;
    }
  
  d = [services objectForKey:name];
  if (!d) // New service arrived
    {
      d = [[NSMutableDictionary alloc] init];
      [services setObject:d forKey:name];
    }

  // "Command and Key Equivalent"
  [d setObject:[commandTF stringValue] forKey:Commandline];
  [d setObject:[keyTF stringValue] forKey:Key];
  // "Use Selection"
  [d setObject:[NSString stringWithFormat:@"%li",
                         [[selectionMatrix selectedCell] tag]]
        forKey:Input];
  // "Execution"
  NSInteger execType = [executeTypeBtn indexOfSelectedItem];
  NSInteger polyTag = [[outputMatrix selectedCell] tag];
  switch (execType)
    {
    case 0:
      [d setObject:[NSString stringWithFormat:@"%li", execType]
            forKey:Type];
      [d setObject:[NSString stringWithFormat:@"%li", polyTag]
            forKey:ReturnData];
      break;
    case 1:
      [d setObject:[NSString stringWithFormat:@"%li", execType + polyTag]
            forKey:Type];
      break;
    }
  // [d setObject:[NSString stringWithFormat:@"%li",
  //                        [executeTypeBtn indexOfSelectedItem]]
  //       forKey:Type];
  // [d setObject:[NSString stringWithFormat:@"%li",
  //                        [[outputMatrix selectedCell] tag]]
  //       forKey:ReturnData];
  [d setObject:[NSString stringWithFormat:@"%li",
                         [[shellMatrix selectedCell] tag]]
        forKey:ExecuteInShell];
  // "Accept"
  i = 0;
  if ([acceptPlainTextBtn state]) i |= 1;
  if ([acceptFilesBtn state]) i |= 2;
  [d setObject:[NSString stringWithFormat:@"%i", i]
        forKey:AcceptTypes];

  if (![name isEqual:new_name]) // Service name changed
    {
      [services setObject:d forKey:new_name];
      [services removeObjectForKey:name];
      [serviceList replaceObjectAtIndex:current
                             withObject:new_name];
      [serviceTable reloadData];
    }
}

- (void)_revert
{
  NSDictionary *d;

  [serviceTable deselectAll:self];
  DESTROY(services);
  DESTROY(serviceList);

  services = [[NSMutableDictionary alloc] init];
  d = [TerminalServices terminalServicesDictionary];

  for (NSString *key in [d allKeys])
    {
      [services setObject:[[d objectForKey:key] mutableCopy] forKey:key];
    }

  serviceList = [[[services allKeys]
                    sortedArrayUsingSelector:@selector(compare:)]
                   mutableCopy];

  [serviceTable reloadData];
  current = -1;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];
}

// --- Init and dealloc
- init
{
  self = [super init];
  if (panel == nil)
    {
      if ([NSBundle loadNibNamed:@"TerminalServices" owner:self] == NO)
        {
          NSLog(@"Error loading NIB TerminalServices");
          return self;
        }
    }
  
  return self;
}

- (void)awakeFromNib
{
  [serviceTable setDelegate:self];
  [serviceTable setDataSource:self];
  [serviceTable setAllowsMultipleSelection:NO];
  [serviceTable setAllowsColumnSelection:NO];
  [serviceTable setAllowsEmptySelection:NO];
  [serviceTable setHeaderView:nil];
  [serviceTable setCornerView:nil];
  [serviceTable setAutoresizesAllColumnsToFit:YES];

  for (id cell in [selectionMatrix cells])
    [cell setRefusesFirstResponder:YES];
  for (id cell in [outputMatrix cells])
    [cell setRefusesFirstResponder:YES];
  for (id cell in [shellMatrix cells])
    [cell setRefusesFirstResponder:YES];
  
  [acceptFilesBtn setRefusesFirstResponder:YES];
  [acceptPlainTextBtn setRefusesFirstResponder:YES];
  [acceptRichTextBtn setRefusesFirstResponder:YES];

  [executeTypeBtn setRefusesFirstResponder:YES];
  
  [self _revert];
  [serviceTable selectRow:0 byExtendingSelection:NO];

  [commandTF setToolTip:@"If selection is to be placed on the command line, \nyou can mark the place to put it at with '%s' \n(otherwise it will be appended to the command line). \nYou can use '%%' to get a real '%'."];

  [panel setDefaultButtonCell:[okBtn cell]];
  
  [accView retain];
  [saveServicesTable setDelegate:self];
  [saveServicesTable setDataSource:self];
  [saveServicesTable setAllowsMultipleSelection:YES];
  [saveServicesTable setAllowsColumnSelection:NO];
  [saveServicesTable setAllowsEmptySelection:NO];
  [saveServicesTable setHeaderView:nil];
  [saveServicesTable setCornerView:nil];
  [saveServicesTable setAutoresizesAllColumnsToFit:YES];
}

- (void)activatePanel
{
  [self _revert];
  [panel makeKeyAndOrderFront:self];
}

- (void)dealloc
{
  DESTROY(services);
  DESTROY(serviceList);
  DESTROY(nameChangeTF);
  [super dealloc];
}

// --- Controls
// Services list table
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  return [serviceList count];
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  return [serviceList objectAtIndex:row];
}

- (BOOL)    tableView:(NSTableView *)tableView
shouldEditTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)rowIndex
{
  NSRect rowFrame;
  
  [serviceTable scrollRowToVisible:rowIndex];

  rowFrame = [tableView rectOfRow:rowIndex];
  rowFrame.size.height += 5;
  rowFrame.size.width += 4;
  rowFrame.origin.y -= 2;
  rowFrame.origin.x -= 2;
  if (nameChangeTF == nil)
    {
      nameChangeTF = [[NSTextField alloc] initWithFrame:rowFrame];
      [nameChangeTF setDelegate:self];
      [nameChangeTF setBezeled:NO];
      [nameChangeTF setBordered:YES];
    }
  else
    {
      [nameChangeTF setFrameOrigin:rowFrame.origin];
    }

  [nameChangeTF setTag:rowIndex];
  [nameChangeTF setStringValue:[serviceList objectAtIndex:rowIndex]];
  
  [tableView addSubview:nameChangeTF];
  [panel makeFirstResponder:nameChangeTF];
  [nameChangeTF selectText:self];
  
  return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)n
{
  int r = [serviceTable selectedRow];

  if (current >= 0)
    [self _update];

  if (r >= 0)
    {
      int i;
      NSString *name,*s;
      NSDictionary *d;

      name = [serviceList objectAtIndex:r];
      d = [services objectForKey:name];

      [commandTF setEditable:YES];
      [keyTF setEditable:YES];
      [selectionMatrix setEnabled:YES];
      [outputMatrix setEnabled:YES];
      [executeTypeBtn setEnabled:YES];
      [acceptPlainTextBtn setEnabled:YES];
      [acceptFilesBtn setEnabled:YES];

      s = [d objectForKey:Commandline];
      [commandTF setStringValue:s?s:@""];
      
      s = [d objectForKey:Key];
      [keyTF setStringValue:s?s:@""];

      i = [[d objectForKey:Type] intValue];
      if (i<0 || i>2) i=0;
      [executeTypeBtn selectItemAtIndex:i];

      i = [[d objectForKey:Input] intValue];
      if (i<0 || i>2) i = 0;
      [selectionMatrix selectCellWithTag:i];

      i=[[d objectForKey:ReturnData] intValue];
      if (i<0 || i>1) i = 0;
      [outputMatrix selectCellWithTag:i];

      if ([d objectForKey:AcceptTypes])
        {
          i = [[d objectForKey:AcceptTypes] intValue];
          [acceptPlainTextBtn setState: !!(i&1)];
          [acceptFilesBtn setState: !!(i&2)];
        }
      else
        {
          [acceptPlainTextBtn setState: 1];
          [acceptFilesBtn setState: 0];
        }
    }
  else
    {
      [commandTF setEditable:NO];
      [keyTF setEditable:NO];
      [selectionMatrix setEnabled:NO];
      [outputMatrix setEnabled:NO];
      [executeTypeBtn setEnabled:NO];
      [acceptPlainTextBtn setEnabled:NO];
      [acceptFilesBtn setEnabled:NO];

      [keyTF setStringValue:@""];
      [commandTF setStringValue:@""];
    }

  current = r;
}

// Service name change Text Field
- (void)controlTextDidEndEditing:(NSNotification *)aNotif
{
  NSLog(@"textDidEndEditing");
  if ([aNotif object] == nameChangeTF)
    {
      [self _update];
      [nameChangeTF removeFromSuperview];
      [self markAsChanged:self];
    }
}

// Check if current dictionary was changed
- (void)markAsChanged:(id)sender
{
  if (sender == commandTF || sender == keyTF)
    {
      [panel setDefaultButtonCell:[okBtn cell]];
    }

  if (sender == executeTypeBtn)
    {
      switch([executeTypeBtn indexOfSelectedItem])
        {
        case 0: // Run Service in the Background
          [[outputMatrix cellWithTag:0] setTitle:@"Discard Output"]; // 0 + 0 = 0
          [[outputMatrix cellWithTag:1] setTitle:@"Return Output"];  // 0 + 1 = 1
          break;
        case 1: // Run Service in a Window
          [[outputMatrix cellWithTag:0] setTitle:@"Idle Window"]; // 1 + 0 = 1
          [[outputMatrix cellWithTag:1] setTitle:@"New Window"];  // 1 + 1 = 2
          break;
        }
    }
  
  [self _update];
  
  if (![services isEqual:[TerminalServices terminalServicesDictionary]])
    {
      [okBtn setEnabled:YES];
      [panel setDocumentEdited:YES];
    }
  else
    {
      [okBtn setEnabled:NO];
      [panel setDocumentEdited:NO];      
    }
}

// "Remove" button
- (void)removeService:(id)sender
{
  NSString *name;
  
  if (current < 0)
    return;
  
  [serviceTable deselectAll:self];

  name = [serviceList objectAtIndex:current];
  [services removeObjectForKey:name];
  [serviceList removeObjectAtIndex:current];

  [serviceTable reloadData];
  current=-1;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];
}

// "New" button
- (void)newService:(id)sender
{
  NSString  *n = _(@"Unnamed service");
  NSInteger row;
  
  [serviceList addObject:n];
  [serviceTable reloadData];
  row = [serviceList count] - 1;
  [serviceTable selectRow:row byExtendingSelection:NO];
  [serviceTable scrollRowToVisible:row];

  [self tableView:serviceTable
        shouldEditTableColumn:[[serviceTable tableColumns] objectAtIndex:0]
              row:row];
  
  current = row;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];
}

// "OK" button
// Save services to ~/Library/Services/TerminalServices.plist
- (void)saveServices:(id)sender
{
  NSUserDefaults *ud;

  if (!services) return;

  [self _update];

  ud = [NSUserDefaults standardUserDefaults];

  if (![services isEqual:[TerminalServices terminalServicesDictionary]])
    {
      [ud setObject:[services copy] forKey:@"TerminalServices"];
      [ud synchronize];

      [TerminalServices updateServicesPlist];
    }
  
  [self _revert];
}

// "Save..." button
- (void)saveServicesAs:(id)sender
{
  NSSavePanel *savePanel = [NSSavePanel savePanel];

  [savePanel setTitle:@"Save Services"];
  [savePanel setShowsHiddenFiles:NO];

  // Accessory view
  [savePanel setAccessoryView:accView];
  [saveServicesTable reloadData];
  
  if ([savePanel runModalForDirectory:[TerminalServices serviceDirectory]
                                 file:nil] == NSOKButton)
    {
      
    }
}

@end

