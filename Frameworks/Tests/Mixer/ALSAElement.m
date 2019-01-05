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
#import <X11/Xlib.h>

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
  [muteButton setRefusesFirstResponder:YES];

  [self refresh];
}

- (NSBox *)view
{
  return box;
}

- (BOOL)isPlayback
{
  return !flags.has_capture_volume;
}

- (void)handleEvents
{
  int            poll_count, fill_count;
  struct pollfd  *polls;
  unsigned short revents;

  poll_count = snd_mixer_poll_descriptors_count(mixer);
  if (poll_count <= 0)
    NSLog(@"Cannot obtain mixer poll descriptors.");

  polls = alloca((poll_count + 1) * sizeof (struct pollfd));
  fill_count = snd_mixer_poll_descriptors(mixer, polls, poll_count);
  NSAssert(poll_count = fill_count, @"poll counts differ");

  poll(polls, fill_count + 1, 5);

  /* Ensure that changes made via other programs (alsamixer, etc.) get
     reflected as well.  */
  snd_mixer_poll_descriptors_revents(mixer, polls, poll_count, &revents);
  if (revents & POLLIN)
    snd_mixer_handle_events(mixer);  
}

- (void)refresh
{
  [self handleEvents];
  
  snd_mixer_selem_get_playback_volume_range(element,
                                            &playback_volume_min,
                                            &playback_volume_max);
  [volumeSlider setMinValue:(double)playback_volume_min];
  [volumeSlider setMaxValue:(double)playback_volume_max];

  if (flags.has_playback_switch) {
    int play;
    snd_mixer_selem_get_playback_switch(element, SND_MIXER_SCHN_FRONT_LEFT, &play);
    [muteButton setState:!play];
  }
  
  // if ([muteButton state] == NSOffState) {
    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
      snd_mixer_selem_get_playback_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                          &playback_volume_left);
      [volumeSlider setIntValue:playback_volume_left];
      [volumeLeft setIntValue:playback_volume_left];
      [volumeRight setIntValue:playback_volume_left];
    }
    if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
      snd_mixer_selem_get_playback_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                          &playback_volume_right);
      [volumeRight setIntValue:playback_volume_right];
    }
    
    if (flags.is_playback_mono == 1) {
      [balanceSlider retain];
      [balanceSlider removeFromSuperview];
      [balanceSlider setIntValue:1];
      [balanceSlider setEnabled:NO];
      [volumeLeft setStringValue:@""];
      [volumeRight setStringValue:@""];
    }
    else {
      [balanceSlider setIntValue:1];
      if (playback_volume_right != playback_volume_left) {
        CGFloat vol_r = (CGFloat)playback_volume_right;
        CGFloat vol_l = (CGFloat)playback_volume_left;
        CGFloat vol_max = (playback_volume_right > playback_volume_left) ? vol_r : vol_l;
        
        [balanceSlider setFloatValue:(1.0 - ((vol_r - vol_l) / vol_max))];
      }
    }
    
    [volumeField setIntValue:(playback_volume_left > playback_volume_right ?
                              playback_volume_left : playback_volume_right)];
  // }

  NSLog(@"Control `%s` min=%li (%.0f), max=%li(%.0f)", elem_name,
        playback_volume_min, [volumeSlider minValue],
        playback_volume_max, [volumeSlider maxValue]);
}

- (void)setVolume:(id)sender
{
  int     volume = [sender intValue];
  CGFloat balance = [balanceSlider floatValue];
  
  [volumeField setIntValue:volume];

  if (balance < 1) {
    // playback_volume_right = volume - (volume_max - balance_volume);
    playback_volume_right = volume * balance;
    playback_volume_left = volume;
  }
  else if (balance > 1) {
    // playback_volume_left = volume - (balance_volume - volume_max);
    playback_volume_left = volume * (2 - balance);
    playback_volume_right = volume;
  }
  else {
    playback_volume_left = playback_volume_right = volume;
  }

  if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_LEFT)) {
    snd_mixer_selem_set_playback_volume(element, SND_MIXER_SCHN_FRONT_LEFT,
                                        playback_volume_left);
    [volumeLeft setIntValue:playback_volume_left];
    [volumeRight setIntValue:playback_volume_right];
  }
  if (snd_mixer_selem_has_playback_channel(element, SND_MIXER_SCHN_FRONT_RIGHT)) {
    snd_mixer_selem_set_playback_volume(element, SND_MIXER_SCHN_FRONT_RIGHT,
                                        playback_volume_right);
  }
  else {
    [volumeLeft setStringValue:@""];
    [volumeRight setStringValue:@""];
  }
    
  [volumeField setIntValue:volume];
  fprintf(stderr, "`%s` left:%li right:%li balance:%.1f\n",
          elem_name, playback_volume_left, playback_volume_right, balance);
}

- (void)setBalance:(id)sender
{
  [self setVolume:volumeSlider];
}

- (void)setMute:(id)sender
{
  if (flags.has_playback_switch) {
    snd_mixer_selem_set_playback_switch_all(element, ![sender state]);
  }
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

@end
