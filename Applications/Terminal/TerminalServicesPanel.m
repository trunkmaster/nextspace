/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <DesktopKit/NXTAlert.h>

#import "Defaults.h"
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
  if ([nameChangeTF superview] != nil) {
    new_name = [nameChangeTF stringValue];
    if (![new_name length]) {
      new_name = name;
    }
  } else {
    new_name = name;
  }

  d = [services objectForKey:name];
  // New service arrived
  if (!d) {
    d = [[NSMutableDictionary alloc] init];
    [services setObject:d forKey:name];
  }

  // "Command and Key Equivalent"
  [d setObject:[commandTF stringValue] forKey:Commandline];
  [d setObject:[keyTF stringValue] forKey:Key];
  // "Accept"
  i = 0;
  if ([acceptPlainTextBtn state]) {
    i |= 1;
  }
  if ([acceptFilesBtn state]) {
    i |= 2;
  }
  [d setObject:[NSString stringWithFormat:@"%i", i] forKey:AcceptTypes];

  // Service name changed
  if (![name isEqual:new_name]) {
    [services setObject:d forKey:new_name];
    [services removeObjectForKey:name];
    [serviceList replaceObjectAtIndex:current withObject:new_name];
    [serviceTable reloadData];
  }

  // "Use Selection"
  [d setObject:[NSString stringWithFormat:@"%li", [[selectionMatrix selectedCell] tag]]
        forKey:Input];

  // "Execution"
  NSInteger execType = [executeTypeBtn indexOfSelectedItem];
  NSInteger outTag = [[outputMatrix selectedCell] tag];
  [d setObject:[NSString stringWithFormat:@"%li", execType] forKey:ExecType];
  [d setObject:[NSString stringWithFormat:@"%li", outTag]
        forKey:(execType == EXEC_IN_BACKGROUND) ? ReturnData : WindowType];
  [d setObject:[NSString stringWithFormat:@"%li", [[shellMatrix selectedCell] tag]]
        forKey:ExecInShell];
}

- (void)_revert
{
  NSDictionary *d;

  [serviceTable deselectAll:self];
  DESTROY(services);
  DESTROY(serviceList);

  services = [[NSMutableDictionary alloc] init];
  d = [TerminalServices terminalServicesDictionary];

  for (NSString *key in [d allKeys]) {
    [services setObject:[[d objectForKey:key] mutableCopy] forKey:key];
  }

  serviceList = [[[services allKeys] sortedArrayUsingSelector:@selector(compare:)] mutableCopy];

  [serviceTable reloadData];
  current = -1;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];
}

// --- Init and dealloc
- init
{
  self = [super init];
  if (panel == nil) {
    if ([NSBundle loadNibNamed:@"TerminalServices" owner:self] == NO) {
      NSLog(@"Error loading NIB TerminalServices");
      return self;
    }
  }

  return self;
}

