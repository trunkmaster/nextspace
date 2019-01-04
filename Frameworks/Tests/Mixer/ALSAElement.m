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

#import "ALSAElement.h"

@implementation ALSAElement

- initWithElement:(snd_mixer_elem_t *)elem mixer:(snd_mixer_t *)mix
{
  [super init];
  
  mixer = mix;
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
  
  // int snd_mixer_selem_has_playback_channel(snd_mixer_elem_t *obj, snd_mixer_selem_channel_id_t channel);
  // int snd_mixer_selem_has_capture_channel(snd_mixer_elem_t *obj, snd_mixer_selem_channel_id_t channel);

  [NSBundle loadNibNamed:@"ALSAElement" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [box retain];
  [box removeFromSuperview];
  [window release];

  [box setTitle:[NSString stringWithCString:elem_name]];
}

- (NSBox *)view
{
  return box;
}

- (void)setTitle:(NSString *)title
{
  [box setTitle:title];
}

- (void)setVolumeTarget:(id)target action:(SEL)action
{
  [volumeSlider setTarget:target];
  [volumeSlider setAction:action];
}
- (void)setBalanceTarget:(id)target action:(SEL)action
{
  [balanceSlider setTarget:target];
  [balanceSlider setAction:action];
}

- (void)setVolumeSliderValue:(NSInteger)vol
{
}

- (void)setBalanceSliderValue:(NSInteger)vol
{
}

- (void)mute
{
}

@end
