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

- (void)_update
{
  NSString *name,*new_name;
  NSMutableDictionary *d;
  int i;

  if (current < 0)
    return;

  name = [serviceList objectAtIndex:current];
  new_name = [tf_name stringValue];
  if (![new_name length])
    new_name = name;
  d = [services objectForKey:name];
  if (!d)
    d = [[NSMutableDictionary alloc] init];

  [d setObject:[tf_key stringValue]
        forKey:Key];
  [d setObject:[tf_cmdline stringValue]
        forKey:Commandline];
  [d setObject:[NSString stringWithFormat:@"%li",[pb_input indexOfSelectedItem]]
        forKey:Input];
  [d setObject:[NSString stringWithFormat:@"%li",[pb_output indexOfSelectedItem]]
        forKey:ReturnData];
  [d setObject:[NSString stringWithFormat:@"%li",[pb_type indexOfSelectedItem]]
        forKey:Type];

  i=0;
  if ([cb_string state]) i |= 1;
  if ([cb_filenames state]) i |= 2;
  [d setObject:[NSString stringWithFormat:@"%i",i]
        forKey:AcceptTypes];

  if (![name isEqual:new_name])
    {
      [services setObject:d forKey:new_name];
      [services removeObjectForKey:name];
      [serviceList replaceObjectAtIndex:current
                              withObject:new_name];
      [serviceTable reloadData];
    }
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

  {
    NSEnumerator *e = [d keyEnumerator];
    NSString     *key;
    while ((key = [e nextObject]))
      {
        [services setObject:[[d objectForKey:key] mutableCopy]
                     forKey:key];
      }
  }

  serviceList = [[[services allKeys]
                    sortedArrayUsingSelector:@selector(compare:)]
                   mutableCopy];

  [serviceTable reloadData];
  current = -1;
  [self tableViewSelectionDidChange:nil];
}

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

- (void)awakerFromNib
{
  [serviceTable setDelegate:self];
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



- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  return [serviceList count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc  row:(int)row
{
  return [serviceList objectAtIndex:row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)n
{
  int r=[serviceTable selectedRow];

  if (current>=0)
    [self _update];

  if (r>=0)
    {
      int i;
      NSString *name,*s;
      NSDictionary *d;

      name=[serviceList objectAtIndex: r];
      d=[services objectForKey: name];

      [tf_name setEditable: YES];
      [tf_cmdline setEditable: YES];
      [tf_key setEditable: YES];
      [pb_input setEnabled: YES];
      [pb_output setEnabled: YES];
      [pb_type setEnabled: YES];
      [cb_string setEnabled: YES];
      [cb_filenames setEnabled: YES];

      [tf_name setStringValue: name];

      s=[d objectForKey: Key];
      [tf_key setStringValue: s?s:@""];

      s=[d objectForKey: Commandline];
      [tf_cmdline setStringValue: s?s:@""];

      i=[[d objectForKey: Type] intValue];
      if (i<0 || i>2) i=0;
      [pb_type selectItemAtIndex: i];

      i=[[d objectForKey: Input] intValue];
      if (i<0 || i>2) i=0;
      [pb_input selectItemAtIndex: i];

      i=[[d objectForKey: ReturnData] intValue];
      if (i<0 || i>1) i=0;
      [pb_output selectItemAtIndex: i];

      if ([d objectForKey: AcceptTypes])
        {
          i=[[d objectForKey: AcceptTypes] intValue];
          [cb_string setState: !!(i&1)];
          [cb_filenames setState: !!(i&2)];
        }
      else
        {
          [cb_string setState: 1];
          [cb_filenames setState: 0];
        }
    }
  else
    {
      [tf_name setEditable: NO];
      [tf_cmdline setEditable: NO];
      [tf_key setEditable: NO];
      [pb_input setEnabled: NO];
      [pb_output setEnabled: NO];
      [pb_type setEnabled: NO];
      [cb_string setEnabled: NO];
      [cb_filenames setEnabled: NO];

      [tf_name setStringValue: @""];
      [tf_key setStringValue: @""];
      [tf_cmdline setStringValue: @""];
    }

  current=r;
}

// "Remove" button
- (void)removeService:(id)sender
{
	NSString *name;
	if (current<0)
		return;
	[serviceTable deselectAll: self];

	name=[serviceList objectAtIndex: current];
	[services removeObjectForKey: name];
	[serviceList removeObjectAtIndex: current];

	[serviceTable reloadData];
	current=-1;
	[self tableViewSelectionDidChange: nil];
}

// "New" button
- (void)addService:(id)sender
{
  NSString *n=_(@"Unnamed service");
  [serviceList addObject: n];
  [serviceTable reloadData];
  [serviceTable selectRow: [serviceList count]-1 byExtendingSelection: NO];
}

@end

