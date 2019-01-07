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

#import "ALSACard.h"
#import "ALSAElement.h"
#import <X11/Xlib.h>

@implementation ALSAElement

- initWithCard:(ALSACard *)card
       element:(snd_mixer_elem_t *)elem
{
  [super init];

  alsaCard = card;
  mixer = [card mixer];
  element = elem;
  
  snd_mixer_selem_id_alloca(&elem_id);
  snd_mixer_selem_get_id(element, elem_id);

  // General
  elem_name = strdup(snd_mixer_selem_id_get_name(elem_id));
  flags.is_active = snd_mixer_selem_is_active(element);
  flags.has_common_volume = snd_mixer_selem_has_common_volume(element);
  flags.has_common_switch = snd_mixer_selem_has_common_switch(element);
  // Playback
  flags.is_playback_mono = snd_mixer_selem_is_playback_mono(element);
  flags.has_playback_switch = snd_mixer_selem_has_playback_switch(element);
  flags.has_playback_switch_joined = snd_mixer_selem_has_playback_switch_joined(element);
  flags.has_playback_volume = snd_mixer_selem_has_playback_volume(element);
  flags.has_playback_volume_joined = snd_mixer_selem_has_playback_volume_joined(element);
  // Capture
  flags.is_capture_mono = snd_mixer_selem_is_capture_mono(element);
  flags.has_capture_volume = snd_mixer_selem_has_capture_volume(element);
  flags.has_capture_volume_joined = snd_mixer_selem_has_capture_volume_joined(element);
  flags.has_capture_switch = snd_mixer_selem_has_capture_switch(element);
  flags.has_capture_switch_joined = snd_mixer_selem_has_capture_switch_joined(element);
  flags.has_capture_switch_exclusive = snd_mixer_selem_has_capture_switch_exclusive(element);

  fprintf(stderr, "\t %s (", elem_name);
  fprintf(stderr, " is_active: %i", flags.is_active);
  fprintf(stderr, " has_common_volume: %i", flags.has_common_volume);
  fprintf(stderr, " has_common_switch: %i", flags.has_common_switch);
  fprintf(stderr, " is_playback_mono: %i", flags.is_playback_mono);
  fprintf(stderr, " has_playback_switch: %i", flags.has_playback_switch);
  fprintf(stderr, " has_playback_switch_joined: %i", flags.has_playback_switch_joined);
  fprintf(stderr, " has_playback_volume: %i", flags.has_playback_volume);
  fprintf(stderr, " has_playback_volume_joined: %i", flags.has_playback_volume_joined);
  fprintf(stderr, ")\n");
  
  [NSBundle loadNibNamed:@"ALSAElement" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [box retain];
  [box removeFromSuperview];
  [window release];

  [box setTitle:[NSString stringWithCString:elem_name]];
  [muteButton setRefusesFirstResponder:YES];

  if (flags.has_playback_volume) {
    // Set min/max values for volume slider
    snd_mixer_selem_get_playback_volume_range(element, &volume_min, &volume_max);
  }
  else if (flags.has_capture_volume) {
    snd_mixer_selem_get_capture_volume_range(element, &volume_min, &volume_max);
  }
  
  [volumeSlider setMinValue:(double)volume_min];
  [volumeSlider setMaxValue:(double)volume_max];

  if ((!flags.has_playback_volume && !flags.has_capture_volume) || volume_max == 0) {
    // [volumeSlider retain];
    [volumeSlider removeFromSuperview];
  }
  
  // Remove balance slider if element is mono
  if ((flags.is_playback_mono == 1 && flags.has_playback_volume) ||
      (flags.is_capture_mono == 1 && flags.has_capture_volume) ||
      volume_max == 0) {
    // [balanceSlider retain];
    [balanceSlider removeFromSuperview];
    [volumeLeft setStringValue:@""];
    [volumeRight setStringValue:@""];
  }

  [self refresh];
}

- (NSBox *)view
{
  return box;
}

- (BOOL)isPlayback
{
  return flags.has_playback_volume && !flags.has_capture_volume;
}

- (BOOL)isCapture
{
  return flags.has_capture_volume;
}

- (BOOL)isOption
{
  if (snd_mixer_selem_is_enumerated(element)) {
    char buf[64];
    unsigned idx;
    
    snd_mixer_selem_get_enum_item(element, SND_MIXER_SCHN_FRONT_LEFT, &idx);
    snd_mixer_selem_get_enum_item_name(element, idx, sizeof(buf) - 1, buf);
    fprintf(stderr, "Element `%s` is enumerated, playback=%i, capture=%i Value: %s\n",
            elem_name,
            snd_mixer_selem_is_enum_playback(element),
            snd_mixer_selem_is_enum_capture(element),
            buf);
  }
  return (!flags.has_playback_volume &&
          !flags.has_capture_volume &&
          snd_mixer_selem_is_enumerated(element));
}

- (void)refresh
{
  if (flags.has_playback_volume) {
    // Mute button
    if (flags.has_playback_switch) {
      int play;
      snd_mixer_selem_get_playback_switch(element, SND_MIXER_SCHN_FRONT_LEFT, &play);
      [muteButton setState:!play];
    }

    // Volume slider and text field
    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
      snd_mixer_selem_get_playback_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                          &volume_left);
      if (!flags.is_playback_mono)
        [volumeLeft setIntValue:volume_left];
    }
    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
      snd_mixer_selem_get_playback_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                          &volume_right);
      if (!flags.is_playback_mono)
        [volumeRight setIntValue:volume_right];
    }
    [volumeSlider setIntValue:(volume_left > volume_right ?
                               volume_left : volume_right)];
    [volumeField setIntValue:(volume_left > volume_right ?
                              volume_left : volume_right)];

    // Balance slider and text fields
    if (flags.is_playback_mono == 0 && volume_right != volume_left) {
      CGFloat vol_r = (CGFloat)volume_right;
      CGFloat vol_l = (CGFloat)volume_left;
      CGFloat vol_max = (volume_right > volume_left) ? vol_r : vol_l;
        
      [balanceSlider setFloatValue:(1.0 - ((vol_l - vol_r) / vol_max))];
    }
  }
  else if (flags.has_capture_volume) {
    // Mute button
    if (flags.has_capture_switch) {
      int play;
      snd_mixer_selem_get_capture_switch(element, SND_MIXER_SCHN_FRONT_LEFT, &play);
      [muteButton setState:!play];
    }

    // Volume slider and text field
    if (snd_mixer_selem_has_capture_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
      snd_mixer_selem_get_capture_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                         &volume_left);
      if (!flags.is_capture_mono)
        [volumeLeft setIntValue:volume_left];
    }
    if (snd_mixer_selem_has_capture_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
      snd_mixer_selem_get_capture_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                         &volume_right);
      if (!flags.is_capture_mono)
        [volumeRight setIntValue:volume_right];
    }
    [volumeSlider setIntValue:
                    (volume_left > volume_right ? volume_left : volume_right)];
    [volumeField setIntValue:
                   (volume_left > volume_right ? volume_left : volume_right)];

    // Balance slider and text fields
    if (flags.is_capture_mono == 0 && volume_right != volume_left) {
      CGFloat vol_r = (CGFloat)volume_right;
      CGFloat vol_l = (CGFloat)volume_left;
      CGFloat vol_max = (volume_right > volume_left) ? vol_r : vol_l;
        
      [balanceSlider setFloatValue:(1.0 - ((vol_l - vol_r) / vol_max))];
    }
  }
  
  // NSLog(@"Control `%s` min=%li(%.0f), max=%li(%.0f), is_active=%i", elem_name,
  //       volume_min, [volumeSlider minValue],
  //       volume_max, [volumeSlider maxValue], flags.is_active);
}