- (void)awakeFromNib
{
  [panel setFrameAutosaveName:@"ServicesPanel"];

  [serviceTable setDelegate:self];
  [serviceTable setDataSource:self];
  [serviceTable setAllowsMultipleSelection:NO];
  [serviceTable setAllowsColumnSelection:NO];
  [serviceTable setAllowsEmptySelection:NO];
  [serviceTable setHeaderView:nil];
  [serviceTable setCornerView:nil];
  [serviceTable setAutoresizesAllColumnsToFit:YES];

  for (id cell in [selectionMatrix cells]) {
    [cell setRefusesFirstResponder:YES];
  }
  for (id cell in [outputMatrix cells]) {
    [cell setRefusesFirstResponder:YES];
  }
  for (id cell in [shellMatrix cells]) {
    [cell setRefusesFirstResponder:YES];
  }

  [acceptFilesBtn setRefusesFirstResponder:YES];
  [acceptPlainTextBtn setRefusesFirstResponder:YES];
  [acceptRichTextBtn setRefusesFirstResponder:YES];

  [executeTypeBtn setRefusesFirstResponder:YES];

  [self _revert];
  [serviceTable selectRow:0 byExtendingSelection:NO];
  [self updateOutputMatrix];
  [self updateShellMatrix];

  [commandTF setToolTip:@"If selection is to be placed on the command line, \nyou can mark the "
                        @"place to put it at with '%s' \n(otherwise it will be appended to the "
                        @"command line). \nYou can use '%%' to get a real '%'."];

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

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(int)row
{
  return [serviceList objectAtIndex:row];
}

- (BOOL)tableView:(NSTableView *)tableView
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
  if (nameChangeTF == nil) {
    nameChangeTF = [[NSTextField alloc] initWithFrame:rowFrame];
    [nameChangeTF setDelegate:self];
    [nameChangeTF setBezeled:NO];
    [nameChangeTF setBordered:YES];
  } else {
    [nameChangeTF setFrameOrigin:rowFrame.origin];
  }

  [nameChangeTF setTag:rowIndex];
  [nameChangeTF setStringValue:[serviceList objectAtIndex:rowIndex]];

  [tableView addSubview:nameChangeTF];
  [panel makeFirstResponder:nameChangeTF];
  [nameChangeTF selectText:self];

  // will be enabled in -controlTextDidEndEditing:
  [[panel defaultButtonCell] setEnabled:NO];

  return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)n
{
  int r = [serviceTable selectedRow];

  if (current >= 0) {
    [self _update];
  }

  if (r >= 0) {
    int i;
    NSString *name, *s;
    NSDictionary *d;

    name = [serviceList objectAtIndex:r];
    d = [services objectForKey:name];

    [commandTF setEditable:YES];
    [keyTF setEditable:YES];

    [acceptPlainTextBtn setEnabled:YES];
    [acceptFilesBtn setEnabled:YES];
    [acceptRichTextBtn setEnabled:YES];
    [selectionMatrix setEnabled:YES];

    [executeTypeBtn setEnabled:YES];
    [outputMatrix setEnabled:YES];
    [shellMatrix setEnabled:YES];

    s = [d objectForKey:Commandline];
    [commandTF setStringValue:s ? s : @""];

    s = [d objectForKey:Key];
    [keyTF setStringValue:s ? s : @""];

    // "Accept"
    if ([d objectForKey:AcceptTypes]) {
      i = [[d objectForKey:AcceptTypes] intValue];
      [acceptPlainTextBtn setState:!!(i & 1)];
      [acceptFilesBtn setState:!!(i & 2)];
    } else {
      [acceptPlainTextBtn setState:1];
      [acceptFilesBtn setState:0];
    }

    // "Use Selection"
    i = [[d objectForKey:Input] intValue];
    if (i < 0 || i > 2) {
      i = 0;
    }
    [selectionMatrix selectCellWithTag:i];

    // "Execution"
    i = [[d objectForKey:ExecType] intValue];
    if (i < 0 || i > 1) {
      i = 0;
    }
    [executeTypeBtn selectItemAtIndex:i];

    // outputMatrix
    if (i == EXEC_IN_BACKGROUND) {
      i = [[d objectForKey:ReturnData] intValue];
    } else {
      i = [[d objectForKey:WindowType] intValue];
    }
    if (i < 0 || i > 1) {
      i = 0;
    }
    [outputMatrix selectCellWithTag:i];
    [self updateOutputMatrix];

    // shellMatrix
    i = [[d objectForKey:ExecInShell] intValue];
    if (i < 0 || i > 1) {
      i = 0;
    }
    [shellMatrix selectCellWithTag:i];
    [self updateShellMatrix];
  } else {
    [commandTF setEditable:NO];
    [commandTF setStringValue:@""];
    [keyTF setEditable:NO];
    [keyTF setStringValue:@""];

    [acceptPlainTextBtn setEnabled:NO];
    [acceptFilesBtn setEnabled:NO];
    [acceptRichTextBtn setEnabled:NO];
    [selectionMatrix setEnabled:NO];

    [executeTypeBtn setEnabled:NO];
    [outputMatrix setEnabled:NO];
    [shellMatrix setEnabled:NO];
  }

  current = r;
}

- (void)updateOutputMatrix
{
  if ([executeTypeBtn indexOfSelectedItem] == EXEC_IN_BACKGROUND) {
    [[outputMatrix cellWithTag:0] setTitle:@"Discard Output"];
    [[outputMatrix cellWithTag:1] setTitle:@"Return Output"];
  } else {
    [[outputMatrix cellWithTag:0] setTitle:@"Idle Window"];
    [[outputMatrix cellWithTag:1] setTitle:@"New Window"];
  }
}
- (void)updateShellMatrix
{
  BOOL enabled = YES;
  NSMutableAttributedString *aTitle;

  // Run Service in a Window
  if (([executeTypeBtn indexOfSelectedItem]) == EXEC_IN_WINDOW &&
      ([[outputMatrix selectedCell] tag] == WINDOW_IDLE)) {
    enabled = NO;
  }

  if (enabled) {
    [shellMatrix setEnabled:YES];
    for (id cell in [shellMatrix cells]) {
      aTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedTitle]];
      [aTitle addAttribute:NSForegroundColorAttributeName
                     value:[NSColor blackColor]
                     range:NSMakeRange(0, [aTitle length])];
      [cell setAttributedTitle:aTitle];
    }
  } else {
    [shellMatrix setEnabled:NO];
    for (id cell in [shellMatrix cells]) {
      aTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedTitle]];
      [aTitle addAttribute:NSForegroundColorAttributeName
                     value:[NSColor darkGrayColor]
                     range:NSMakeRange(0, [aTitle length])];
      [cell setAttributedTitle:aTitle];
    }
  }
}

