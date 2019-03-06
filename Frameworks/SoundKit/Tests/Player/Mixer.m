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
static void *InputContext = &InputContext;

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
  [self fillCardList];
}

- (id)window
{
  return window;
}

- (void)fillCardList
{
  SKSoundServer *server = [SKSoundServer sharedServer];
  NSString      *title;
  
  [deviceCardBtn removeAllItems];
  
  for (SKSoundDevice *device in [server cardList]) {
    NSLog(@"Device: %@", device.description);
    title = device.description;
    [deviceCardBtn addItemWithTitle:title];
    [[deviceCardBtn itemWithTitle:title] setRepresentedObject:device];
  }

  NSLog(@"Default output card: `%@` selected `%@`",
        [[server defaultOutput] cardDescription],
        [[deviceCardBtn selectedItem] title]);
  
  if ([[[modeButton selectedItem] title] isEqualToString:@"Playback"] != NO) {
    SKSoundOut *defOut = [server defaultOutput];
    if (defOut != nil) {
      [deviceCardBtn selectItemWithTitle:[defOut cardDescription]];
    }
    else if ([[deviceCardBtn selectedItem] title] == nil) {
      [deviceCardBtn selectItemAtIndex:0];
    }
    else {
      [deviceCardBtn selectItemWithTitle:[[deviceCardBtn selectedItem] title]];
    }
  }
  else {
    SKSoundIn *defIn = [server defaultInput];
    if (defIn != nil) {
      [deviceCardBtn selectItemWithTitle:[defIn cardDescription]];
    }
    else if ([[deviceCardBtn selectedItem] title] == nil) {
      [deviceCardBtn selectItemAtIndex:0];
    }
    else {
      [deviceCardBtn selectItemWithTitle:[[deviceCardBtn selectedItem] title]];
    }
  }
  
  [self fillProfileList];
}
- (void)fillProfileList
{
  SKSoundDevice *device = [[deviceCardBtn selectedItem] representedObject];
  NSString      *title;
  
  [deviceProfileBtn removeAllItems];
  
  for (NSDictionary *profile in [device availableProfiles]) {
    title = profile[@"Description"];
    [deviceProfileBtn addItemWithTitle:title];
    [[deviceProfileBtn itemWithTitle:title] setRepresentedObject:device];
  }
  [deviceProfileBtn selectItemWithTitle:[device activeProfile]];
  
  [self fillPortList];
}
- (void)fillPortList
{
  NSString      *title;
  SKSoundServer *server = [SKSoundServer sharedServer];
  NSArray       *deviceList;
  BOOL          isPlayback;

  isPlayback = [[[modeButton selectedItem] title] isEqualToString:@"Playback"];

  [devicePortBtn removeAllItems];

  if (isPlayback) {
    deviceList = [server outputList];
  }
  else {
    deviceList = [server inputList];
  }
    
  for (SKSoundDevice *device in deviceList) {
    NSLog(@"Device: %@", device.description);
    
    for (NSDictionary *port in [device availablePorts]) {
      title = port[@"Description"];
      [devicePortBtn addItemWithTitle:title];
      [[devicePortBtn itemWithTitle:title] setRepresentedObject:device];
    }
    
    // KVO for added output
    [self observeDevice:device];
  }
  
  if (isPlayback) {
    SKSoundOut *output;
    if ([devicePortBtn numberOfItems] > 1 &&
        (output = [server defaultOutput]) != nil) {
      [devicePortBtn selectItemWithTitle:[output activePort]];
      if ([output activePort] != nil) {
        [devicePortBtn selectItemWithTitle:[output activePort]];
      }
      else {
        [devicePortBtn selectItemAtIndex:0];
      }
    }
  }
  else {
    SKSoundIn *input;
    if ([devicePortBtn numberOfItems] > 1 &&
        (input = [server defaultInput]) != nil) {
      if ([input activePort] != nil) {
        [devicePortBtn selectItemWithTitle:[input activePort]];
      }
      else {
        [devicePortBtn selectItemAtIndex:0];
      }
    }
  }

  if ([devicePortBtn numberOfItems] == 0) {
    [deviceMuteBtn setEnabled:NO];
    [devicePortBtn setEnabled:NO];
    [deviceVolumeSlider setEnabled:NO];
    [deviceBalanceSlider setEnabled:NO];
  }
  else {
    [deviceMuteBtn setEnabled:YES];
    [devicePortBtn setEnabled:YES];
    [deviceVolumeSlider setEnabled:YES];
    [deviceBalanceSlider setEnabled:YES];
  }
    
  NSLog(@"Device port selected item: %@ - %@",
        [[[[devicePortBtn selectedItem] representedObject] class] description],
        [[devicePortBtn selectedItem] title]);
  
  [self setDevicePort:devicePortBtn];
}

