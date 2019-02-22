/*
   Project: Mixer

   Copyright (C) 2019 Sergii Stoian

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <stdio.h>
#import <string.h>

#import <SoundKit/SoundKit.h>

#import "Mixer.h"

@implementation Mixer

- init
{
  self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"Mixer" owner:self];
  }
  [window makeKeyAndOrderFront:self];
  
  return self;
}

- (void)awakeFromNib
{
  [self updateOutputDeviceList];
}

- (NSWindow *)window
{
  return window;
}


- (void)reloadBrowser:(NSBrowser *)browser
{
  NSString *selected = [[appBrowser selectedCellInColumn:0] title];
    
  [appBrowser reloadColumn:0];
  [appBrowser setTitle:@"Streams" ofColumn:0];

  if (selected == nil) {
    [appBrowser selectRow:0 inColumn:0];
  }
}
 
// Sink-Port list
- (void)updateOutputDeviceList
{
  NSString      *title;
  SKSoundServer *server = [SKSoundServer sharedServer];
  SKSoundOut    *defOut = [server defaultOutput];
  
  [outputDevice removeAllItems];
  
  for (NSString *port in [defOut availablePorts]) {
    title = [NSString stringWithFormat:@"%@", port];
    [outputDevice addItemWithTitle:title];
    [[outputDevice itemWithTitle:title] setRepresentedObject:defOut];
  }
  
  [outputDevice selectItemWithTitle:[defOut activePort]];
  [outputVolume setFloatValue:[[defOut volume][0] floatValue]];
  [self updateOutputProfileList:outputDevice];
}
// "Device" popup button action. Fills "Profile" popup button.
- (void)updateOutputProfileList:(id)sender
{
  SKSoundOut *defOut = [[SKSoundServer sharedServer] defaultOutput];
  
  [outputDeviceProfile removeAllItems];
  [outputDeviceProfile addItemsWithTitles:[defOut availableProfiles]];
  [outputDeviceProfile selectItemWithTitle:[defOut activeProfile]];
}

// --- Browser delegate ---
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  // NSString      *mode = [[modeButton selectedItem] title];
  // NSBrowserCell *cell;

  // if ([mode isEqualToString:@"Playback"]) {
  //   // Get streams of "sink-input-by-media-role" type first
  //   for (PAStream *st in streamList) {
  //     if ([[st typeName] isEqualToString:@"sink-input-by-media-role"]) {
  //       [matrix addRow];
  //       cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //       [cell setLeaf:YES];
  //       [cell setRefusesFirstResponder:YES];
  //       [cell setTitle:[NSString stringWithFormat:@"%@ Sounds", [st clientName]]];
  //       [cell setRepresentedObject:st];
  //     }
  //   }
  //   for (PASinkInput *si in sinkInputList) {
  //     [matrix addRow];
  //     cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //     [cell setLeaf:YES];
  //     [cell setRefusesFirstResponder:YES];
  //     [cell setTitle:[si nameForClients:clientList streams:streamList]];
  //     [cell setRepresentedObject:si];
  //   }
  // }
  // else if ([mode isEqualToString:@"Recording"]) {
  //   // TODO
  // }
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

// --- Actions
- (void)browserClick:(id)sender
{
  id object = [[sender selectedCellInColumn:0] representedObject];

  if (object == nil) {
    return;
  }
  
  // NSLog(@"Browser received click: %@, cell - %@, repObject - %@",
  //       [sender className], [[sender selectedCellInColumn:0] title],
  //       [[[sender selectedCellInColumn:0] representedObject] className]);
  
  // if ([object respondsToSelector:@selector(volumes)]) {
  //   NSArray *volume = [object volumes];
  //   if (volume != nil && [volume count] > 0) {
  //     [appVolume setFloatValue:[volume[0] floatValue]];
  //   }
  // }
}

- (void)appMuteClick:(id)sender
{
  // [[[appBrowser selectedCellInColumn:0] representedObject] setMute:[sender state]];
}

@end