- (void)setVolume:(id)sender
{
  int     volume;
  CGFloat balance;

  [alsaCard setShouldHandleEvents:NO];

  volume = [volumeSlider intValue];
  volume_left = volume;
  volume_right = volume;
  
  if (flags.has_playback_volume) {
    if (!flags.is_playback_mono) {
      balance = [balanceSlider floatValue];
  
      if (balance < 1) {
        volume_right = volume * balance;
        volume_left = volume;
      }
      else if (balance > 1) {
        volume_left = volume * (2 - balance);
        volume_right = volume;
      }
    }

    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
      snd_mixer_selem_set_playback_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                          volume_left);
    }
    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
      snd_mixer_selem_set_playback_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                          volume_right);
    }
  }
  else if (flags.has_capture_volume) {
    if (!flags.is_capture_mono) {
      balance = [balanceSlider floatValue];
  
      if (balance < 1) {
        volume_right = volume * balance;
        volume_left = volume;
      }
      else if (balance > 1) {
        volume_left = volume * (2 - balance);
        volume_right = volume;
      }
    }

    if (snd_mixer_selem_has_capture_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
      snd_mixer_selem_set_capture_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                         volume_left);
    }
    if (snd_mixer_selem_has_capture_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
      snd_mixer_selem_set_capture_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                         volume_right);
    }
  }
  
  if (flags.is_playback_mono == 0 && flags.is_capture_mono == 0) {
    [volumeLeft setIntValue:volume_left];
    [volumeRight setIntValue:volume_right];
  }

  if (sender == volumeSlider) {
    [volumeField setIntValue:(volume_left >= volume_right ?
                              volume_left : volume_right)];
  }
  
  // fprintf(stderr, "`%s` left:%li right:%li balance:%.1f\n",
  //         elem_name, volume_left, volume_right, balance);
  
  [alsaCard setShouldHandleEvents:YES];
}

- (void)setBalance:(id)sender
{
  if (flags.is_playback_mono)
    return;
  
  [self setVolume:sender];
}

- (void)setMute:(id)sender
{
  if (flags.has_playback_switch) {
    snd_mixer_selem_set_playback_switch_all(element, ![sender state]);
  }
  
  if (flags.has_capture_switch) {
    snd_mixer_selem_set_capture_switch_all(element, ![sender state]);
  }
}

@end
