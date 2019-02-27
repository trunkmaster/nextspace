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

static void *OutputContext = &OutputContext;

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
  [self fillDeviceList];
}

- (id)window
{
  return window;
}

// Fills "Device" popup with port names
- (void)fillDeviceList
{
  NSString      *title;
  SKSoundServer *server = [SKSoundServer sharedServer];
  
  [devicePort removeAllItems];

  for (SKSoundOut *output in [server outputList]) {
    for (NSDictionary *port in [output availablePorts]) {
      title = [NSString stringWithFormat:@"%@",
                      [port objectForKey:@"Description"]];
      [devicePort addItemWithTitle:title];
      [[devicePort itemWithTitle:title] setRepresentedObject:output];
    }
    // KVO for added output
    [self observeOutput:output];
  }
  
  [devicePort selectItemWithTitle:[[server defaultOutput] activePort]];
  [self setOutputPort:devicePort];
}

// "Fills "Profile" popup button.
- (void)fillProfileList
{
  SKSoundOut *device = [[devicePort selectedItem] representedObject];
  
  [deviceProfile removeAllItems];
  for (NSDictionary *profile in [device availableProfiles]) {
    [deviceProfile addItemWithTitle:profile[@"Description"]];
  }
  [deviceProfile selectItemWithTitle:[device activeProfile]];
}

// --- Key-Value Observing
- (void)observeOutput:(SKSoundOut *)output
{
  [output.sink addObserver:self
                forKeyPath:@"mute"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.sink addObserver:self
                forKeyPath:@"activePort"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.card addObserver:self
                forKeyPath:@"activeProfile"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.sink addObserver:self
                forKeyPath:@"channelVolumes"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SKSoundOut *output = [[devicePort selectedItem] representedObject];
  
  if (context == OutputContext) {
    if (object == output.sink) {
      NSLog(@"SoundOut received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [deviceMute setState:[output isMute]];
      }
      else if ([keyPath isEqualToString:@"activePort"]) {
        [devicePort selectItemWithTitle:output.activePort];
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [deviceVolume setIntegerValue:[output volume]];
        // NSLog(@"Set balance: %f", [output balance]);
        [deviceBalance setFloatValue:[output balance]];
      }
    }
    else if (object == output.card) {
      if ([keyPath isEqualToString:@"activeProfile"]) {
        [deviceProfile selectItemWithTitle:output.activeProfile];
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

- (void)setMode:(id)sender
{
  NSString *title = [[sender selectedItem] title];

  if ([title isEqualToString:@"Playback"]) {
    [deviceBox setTitle:@"Output"];
  }
  else if ([title isEqualToString:@"Recording"]) {
    [deviceBox setTitle:@"Input"];
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
// "Device" popup action
- (void)setOutputPort:(id)sender
{
  SKSoundOut *output = [[devicePort selectedItem] representedObject];

  [output setActivePort:[[devicePort selectedItem] title]];
  [deviceMute setState:[output isMute]];
  [deviceVolume setMaxValue:[output volumeSteps]-1];
  [deviceVolume setIntegerValue:[output volume]];
  [deviceBalance setFloatValue:[output balance]];
  [self fillProfileList];
}
// "Profile" popup action
- (void)setOutputProfile:(id)sender
{
  SKSoundOut *output = [[devicePort selectedItem] representedObject];

  [output setActiveProfile:[[deviceProfile selectedItem] title]];
}

- (void)setDeviceMute:(id)sender
{
  [[[devicePort selectedItem] representedObject] setMute:[sender state]];
}

- (void)setDeviceVolume:(id)sender
{
  SKSoundOut *output = [[devicePort selectedItem] representedObject];

  NSLog(@"Output: set volume to %li (old: %lu)",
        [deviceVolume integerValue], [output volume]);
  
  [output setVolume:[deviceVolume integerValue]];
  
  NSLog(@"Output: volume was set to %lu", [output volume]);
}

- (void)setDeviceBalance:(id)sender
{
  SKSoundOut *device = [[devicePort selectedItem] representedObject];
  NSLog(@"Device: set balance: %@", [sender className]);
  [device setBalance:[deviceBalance floatValue]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

@end
