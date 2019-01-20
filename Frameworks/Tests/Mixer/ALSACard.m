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

#import <dispatch/dispatch.h>

#import "ALSAElement.h"
#import "ALSACard.h"

  
// static dispatch_queue_t event_loop_q;
static int q_number = 0;

@implementation ALSACard

- (void)dealloc
{
  NSLog(@"[ALSACard] %@ dealloc", cardName);

  while (!isEventLoopDidQuit) {;}
  
  // if (isEventLoopActive != NO) {
  //   [self quitEventLoop];
  // }
  
  if (alsa_mixer != NULL) {
    [self deleteMixer:alsa_mixer];
  }

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
  snd_ctl_card_info_t *info;
  char                buf[16];
  snd_ctl_t           *ctl;

  [super init];

  NSLog(@"ALSACard: init with number %d", number);

  snd_ctl_card_info_alloca(&info);
  
  if (number < 0) {
    snd_mixer_t *mixer;
    snd_hctl_t  *hctl;

    deviceName = [[NSString alloc] initWithString:@"default"];
    mixer = [self createMixer];

    if (snd_mixer_get_hctl(mixer, [deviceName cString], &hctl) >= 0) {
      ctl = snd_hctl_ctl(hctl);
      if (snd_ctl_card_info(ctl, info) >= 0) {
        cardName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_name(info)];
        chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];
      }
    }
  
    [self deleteMixer:mixer];
  }
  else {
    sprintf(buf, "hw:%d", number);
    if (snd_ctl_open(&ctl, buf, 0) < 0) {
      return nil;
    }
    
    if (snd_ctl_card_info(ctl, info) < 0) {
      snd_ctl_close(ctl);
      return nil;
    }
    
    cardName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_name(info)];
    deviceName = [[NSString alloc] initWithFormat:@"hw:%d", number];

    alsa_mixer = [self createMixer];
    chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];

    snd_ctl_close(ctl);
  }
  
  alsa_mixer = [self createMixer];
  if (alsa_mixer) {
    snd_mixer_elem_t *elem;
 
    // fprintf(stderr, "Mixer elements for card `%s`:\n", [deviceName cString]);
    controls = [[NSMutableArray alloc] init];
    for (elem = snd_mixer_first_elem(alsa_mixer); elem; elem = snd_mixer_elem_next(elem)) {
      [controls addObject:[[ALSAElement alloc] initWithCard:self element:elem]];
    }
  }

  isEventLoopActive = NO;
  shouldHandleEvents = NO;
  isEventLoopDispatched = NO;
  isEventLoopDidQuit = NO;
  
  return self;
}

- (void)handleEvents:(BOOL)oneTime
{
  int            poll_count, fill_count;
  struct pollfd  *pollfds;
  unsigned short revents;
  int            n;

  if (oneTime == NO && shouldHandleEvents == NO) {
    usleep(50000);
    return;
  }

  poll_count = snd_mixer_poll_descriptors_count(alsa_mixer);
  if (poll_count <= 0) {
    NSLog(@"Cannot obtain mixer poll descriptors.");
  }

  // pollfds = alloca((poll_count + 1) * sizeof(struct pollfd));
  pollfds = alloca(poll_count * sizeof(struct pollfd));
  fill_count = snd_mixer_poll_descriptors(alsa_mixer, pollfds, poll_count);
  NSAssert(poll_count = fill_count, @"poll counts differ");

  // n = poll(pollfds, fill_count + 1, -1);
  n = poll(pollfds, poll_count, oneTime ? 0 : -1);

  if (oneTime == NO && shouldHandleEvents == NO) {
    return;
  }
  if (n > 0) {
    /* Ensure that changes made via other programs (alsamixer, etc.) get
       reflected as well.  */
    snd_mixer_poll_descriptors_revents(alsa_mixer, pollfds, poll_count, &revents);
    if (revents & POLLIN) {
      snd_mixer_handle_events(alsa_mixer);
      [controls makeObjectsPerform:@selector(refresh)];
    }
  }
  else {
    usleep(50000);
  }
}

- (void)enterEventLoop
{
  NSString *qName;
  NSLog(@"[ALSACard] `%@` eneterEventLoop.", cardName);

  if (event_loop_q == NULL) {
    qName = [NSString stringWithFormat:@"org.nextspace.alsamixer%i",q_number++];
    event_loop_q = dispatch_queue_create([qName cString], NULL);
  }
  else {
    NSLog(@"[ALSACard enterEventloop] `%@` event loop already created.", cardName);
  }

  if (isEventLoopDispatched == NO) {
    isEventLoopActive = YES;
    dispatch_async(event_loop_q, ^{
        while (isEventLoopActive != NO) {
          [self handleEvents:YES];
        }
        isEventLoopDidQuit = YES;
        fprintf(stderr, "ALSACard `%s` event loop quit.\n", [cardName cString]);
      });
    isEventLoopDispatched = YES;
  }
  else {
    NSLog(@"[ALSACard enterEventloop] `%@` block already dispatched.", cardName);
  }
}

- (void)pauseEventLoop
{
  if (isEventLoopDispatched == NO) {
    NSLog(@"[ALSACard pauseEventLoop] event loop was not dispatched to queue!"
          " Call -enterEventLoop first.");
    return;
  }
  shouldHandleEvents = NO;
}

- (void)resumeEventLoop
{
  if (isEventLoopDispatched == NO) {
    NSLog(@"[ALSACard resumeEventLoop] event loop was not dispatched to queue! "
          "Call -enterEventLoop first.");
    return;
  }
  shouldHandleEvents = YES;
}

- (void)quitEventLoop
{
  isEventLoopActive = NO;  // finishes running of dispatched block
  // shouldHandleEvents = NO; // stops processing events
  // isEventLoopDispatched = NO;
  
  if (event_loop_q != NULL) {
    dispatch_release(event_loop_q);
    event_loop_q = NULL;
  }
}

- (void)setShouldHandleEvents:(BOOL)yn
{
  shouldHandleEvents = yn;
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

- (snd_mixer_t *)mixer
{
  return alsa_mixer;
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

- (void)deleteMixer:(snd_mixer_t *)mixer
{
  snd_mixer_detach(mixer, [cardName cString]);
  snd_mixer_close(mixer);
  mixer = NULL;
}

@end
