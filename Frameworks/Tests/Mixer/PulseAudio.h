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

#import <AppKit/AppKit.h>

#import <pulse/pulseaudio.h>

@interface PulseAudio : NSObject
{
  id window;
  id serverInfo;
  id cardInfo;
  
  id streamsBrowser;
  id sreamMute;
  id streamVolume;
  
  id devicesBrowser;
  id deviceMute;

  NSString       *defaultSinkName;
  NSString       *defaultSourceName;
  NSMutableArray *clientList;
  NSMutableArray *streamList; // sink-input* or source-output*
  NSMutableArray *cardList;
  NSMutableArray *sinkList;
  NSMutableArray *sinkInputList;
  NSMutableArray *sourceList;
  NSMutableArray *sourceOutputList;
  
  // Define our pulse audio loop and connection variables
  pa_mainloop     *pa_loop;
  pa_mainloop_api *pa_api;

  // Objects Map
  id omWindow;
  id streamsPUB;
  id clientsPUB;
  id sinkInputsPUB;
  id sinkPUB;
  id cardPUB;
  id portsPUB;
  id profilesPUB;

  // Advanced Sound Preferences
  id modeButton;
  id appBrowser;
  id appMute;
  id appVolume;
  id outputMute;
  id outputDevice;
  id outputDeviceProfile;
  id outputVolume;
  id outputBalance;
}

// TODO
- (void)updateServer:(NSValue *)value;
- (void)updateCard:(NSValue *)value;
- (void)removeCardWithIndex:(NSNumber *)index;


- (void)updateClient:(NSValue *)value;
- (void)removeClientWithIndex:(NSNumber *)index;

- (void)updateStream:(NSValue *)value;

- (void)updateSink:(NSString *)sink;
- (void)removeSinkWithIndex:(NSNumber *)index;

- (void)updateSinkInput:(NSString *)sink;
- (void)removeSinkInputWithIndex:(NSNumber *)index;

// TODO
- (void)updateSource:(NSValue *)value;
- (void)removeSourceWithIndex:(NSNumber *)index;

- (void)updateSourceOutput:(NSValue *)value;
- (void)removeSourceOutputWithIndex:(NSNumber *)index;

- (void)reloadBrowser:(NSBrowser *)browser;
- (void)updateOutputDeviceList;
- (void)updateOutputProfileList:(NSPopUpButton *)button;

@end
