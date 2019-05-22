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
static void *StreamPlayContext = &StreamPlayContext;
static void *StreamRecordContext = &StreamRecordContext;
static void *StreamVirtualContext = &StreamVirtualContext;

enum {
  PlaybackMode,
  RecordingMode
};

@implementation Mixer (Private)
- (NSImage *)imageNamed:(NSString *)name
{
  NSBundle *bundle = [NSBundle bundleForClass:[Mixer class]];
  NSString *imagePath;
  NSImage  *image;

  imagePath = [bundle pathForResource:name
                               ofType:@"tiff"
                          inDirectory:@"Resources"];
  NSLog(@"Path for image `%@` - %@", name, imagePath);
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
  
  return [image autorelease];
}  
@end

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
    if ([[device availablePorts] count] == 0) {
      [devicePortBtn addItemWithTitle:device.name];
      [[devicePortBtn itemWithTitle:device.name] setRepresentedObject:device];
    }
    else {
      for (NSDictionary *port in [device availablePorts]) {
        title = [NSString stringWithFormat:@"%@",
                        [port objectForKey:@"Description"]];
        [devicePortBtn addItemWithTitle:title];
        [[devicePortBtn itemWithTitle:title] setRepresentedObject:device];
      }
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
- (void)startObserveStream:(SNDStream *)stream
{
  if ([stream isKindOfClass:[SNDVirtualStream class]]) {
    SNDVirtualStream *st = (SNDVirtualStream *)stream;
    [st.stream addObserver:self
                forKeyPath:@"mute"
                   options:NSKeyValueObservingOptionNew
                   context:StreamVirtualContext];
    [st.stream addObserver:self
                forKeyPath:@"volume"
                   options:NSKeyValueObservingOptionNew
                   context:StreamVirtualContext];
  }
  else if ([stream isKindOfClass:[SNDPlayStream class]]) {
    SNDPlayStream *st = (SNDPlayStream *)stream;
    [st.sinkInput addObserver:self
                   forKeyPath:@"mute"
                      options:NSKeyValueObservingOptionNew
                      context:StreamPlayContext];
    [st.sinkInput addObserver:self
                   forKeyPath:@"channelVolumes"
                      options:NSKeyValueObservingOptionNew
                      context:StreamPlayContext];
  }
  else if ([stream isKindOfClass:[SNDRecordStream class]]) {
    SNDRecordStream *st = (SNDRecordStream *)stream;
    [st.sourceOutput addObserver:self
                      forKeyPath:@"mute"
                         options:NSKeyValueObservingOptionNew
                         context:StreamRecordContext];
    [st.sourceOutput addObserver:self
                      forKeyPath:@"channelVolumes"
                         options:NSKeyValueObservingOptionNew
                         context:StreamRecordContext];
  }
}
- (void)stopObserveStream:(SNDStream *)stream
{
  if ([stream isKindOfClass:[SNDVirtualStream class]]) {
    SNDVirtualStream *st = (SNDVirtualStream *)stream;
    [st.stream removeObserver:self forKeyPath:@"mute"];
    [st.stream removeObserver:self forKeyPath:@"volume"];
  }
  else if ([stream isKindOfClass:[SNDPlayStream class]]) {
    SNDPlayStream *st = (SNDPlayStream *)stream;
    [st.sinkInput removeObserver:self forKeyPath:@"mute"];
    [st.sinkInput removeObserver:self forKeyPath:@"channelVolumes"];
  }
  else if ([stream isKindOfClass:[SNDRecordStream class]]) {
    SNDRecordStream *st = (SNDRecordStream *)stream;
    [st.sourceOutput removeObserver:self forKeyPath:@"mute"];
    [st.sourceOutput removeObserver:self forKeyPath:@"channelVolumes"];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SNDOut    *output;
  SNDIn     *input;
  
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
  }
  else if (context == StreamVirtualContext) {
    SNDVirtualStream *virtualStream;
    virtualStream = [[appBrowser selectedCellInColumn:0] representedObject];
    if (object == virtualStream.stream) {
      if ([keyPath isEqualToString:@"mute"]) {
        NSLog(@"VirtualStream changed mute attribute.");
        [self browserClick:appBrowser];
      }
      else if ([keyPath isEqualToString:@"volume"]) {
        NSLog(@"VirtualStream changed it's volume.");
        [self browserClick:appBrowser];
      }
    }
  }
  else if (context == StreamPlayContext) {
    SNDPlayStream *playStream;
    playStream = [[appBrowser selectedCellInColumn:0] representedObject];
    if (object == playStream.sinkInput) {
      if ([keyPath isEqualToString:@"mute"]) {
        NSLog(@"PlayStream changed mute attribute.");
        [self browserClick:appBrowser];
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        NSLog(@"PlayStream changed it's volume.");
        [self browserClick:appBrowser];
      }
    }
  }
  else if (context == StreamRecordContext) {
    SNDRecordStream *recordStream;
    recordStream = [[appBrowser selectedCellInColumn:0] representedObject];
    if (object == recordStream.sourceOutput) {
      if ([keyPath isEqualToString:@"mute"]) {
        NSLog(@"RecordStream changed mute attribute.");
        [self browserClick:appBrowser];
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        NSLog(@"RecordStream changed it's volume.");
        [self browserClick:appBrowser];
      }
    }
  }
  else {
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
    [appVolumeMuteImg setImage:[self imageNamed:@"volMute"]];
    [appVolumeLoudImg setImage:[self imageNamed:@"volLoud"]];
    [deviceVolumeMuteImg setImage:[self imageNamed:@"volMute"]];
    [deviceVolumeLoudImg setImage:[self imageNamed:@"volLoud"]];
 }
  else if ([[sender selectedItem] tag] == RecordingMode) {
    [deviceBox setTitle:@"Input"];
    [appVolumeMuteImg setImage:[self imageNamed:@"micMute"]];
    [appVolumeLoudImg setImage:[self imageNamed:@"micLoud"]];
    [deviceVolumeMuteImg setImage:[self imageNamed:@"micMute"]];
    [deviceVolumeLoudImg setImage:[self imageNamed:@"micLoud"]];
  }
  [self updateDeviceList];
  [self reloadBrowser:appBrowser];
}

// --- Streams actions
- (void)reloadBrowser:(NSBrowser *)browser
{
  NSString *selected = [[appBrowser selectedCellInColumn:0] title];

  [appBrowser reloadColumn:0];
  [appBrowser setTitle:@"Streams" ofColumn:0];

  if ([[appBrowser matrixInColumn:0] numberOfRows] > 0 && selected == nil) {
    [appBrowser selectRow:0 inColumn:0];
  }
  [self browserClick:appBrowser];
}
 
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  NSArray       *streamList = [[SNDServer sharedServer] streamList];

  if ([[modeButton selectedItem] tag] == PlaybackMode) {
    for (SNDStream *st in streamList) {
      if ([st isKindOfClass:[SNDPlayStream class]] ||
          ([st isKindOfClass:[SNDVirtualStream class]] &&
           st.isActive != NO && st.isPlayback != NO)) {
        [matrix addRow];
        cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
        [cell setLeaf:YES];
        [cell setRefusesFirstResponder:YES];
        [cell setTitle:st.name];
        [cell setRepresentedObject:st];
        // NSLog(@"Browser add %@: %@", [st className], st.name);
      }
    }
  }
  else if ([[modeButton selectedItem] tag] == RecordingMode) {
    for (SNDStream *st in streamList) {
      if ([st isKindOfClass:[SNDRecordStream class]] ||
          ([st isKindOfClass:[SNDVirtualStream class]] &&
           st.isActive != NO && st.isPlayback == NO)) {
        [matrix addRow];
        cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
        [cell setLeaf:YES];
        [cell setRefusesFirstResponder:YES];
        [cell setTitle:st.name];
        [cell setRepresentedObject:st];
        // NSLog(@"Browser add %@: %@", [st className], st.name);
      }
    }
  }
}

