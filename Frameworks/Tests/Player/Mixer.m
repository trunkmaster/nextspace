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

#import <SoundKit/SoundKit.h>

#import "Mixer.h"

static void *OutputVolumeContext = &OutputVolumeContext;

@implementation Mixer

- init
{
  self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"Mixer" owner:self];
  }
  
  return self;
}

- (void)awakeFromNib
{
  [window setFrameAutosaveName:@"Mixer"];
  [window makeKeyAndOrderFront:self];
  [self updateOutputDeviceList];
}

- (NSWindow *)window
{
  return window;
}

// --- Key-Value Observing
- (void)observeOutput:(SKSoundOut *)output
{
  [output.sink addObserver:self
                forKeyPath:@"channelVolumes"
                   options:NSKeyValueObservingOptionNew
                   context:OutputVolumeContext];
  [output.sink addObserver:self
                forKeyPath:@"mute"
                   options:NSKeyValueObservingOptionNew
                   context:OutputVolumeContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SKSoundOut *output = [[outputDevice selectedItem] representedObject];
  
  if (context == OutputVolumeContext) {
    if (object == output.sink) {
      NSLog(@"SoundOut received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [outputMute setState:[output isMuted]];
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [outputVolume setIntegerValue:[output volume]];
        NSLog(@"Set balance: %f", [output balance]);
        [outputBalance setFloatValue:[output balance]];
      }
    }
  } else {
    // Any unrecognized context must belong to super
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

// --- Streams actions
- (void)reloadBrowser:(NSBrowser *)browser
{
  NSString *selected = [[appBrowser selectedCellInColumn:0] title];
    
  [appBrowser reloadColumn:0];
  [appBrowser setTitle:@"Streams" ofColumn:0];

  if (selected == nil) {
    [appBrowser selectRow:0 inColumn:0];
  }
}
 
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

// --- Output actions
// Fills "Device" popup with port names
- (void)updateOutputDeviceList
{
  NSString      *title;
  SKSoundServer *server = [SKSoundServer sharedServer];
  SKSoundOut    *defOut;
  
  [outputDevice removeAllItems];

  for (SKSoundOut *output in [server outputList]) {
    for (NSString *port in [output availablePorts]) {
      title = [NSString stringWithFormat:@"%@", port];
      [outputDevice addItemWithTitle:title];
      [[outputDevice itemWithTitle:title] setRepresentedObject:output];
    }
    // KVO for added output
    [self observeOutput:output];
  }
  
  defOut = [server defaultOutput];
  [outputDevice selectItemWithTitle:[defOut activePort]];
  [outputMute setState:[defOut isMuted]];
  [outputVolume setIntegerValue:[defOut volume]];
  [outputBalance setFloatValue:[defOut balance]];
  
  [self updateOutputProfileList:outputDevice];
}

// "Device" popup button action. Fills "Profile" popup button.
- (void)updateOutputProfileList:(id)sender
{
  SKSoundOut *output = [[outputDevice selectedItem] representedObject];
  
  [outputDeviceProfile removeAllItems];
  [outputDeviceProfile addItemsWithTitles:[output availableProfiles]];
  [outputDeviceProfile selectItemWithTitle:[output activeProfile]];
}

- (void)outputMute:(id)sender
{
  [[[outputDevice selectedItem] representedObject] setMuted:[sender state]];
}

- (void)outputSetVolume:(id)sender
{
  SKSoundOut *output = [[outputDevice selectedItem] representedObject];

  NSLog(@"Output: set volume to %li (old: %lu)",
        [outputVolume integerValue], [output volume]);
  
  [output setVolume:[outputVolume integerValue]];
  
  NSLog(@"Output: volume was set to %lu", [output volume]);
}

- (void)outputSetBalance:(id)sender
{
  SKSoundOut *output = [[outputDevice selectedItem] representedObject];
  NSLog(@"Ouput: set balance: %@", [sender className]);
  [output setBalance:[outputBalance floatValue]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

@end
