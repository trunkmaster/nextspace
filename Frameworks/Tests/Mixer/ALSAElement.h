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

@interface ALSAElement : NSObject
{
  NSWindow	*window;
  NSBox 	*box;
  NSTextField	*volumeField;
  NSTextField	*volumeLeft;
  NSTextField	*volumeRight;
  NSSlider	*volumeSlider;
  NSSlider	*balanceSlider;
  NSButton	*muteButton;

  // ALSA
  snd_mixer_t		*mixer;
  snd_mixer_elem_t	*element;
  snd_mixer_selem_id_t	*elem_id;
  char			*elem_name;
  long			playback_volume_min;
  long			playback_volume_max;
  long			playback_volume;
  long			playback_volume_left;
  long			playback_volume_right;
  long			capture_volume;
  struct {
    int is_active;
    int has_common_volume;
    int has_common_switch;
    //Playback
    int is_playback_mono;
    int has_playback_switch;
    int has_playback_switch_joined;
    int has_playback_volume;
    int has_playback_volume_joined;
    // Capture
    int is_capture_mono;
    int has_capture_volume;
    int has_capture_volume_joined;
    int has_capture_switch;
    int has_capture_switch_joined;
    int has_capture_switch_exclusive;
  } flags;
}

- initWithElement:(snd_mixer_elem_t *)elem mixer:(snd_mixer_t *)mix;
- (NSBox *)view;
- (BOOL)isPlayback;
- (void)refresh;

@end