// Service name change Text Field
- (void)controlTextDidBeginEditing:(NSNotification *)aNotif
{
  if ([aNotif object] != nameChangeTF) {
    [okBtn setEnabled:YES];
    [saveBtn setEnabled:NO];
    [panel setDocumentEdited:YES];
  }
}
- (void)controlTextDidEndEditing:(NSNotification *)aNotif
{
  if ([aNotif object] == nameChangeTF) {
    NSString *sName = [nameChangeTF stringValue];
    NSArray *sList;

    for (NSString *s in serviceList) {
      if ([s isEqualToString:sName]) {
        NXTRunAlertPanel(@"Terminal Services",
                         @"Service with name \"%@\" already exist."
                         @" Choose another name for service please.",
                         @"OK", nil, nil, sName);
        // TODO: in GNUstep/Workspace. Why focus is not returned to
        // the last key window by default?
        [panel makeKeyAndOrderFront:self];
        [panel makeFirstResponder:nameChangeTF];
        return;
      }
    }

    [self _update];
    [nameChangeTF removeFromSuperview];

    sList = [serviceList sortedArrayUsingSelector:@selector(compare:)];
    [serviceList release];
    serviceList = [sList mutableCopy];

    [serviceTable selectRow:[sList indexOfObject:sName] byExtendingSelection:NO];
    [serviceTable scrollRowToVisible:[sList indexOfObject:sName]];
    [self markAsChanged:self];
  }
}

// Check if current dictionary was changed
- (void)markAsChanged:(id)sender
{
  // NSLog(@"First responder: %@", [[panel firstResponder] className]);

  if ([panel firstResponder] != commandTF) {
    // NSLog(@"markAsChanged: first reponder is Command Text Field.");
    [panel makeFirstResponder:commandTF];
    [[panel fieldEditor:NO forObject:commandTF]
        setSelectedRange:NSMakeRange([[commandTF stringValue] length], 0)];
  }

  if (sender == executeTypeBtn) {
    [self updateOutputMatrix];
    sender = outputMatrix;
  }

  if (sender == outputMatrix) {
    [self updateShellMatrix];
  }

  [self _update];

  if (![services isEqual:[TerminalServices terminalServicesDictionary]]) {
    [okBtn setEnabled:YES];
    [saveBtn setEnabled:NO];
    [panel setDocumentEdited:YES];
  } else {
    [okBtn setEnabled:NO];
    [saveBtn setEnabled:YES];
    [panel setDocumentEdited:NO];
  }
}

// "Remove" button
- (void)removeService:(id)sender
{
  NSString *name;

  if (current < 0) {
    return;
  }
  [serviceTable deselectAll:self];

  name = [serviceList objectAtIndex:current];
  [services removeObjectForKey:name];
  [serviceList removeObjectAtIndex:current];

  [serviceTable reloadData];
  current = -1;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];
}

// "New" button
- (void)newService:(id)sender
{
  NSString *n;
  NSInteger row, sc = 1;

  for (NSString *s in serviceList) {
    if ([s rangeOfString:@"New Service"].location != NSNotFound) {
      sc++;
    }
  }
  n = [NSString stringWithFormat:@"New Service #%li", sc];

  [serviceList addObject:n];
  [serviceTable reloadData];
  row = [serviceList count] - 1;
  [serviceTable selectRow:row byExtendingSelection:NO];
  [serviceTable scrollRowToVisible:row];

  current = row;
  [self tableViewSelectionDidChange:nil];
  [self markAsChanged:self];

  [self tableView:serviceTable
      shouldEditTableColumn:[[serviceTable tableColumns] objectAtIndex:0]
                        row:row];
}

// "OK" button
// Save services to ~/Library/Services/TerminalServices.plist
- (void)saveServices:(id)sender
{
  NSUserDefaults *ud;

  if (!services) {
    return;
  }

  // id fr = [panel firstResponder];
  // if (fr == nameChangeTF || fr == commandTF || fr == keyTF)
  //   return;

  [self _update];

  ud = [NSUserDefaults standardUserDefaults];

  if (![services isEqual:[TerminalServices terminalServicesDictionary]]) {
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
  [saveServicesTable reloadData];
  // [saveServicesTable deselectAll:self]; // TODO: doesn't work
  for (int i = 0; i < [saveServicesTable numberOfRows]; i++) {
    [saveServicesTable deselectRow:i];
  }

  if (![savePanel accessoryView]) {
    [savePanel setAccessoryView:accView];
  }

  if ([savePanel runModalForDirectory:[Defaults sessionsDirectory] file:nil] == NSOKButton) {
    NSEnumerator *rowsEnum = [saveServicesTable selectedRowEnumerator];
    id row;
    NSMutableArray *sList = [NSMutableArray new];
    NSString *fName = [savePanel filename];

    while ((row = [rowsEnum nextObject]) != nil) {
      [sList addObject:[serviceList objectAtIndex:[row intValue]]];
    }

    if ([[fName pathExtension] isEqualToString:@""]) {
      fName = [fName stringByAppendingPathExtension:@"svcs"];
    }

    [[TerminalServices plistForServiceNames:sList] writeToFile:fName atomically:YES];
    [sList release];
  }
  [panel makeKeyAndOrderFront:self];
}

@end
