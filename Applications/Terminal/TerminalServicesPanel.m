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
  NSString *name,*new_name;
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

- (void)_save
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
  
  [self _revert];
  [serviceTable selectRow:0 byExtendingSelection:NO];
}

- (void)activatePanel
{
  [panel orderFront:self];
}

- (void)dealloc
{
  DESTROY(services);
  DESTROY(serviceList);
  [super dealloc];
}

// --- Controls
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
      NSLog(@"Service '%@' = %@", name, d);

      [commandTF setEditable:YES];
      [keyTF setEditable:YES];
      [selectionMatrix setEnabled:YES];
      [outputMatrix setEnabled:YES];
      [executeTypeBtn setEnabled:YES];
      [acceptPlainTextBtn setEnabled:YES];
      [acceptFilesBtn setEnabled:YES];

      s = [d objectForKey:Commandline];
      [commandTF setStringValue:s?s:@""];
      NSLog(@"Services click on '%@', CMD='%@'", name, s);
      
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

@end

