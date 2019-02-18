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

#import "ALSA.h"
#import "PulseAudio.h"
#import "SoundKitClient.h"
#import "AppController.h"

@implementation AppController

- (void)dealloc
{
  [alsaPanel release];
  [paPanel release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
}

- (BOOL)applicationShouldTerminate:(id)sender
{
  if (alsaPanel) {
    [alsaPanel release];
  }
  if (paPanel) {
    [[paPanel window] close];
    [paPanel release];
  }
  if (soundClient) {
    [soundClient release];
  }
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

// --- Menu actions

- (void)openALSAPanel:(id)sender
{
  if (alsaPanel) {
    [alsaPanel release];
  }
  
  alsaPanel = [[ALSA alloc] init];
  if ([alsaPanel respondsToSelector:@selector(showPanel)]) {
    [alsaPanel showPanel];
  }
}

- (void)openPulseAudioPanel:(id)sender
{
  // if (paPanel) {
  //   [paPanel release];
  // }
  // paPanel = [[PulseAudio alloc] init];
}

- (void)testSoundKit:(id)sender
{
  if (soundClient) {
    [soundClient release];
  }
  soundClient = [[SoundKitClient alloc] init];
}

@end
