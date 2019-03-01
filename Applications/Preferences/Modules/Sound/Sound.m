/*
  Sound preferences bundle

  Author:	Sergii Stoian <stoyan255@gmail.com>
  Date:		2019

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import "Sound.h"

@implementation Sound

static NSBundle                 *bundle = nil;
// static NSUserDefaults           *defaults = nil;
// static NSMutableDictionary      *domain = nil;

// --- Init and dealloc
- (void)dealloc
{
  NSLog(@"Sound -dealloc");
  if (soundServer) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [soundOut release];
    [soundIn release];
    [soundServer disconnect];
    [soundServer release];
  }
  [image release];
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  // defaults = [NSUserDefaults standardUserDefaults];
  // domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Sound" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  // 1. Connect to PulseAudio on locahost
  soundServer = [SKSoundServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SKServerStateDidChangeNotification
         object:soundServer];
  
}

// --- Protocol
- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Sound" owner:self]) {
      NSLog (@"Sound.preferences: Could not load GORM file, aborting.");
      return nil;
    }
  }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Sound Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

// --- Server actions
- (void)_updateControls
{
  if (soundOut) {
    [muteButton setEnabled:YES];
    [volumeLevel setEnabled:YES];
    [volumeBalance setEnabled:YES];
    [muteButton setState:[soundOut isMute]];
    [volumeLevel setIntegerValue:[soundOut volume]];
    [volumeBalance setIntegerValue:[soundOut balance]];
  }
  else {
    [muteButton setEnabled:NO];
    [volumeLevel setEnabled:NO];
    [volumeBalance setEnabled:NO];
  }
  
  if (soundIn) {
    [muteMicButton setEnabled:YES];
    [micLevel setEnabled:YES];
    [micBalance setEnabled:YES];
    [muteMicButton setState:[soundIn isMute]];
    [micLevel setIntegerValue:[soundIn volume]];
    [micBalance setIntegerValue:[soundIn balance]];
  }
  else {
    [muteMicButton setEnabled:NO];
    [micLevel setEnabled:NO];
    [micBalance setEnabled:NO];
  }
}

- (void)serverStateChanged:(NSNotification *)notif
{
  if (soundServer.status == SKServerReadyState) {
    soundOut = [[soundServer defaultOutput] retain];
    soundIn = [[soundServer defaultInput] retain];
    if (soundOut) {
      [volumeLevel setMaxValue:[soundOut volumeSteps]-1];
    }
    if (soundIn) {
      [micLevel setMaxValue:[soundIn volumeSteps]-1];
    }
    [self _updateControls];
  }
  else if (soundServer.status == SKServerFailedState ||
           soundServer.status == SKServerTerminatedState) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [soundServer release];
    soundServer = nil;
  }
}

// --- Control actions
- (void)setMute:(id)sender
{
  SKSoundDevice *device = (sender == muteButton) ? soundOut : soundIn;
  [device setMute:[sender state]];
}
- (void)setVolume:(id)sender
{
  SKSoundDevice *device = (sender == volumeLevel) ? soundOut : soundIn;
  
  [device setVolume:[sender integerValue]];
}
- (void)setBalance:(id)sender
{
  SKSoundDevice *device = (sender == volumeBalance) ? soundOut : soundIn;
  
  [device setBalance:[sender integerValue]];
}

- (void)setBeep:(id)sender {}
- (void)setBeepRadio:(id)sender {}

@end