- (void)browserClick:(id)sender
{
  SNDStream *stream = [[sender selectedCellInColumn:0] representedObject];
  SNDServer *server;
  NSString  *activePort;

  // NSLog(@"Browser received click: %@, cell - %@, repObject - %@, volume - %lu",
  //       [sender className], [[sender selectedCellInColumn:0] title],
  //       [stream className], [stream volume]);

  if (selectedApp != stream) {
    if (selectedApp != nil) {
      [self stopObserveStream:selectedApp];
    }
    [self startObserveStream:stream];
    selectedApp = stream;
  }
  
  if (stream != nil) {
    [appMuteBtn setEnabled:YES];
    [appVolumeMuteImg setEnabled:YES];
    [appVolumeLoudImg setEnabled:YES];
    [appVolumeSlider setEnabled:YES];
    [appVolumeSlider setIntegerValue:[stream volume]];
    [appMuteBtn setState:[stream isMute]];
    activePort = [stream activePort];
  }
  else {
    [appVolumeMuteImg setEnabled:NO];
    [appVolumeLoudImg setEnabled:NO];
    [appVolumeSlider setIntegerValue:0];
    [appVolumeSlider setEnabled:NO];
    [appMuteBtn setState:NSOffState];
    [appMuteBtn setEnabled:NO];
    
    server = [SNDServer sharedServer];
    if ([[modeButton selectedItem] tag] == PlaybackMode)
      activePort = [[server defaultOutput] activePort];
    else
      activePort = [[server defaultInput] activePort];
  }
  
  if (activePort != nil) {
    [devicePortBtn selectItemWithTitle:activePort];
  }
  
  [self updateProfileList];
  [self updateDeviceControls];
}

- (void)appMuteClick:(id)sender
{
  [[[appBrowser selectedCellInColumn:0] representedObject] setMute:[sender state]];
}

- (void)setAppVolume:(id)sender
{
  SNDStream *stream = [[appBrowser selectedCellInColumn:0] representedObject];

  NSLog(@"setAppVolume: sender %@ stream: %@",
        [sender className], [stream className]);

  [stream setVolume:[sender integerValue]];
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
