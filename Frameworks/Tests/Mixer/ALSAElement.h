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

#import <alsa/asoundlib.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class ALSACard;

@interface ALSAElement : NSObject
{
  // Playback
  id playbackWindow;
  id pMuteButton;
  id playbackBox;
  id pVolumeField;
  id pVolumeSlider;
  id pBalanceSlider;
  id pVolumeRight;
  id pVolumeLeft;

  // Capture
  id captureWindow;
  id captureBox;
  id cMuteButton;
  id cVolumeField;
  id cVolumeSlider;
  id cVolumeLeft;
  id cVolumeRight;
  id cBalanceSlider;

  // Option
  id optionBox;
  id optionValues;
  id optionWindow;
  
  NSWindow	*window;
  NSBox 	*box;
  NSTextField	*volumeField;
  NSTextField	*volumeLeft;
  NSTextField	*volumeRight;
  NSSlider	*volumeSlider;
  NSSlider	*balanceSlider;
  NSButton	*muteButton;

  ALSACard      *alsaCard;

  // ALSA
  snd_mixer_t		*mixer;
  snd_mixer_elem_t	*element;
  snd_mixer_selem_id_t	*elem_id;
  char			*elem_name;
  long			volume_min;
  long			volume_max;
  long			volume_left;
  long			volume_right;
  struct {
    int is_active;
    int has_common_volume;
    int has_common_switch;
    //Playback
    int is_playback_mono;
    int has_playback_volume;
    int has_playback_volume_joined;
    int has_playback_switch;
    int has_playback_switch_joined;
    // Capture
    int is_capture_mono;
    int has_capture_volume;
    int has_capture_volume_joined;
    int has_capture_switch;
    int has_capture_switch_joined;
    int has_capture_switch_exclusive;
    // Option
    int is_enumerated;
  } flags;
}

- initWithCard:(ALSACard *)card element:(snd_mixer_elem_t *)elem;
- (NSBox *)view;
- (BOOL)isPlayback;
- (BOOL)isCapture;
- (BOOL)isOption;
- (void)refresh;

@end