// --- Key-Value Observing
- (void)observeDevice:(SKSoundDevice *)device
{
  if ([device isKindOfClass:[SKSoundOut class]]) {
    SKSoundOut *output = (SKSoundOut *)device;
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
  else if ([device isKindOfClass:[SKSoundIn class]]) {
    SKSoundIn *input = (SKSoundIn *)device;
    [input.source addObserver:self
                   forKeyPath:@"mute"
                      options:NSKeyValueObservingOptionNew
                      context:InputContext];
    [input.source addObserver:self
                   forKeyPath:@"activePort"
                      options:NSKeyValueObservingOptionNew
                      context:InputContext];
    [input.card addObserver:self
                 forKeyPath:@"activeProfile"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
    [input.source addObserver:self
                   forKeyPath:@"channelVolumes"
                      options:NSKeyValueObservingOptionNew
                      context:InputContext];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SKSoundOut *output;
  SKSoundIn  *input;
  
  if (context == OutputContext) {
    output = [[devicePortBtn selectedItem] representedObject];
    if (object == output.sink) {
      NSLog(@"SoundOut received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [deviceMuteBtn setState:[output isMute]];
      }
      else if ([keyPath isEqualToString:@"activePort"]) {
        NSString *title = [[devicePortBtn selectedItem] title];
        if ([output.activePort isEqualToString:title] == NO) {
          [devicePortBtn selectItemWithTitle:output.activePort];
        }
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [deviceVolumeSlider setIntegerValue:[output volume]];
        [deviceBalanceSlider setFloatValue:[output balance]];
      }
    }
    else if (object == output.card) {
      if ([keyPath isEqualToString:@"activeProfile"]) {
        [deviceProfileBtn selectItemWithTitle:output.activeProfile];
      }
    }
  }
  else if (context == InputContext) {
    input = [[devicePortBtn selectedItem] representedObject];
    if (object == input.source) {
      NSLog(@"SoundIn received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [deviceMuteBtn setState:[input isMute]];
      }
      else if ([keyPath isEqualToString:@"activePort"]) {
        NSString *title = [[devicePortBtn selectedItem] title];
        if ([input.activePort isEqualToString:title] == NO) {
          [devicePortBtn selectItemWithTitle:input.activePort];
        }
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [deviceVolumeSlider setIntegerValue:[input volume]];
        [deviceBalanceSlider setFloatValue:[input balance]];
      }
    }
    else if (object == input.card) {
      if ([keyPath isEqualToString:@"activeProfile"]) {
        [deviceProfileBtn selectItemWithTitle:input.activeProfile];
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
    [self fillCardList];
  }
  else if ([title isEqualToString:@"Recording"]) {
    [deviceBox setTitle:@"Input"];
    [self fillCardList];
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
- (void)setDeviceCard:(id)sender
{
  SKSoundDevice *device = [[sender selectedItem] representedObject];

  if ([[device availablePorts] count] > 0) {
    [device setActivePort:[[sender selectedItem] title]];
  }
  [deviceMuteBtn setState:[device isMute]];
  [deviceVolumeSlider setMaxValue:[device volumeSteps]-1];
  [deviceVolumeSlider setIntegerValue:[device volume]];
  [deviceBalanceSlider setFloatValue:[device balance]];
  
  [self fillProfileList];
}
- (void)setDeviceProfile:(id)sender
{
  SKSoundDevice *device = [[deviceProfileBtn selectedItem] representedObject];

  [device setActiveProfile:[[deviceProfileBtn selectedItem] title]];
  [self fillPortList];
}
- (void)setDevicePort:(id)sender
{
  SKSoundDevice *device = [[sender selectedItem] representedObject];

  if ([[device availablePorts] count] > 0) {
    [device setActivePort:[[sender selectedItem] title]];
  }
  [deviceMuteBtn setState:[device isMute]];
  [deviceVolumeSlider setMaxValue:[device volumeSteps]-1];
  [deviceVolumeSlider setIntegerValue:[device volume]];
  [deviceBalanceSlider setFloatValue:[device balance]];
}

- (void)setDeviceMute:(id)sender
{
  [[[devicePortBtn selectedItem] representedObject] setMute:[sender state]];
}

- (void)setDeviceVolume:(id)sender
{
  SKSoundDevice *device = [[devicePortBtn selectedItem] representedObject];

  NSLog(@"Device: set volume to %li (old: %lu)",
        [deviceVolumeSlider integerValue], [device volume]);
  
  [device setVolume:[deviceVolumeSlider integerValue]];
  
  NSLog(@"Output: volume was set to %lu", [device volume]);
}

- (void)setDeviceBalance:(id)sender
{
  SKSoundDevice *device = [[devicePortBtn selectedItem] representedObject];
  
  NSLog(@"Device: set balance: %@", [device className]);
  [device setBalance:[deviceBalanceSlider floatValue]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

@end
