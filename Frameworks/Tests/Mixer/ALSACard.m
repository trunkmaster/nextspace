/*
   Project: TEMP

   Copyright (C) 2019 Free Software Foundation

   Author: Developer

   Created: 2019-01-04 16:35:06 +0200 by me

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
#import "ALSACard.h"

@implementation ALSACard

- (void)dealloc
{
  if (alsa_mixer != NULL)
    [self deleteMixer];

  [cardName release];
  [chipName release];
  [deviceName release];
  if (controls) {
    [controls release];
  }
  
  [super dealloc];
}

- initWithNumber:(int)number
{
  snd_ctl_card_info_t	*info;
  char                  buf[16];
  snd_ctl_t             *ctl;

  [super init];

  NSLog(@"ALSACard: init with number %d", number);

  snd_ctl_card_info_alloca(&info);
  
  sprintf(buf, "hw:%d", number);
  if (snd_ctl_open(&ctl, buf, 0) < 0) {
    return nil;
  }
    
  if (snd_ctl_card_info(ctl, info) < 0) {
    snd_ctl_close(ctl);
    return nil;
  }
    
  card_index = number;
  
  cardName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_name(info)];
  deviceName = [[NSString alloc] initWithFormat:@"hw:%d", number];

  alsa_mixer = [self createMixer];
  chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];

  snd_ctl_close(ctl);
  
  alsa_mixer = [self createMixer];
  if (alsa_mixer) {
    snd_mixer_elem_t *elem;
 
    fprintf(stderr, "Mixer elements for card `%s`:\n", [deviceName cString]);
    controls = [[NSMutableArray alloc] init];
    for (elem = snd_mixer_first_elem(alsa_mixer); elem; elem = snd_mixer_elem_next(elem)) {
      [controls addObject:[[ALSAElement alloc] initWithElement:elem mixer:alsa_mixer]];
    }
  }

  return self;
}

// FIXME: Unused
- (void)fetchDefaultInfo
{
  snd_ctl_card_info_t	*info;
  snd_mixer_t           *mixer;
  snd_ctl_t             *ctl;
  snd_hctl_t            *hctl;
  int                   err = 0;

  snd_ctl_card_info_alloca(&info);
  
  if (snd_ctl_open(&ctl, "default", 0) < 0)
    return;
  if (snd_ctl_card_info(ctl, info) < 0) {
    snd_ctl_close(ctl);
    return;
  }
    
  mixer = [self createMixer];
  deviceName = [[NSString alloc] initWithString:@"default"];

  if (snd_mixer_get_hctl(mixer, [deviceName cString], &hctl) < 0)
    err = -1;
    
  if (err >= 0) {
    ctl = snd_hctl_ctl(hctl);
    err = snd_ctl_card_info(ctl, info);
    if (err >= 0) {
      cardName = [[NSString alloc]initWithCString:snd_ctl_card_info_get_mixername(info)];
      chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];
    }
  }
 [self deleteMixer];
}

- (NSString *)name
{
  return cardName;
}

- (NSString *)chipName
{
  return chipName;
}

- (NSArray *)controls
{
  return controls;
}

- (snd_mixer_t *)createMixer
{
  snd_mixer_t *mixer = NULL;
  
  if (snd_mixer_open(&mixer, 0) < 0) {
    NSLog(@"Cannot open mixer for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_attach(mixer, [deviceName cString]) < 0) {
    NSLog(@"Cannot attach mixer for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_selem_register(mixer, NULL, NULL) < 0) {
    NSLog(@"Cannot register the mixer elements for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_load(mixer) < 0) {
    NSLog(@"Cannot load mixer for sound card `%@`.", cardName);
    return NULL;
  }

  return mixer;
}

- (void)deleteMixer
{
  snd_mixer_detach(alsa_mixer, [cardName cString]);
  snd_mixer_close(alsa_mixer);
  alsa_mixer = NULL;
}

@end
