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
- (void)_update
{
  // NSString *name,*new_name;
  NSString *name;
  NSMutableDictionary *d;
  int i;

  if (current < 0)
    return;

  name = [serviceList objectAtIndex:current];
  // new_name = [tf_name stringValue];
  // if (![new_name length])
  //   new_name = name;
  d = [services objectForKey:name];
  if (!d)
    d = [[NSMutableDictionary alloc] init];

  [d setObject:[commandTF stringValue]
        forKey:Commandline];
  [d setObject:[keyTF stringValue]
        forKey:Key];
  [d setObject:[NSString stringWithFormat:@"%li",[[selectionMatrix selectedCell] tag]]
        forKey:Input];
  [d setObject:[NSString stringWithFormat:@"%li",[[outputMatrix selectedCell] tag]]
        forKey:ReturnData];
  [d setObject:[NSString stringWithFormat:@"%li",[executeTypeBtn indexOfSelectedItem]]
        forKey:Type];

  i=0;
  if ([acceptPlainTextBtn state]) i |= 1;
  if ([acceptFilesBtn state]) i |= 2;
  [d setObject:[NSString stringWithFormat:@"%i",i]
        forKey:AcceptTypes];

  // if (![name isEqual:new_name])
  //   {
  //     [services setObject:d forKey:new_name];
  //     [services removeObjectForKey:name];
  //     [serviceList replaceObjectAtIndex:current
  //                            withObject:new_name];
  //     [serviceTable reloadData];
  //   }
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
      [services setObject:[[d objectForKey:key] mutableCopy]
                   forKey:key];
    }

  serviceList = [[[services allKeys]
                    sortedArrayUsingSelector:@selector(compare:)]
                   mutableCopy];

  [serviceTable reloadData];
  current = -1;
  [self tableViewSelectionDidChange:nil];
  [okBtn setEnabled:NO];
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
  
  [self _revert];
  [serviceTable selectRow:0 byExtendingSelection:NO];
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
  NSCell   *cell = [tableColumn dataCellForRow:rowIndex];
  NSRect   rowFrame;
  
  // NSLog(@"Table should edit row %li location: %@",
  //       rowIndex,
  //       NSStringFromRect([tableView rectOfRow:rowIndex]));
  // NSLog(@"Table visible rect: %@",
  //       NSStringFromRect([tableScrollView documentVisibleRect]));
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
  [nameChangeTF setStringValue:[cell stringValue]];
  
  [tableView addSubview:nameChangeTF];
  [panel makeFirstResponder:nameChangeTF];
  [nameChangeTF selectText:self];
  
  return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)n
{
  int r = [serviceTable selectedRow];

  // if (current >= 0)
  //   [self _update];

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
      [serviceList replaceObjectAtIndex:[nameChangeTF tag]
                             withObject:[nameChangeTF stringValue]];
      [serviceTable reloadData];
      [nameChangeTF removeFromSuperview];
    }
}

- (BOOL)controlTextShouldEndEditing:(NSText *)aText
{
  NSLog(@"textShouldEndEditing");
  // TODO: Check conflicting names
  [serviceList replaceObjectAtIndex:[nameChangeTF tag]
                         withObject:[nameChangeTF stringValue]];
  [serviceTable reloadData];
  
  return YES;
}

// If any change was made
- (void)markAsChanged:(id)sender
{
  [okBtn setEnabled:YES];
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
}

// "New" button
- (void)newService:(id)sender
{
  NSString *n=_(@"Unnamed service");
  [serviceList addObject:n];
  [serviceTable reloadData];
  [serviceTable selectRow:[serviceList count]-1 byExtendingSelection:NO];
  [serviceTable scrollRowToVisible:[serviceList count]-1];
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
      [ud setObject:[services copy]
             forKey:@"TerminalServices"];

      [TerminalServices updateServicesPlist];
    }
}

// "Save..." button
- (void)saveServicesAs:(id)sender
{
  NSLog(@"Terminal Services: 'Save...' button was clicked.");
}

@end

