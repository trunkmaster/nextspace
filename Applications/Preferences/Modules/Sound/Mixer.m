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

enum {
  PlaybackMode,
  RecordingMode
};

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
  [cardDescription setTextColor:[NSColor darkGrayColor]];
  [window setFrameAutosaveName:@"Mixer"];
  [window makeKeyAndOrderFront:self];
  
  [self reloadBrowser:appBrowser];
  [self updateDeviceList];
}

- (id)window
{
  return window;
}

// Fills "Output/Input" group popups
- (void)updateDeviceList
{
  NSString  *title;
  SNDServer *server = [SNDServer sharedServer];
  NSArray   *deviceList;

  if ([[modeButton selectedItem] tag] == PlaybackMode) {
    NSLog(@"Playback");
    deviceList = [server outputList];
  }
  else {
    NSLog(@"Recording");
    deviceList = [server inputList];
  }
  
  [devicePortBtn removeAllItems];

  for (SNDDevice *device in deviceList) {
    NSLog(@"Device: %@", device.description);
    for (NSDictionary *port in [device availablePorts]) {
      title = [NSString stringWithFormat:@"%@",
                      [port objectForKey:@"Description"]];
      [devicePortBtn addItemWithTitle:title];
      [[devicePortBtn itemWithTitle:title] setRepresentedObject:device];
    }
    if ([devicePortBtn numberOfItems] == 0) {
      [devicePortBtn addItemWithTitle:device.name];
      [[devicePortBtn itemWithTitle:device.name] setRepresentedObject:device];
    }
    // KVO for added output
    if ([[modeButton selectedItem] tag] == PlaybackMode) {
      [self observeOutput:(SNDOut *)device];
    }
    else {
      [self observeInput:(SNDIn *)device];
    }
  }

  if ([[modeButton selectedItem] tag] == PlaybackMode) {
    [devicePortBtn selectItemWithTitle:[[server defaultOutput] activePort]];
  }

  [self updateDeviceControls];
  [self updateProfileList];
    
  NSLog(@"Device port selected item: %@ - %@",
        [[[[devicePortBtn selectedItem] representedObject] class] description],
        [[devicePortBtn selectedItem] title]);

}

- (void)updateProfileList
{
  SNDDevice *device = [[devicePortBtn selectedItem] representedObject];
  
  [deviceProfileBtn removeAllItems];
  if (device) {
    for (NSDictionary *profile in [device availableProfiles]) {
      [deviceProfileBtn addItemWithTitle:profile[@"Description"]];
    }
    [deviceProfileBtn selectItemWithTitle:[device activeProfile]];
  }
}

- (void)updateDeviceControls
{
  SNDDevice *device = [[devicePortBtn selectedItem] representedObject];

  if (device == nil) {
    [deviceMuteBtn setEnabled:NO];
    [devicePortBtn setEnabled:NO];
    [deviceProfileBtn setEnabled:NO];
    [deviceVolumeSlider setEnabled:NO];
    [deviceBalance setEnabled:NO];
    
    [cardDescription setStringValue:@""];
    [deviceMuteBtn setState:NSOffState];
    [deviceVolumeSlider setMaxValue:0];
    [deviceVolumeSlider setIntegerValue:0];
    [deviceBalance setFloatValue:0.0];
  }
  else {
    [deviceMuteBtn setEnabled:YES];
    [devicePortBtn setEnabled:YES];
    [deviceProfileBtn setEnabled:YES];
    [deviceVolumeSlider setEnabled:YES];
    [deviceBalance setEnabled:YES];
    
    [cardDescription setStringValue:[device cardDescription]];
    [deviceMuteBtn setState:[device isMute]];
    [deviceVolumeSlider setMaxValue:[device volumeSteps]-1];
    [deviceVolumeSlider setIntegerValue:[device volume]];
    [deviceBalance setFloatValue:[device balance]];
  }  
}

// --- Key-Value Observing
- (void)observeOutput:(SNDOut *)output
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
- (void)observeInput:(SNDIn *)input
{
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

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SNDOut *output;
  SNDIn  *input;
  
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
        [deviceBalance setFloatValue:[output balance]];
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
        [deviceBalance setFloatValue:[input balance]];
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
  if ([[sender selectedItem] tag] == PlaybackMode) {
    [deviceBox setTitle:@"Output"];
  }
  else if ([[sender selectedItem] tag] == RecordingMode) {
    [deviceBox setTitle:@"Input"];
  }
  [self updateDeviceList];
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
  NSBrowserCell *cell;

  NSLog(@"browser:createRowsForColumn:");
  
  if ([[modeButton selectedItem] tag] == PlaybackMode) {
    for (SNDStream *st in [[SNDServer sharedServer] streamList]) {
      if (st.isActive != NO &&
          ([st isKindOfClass:[SNDPlayStream class]] ||
           [st isKindOfClass:[SNDVirtualStream class]]))
      [matrix addRow];
      cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
      [cell setLeaf:YES];
      [cell setRefusesFirstResponder:YES];
      [cell setTitle:st.name];
      [cell setRepresentedObject:st];
      NSLog(@"Stream: %@", st.name);
    }
  }
  else if ([[modeButton selectedItem] tag] == RecordingMode) {
    // TODO
  }
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
  [[[appBrowser selectedCellInColumn:0] representedObject]
    setMute:[sender state]];
}

// --- Output actions
// "Device" popup action
- (void)setDevicePort:(id)sender
{
  SNDDevice *device = [[sender selectedItem] representedObject];

  if ([[device availablePorts] count] > 0) {
    [device setActivePort:[[sender selectedItem] title]];
  }
  [self updateProfileList];
  [self updateDeviceControls];
}

// "Profile" popup action
- (void)setDeviceProfile:(id)sender
{
  SNDDevice *device = [[devicePortBtn selectedItem] representedObject];

  [device setActiveProfile:[[deviceProfileBtn selectedItem] title]];
}

- (void)setDeviceMute:(id)sender
{
  [[[devicePortBtn selectedItem] representedObject] setMute:[sender state]];
}

- (void)setDeviceVolume:(id)sender
{
  SNDDevice *device = [[devicePortBtn selectedItem] representedObject];

  [device setVolume:[deviceVolumeSlider integerValue]];
}

- (void)setDeviceBalance:(id)sender
{
  SNDDevice *device = [[devicePortBtn selectedItem] representedObject];
  
  NSLog(@"Device: set balance: %@", [device className]);
  [device setBalance:[deviceBalance floatValue]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

@end
