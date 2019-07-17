/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <AppKit/NSImage.h>
#import <DesktopKit/NXTDefaults.h>
#import <SoundKit/SoundKit.h>

#import <Preferences.h>

@interface Sound: NSObject <PrefsModule>
{
  NXTDefaults	*defaults;
  NSImage	*image;
  SNDServer	*soundServer;
  SNDOut	*soundOut;
  SNDIn		*soundIn;
  NSString	*defaultSound;
  NSDictionary	*soundsList;
  NSInteger	defSoundRow;
  
  id view;
  id window;
  
  id muteButton;
  id volumeBalance;
  id volumeLevel;
  
  id beepBrowser;
  id beepAudioRadio;
  
  id muteMicButton;
  id micLevel;
  id micBalance;

  id soundInfo;

  id mixer;
}

- (NSDictionary *)loadSoundList;

@end
