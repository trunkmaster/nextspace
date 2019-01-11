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
#import "AppController.h"

@implementation AppController

- (void)dealloc
{
  [audioServer release];
  
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
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

// --- Menu actions

- (void)openALSAPanel:(id)sender
{
  if (audioServer) {
    [audioServer release];
  }
  audioServer = [[ALSA alloc] init];
  if ([audioServer respondsToSelector:@selector(showPanel)]) {
    [audioServer showPanel];
  }
}

- (void)openPulseAudioPanel:(id)sender
{
  if (audioServer) {
    [audioServer release];
  }
  audioServer = [[PulseAudio alloc] init];
  // [audioServer iterate];
}

@end
