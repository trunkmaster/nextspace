/* All Rights reserved */

#import <alsa/asoundlib.h>

#import "ALSA.h"
#import "ALSAElement.h"

static BOOL mixerOpened = NO;

/* Convenience macro to die in informational manner.  */
#define DIE(msg) {                                                     \
    NSRunCriticalAlertPanel (@"Error",                                 \
                             msg @"\nThe application will terminate.", \
			     @"OK", nil, nil);                         \
    exit(EXIT_FAILURE);                                                \
  }

@interface ALSAElementsView : NSView
{
  NSView *lastAddedElement;
}
- (void)addElement:(ALSAElement *)element;
@end
@implementation ALSAElementsView
- (BOOL)isFlipped
{
  return YES;
}
- (void)addElement:(ALSAElement *)element
{
  NSRect laeFrame = [lastAddedElement frame];
  NSRect eFrame = [[element view] frame];

  eFrame.origin.y = laeFrame.origin.y + laeFrame.size.height;
  [[element view] setFrameOrigin:eFrame.origin];
  [super addSubview:[element view]
         positioned:NSWindowAbove
         relativeTo:lastAddedElement];
  lastAddedElement = [element view];
}
@end

@implementation ALSA

struct card {
  struct card	*next;
  int		index;
  char		*name;
  char		*device_name;
  char		*chip_name;
};

- (snd_mixer_t *)_openMixerWithName:(char *)mixer_name
{
  snd_mixer_t *mixer;
  
  if (snd_mixer_open(&mixer, 0) < 0)
    DIE(@"Cannot open mixer.");
  if (snd_mixer_attach(mixer, mixer_name) < 0)
    DIE(@"Cannot attach mixer.");
  if (snd_mixer_selem_register(mixer, NULL, NULL) < 0)
    DIE (@"Cannot register the mixer elements.");
  if (snd_mixer_load(mixer) < 0)
    DIE (@"Cannot load mixer.");

  // [NSTimer scheduledTimerWithTimeInterval:0.5
  //                                  target:self
  //                                selector:@selector(refresh)
  //                                userInfo:nil
  //                                 repeats:YES];
  // [NSApp setDelegate:self];
  mixerOpened = YES;

  return mixer;
}

- (void)_closeMixer:(snd_mixer_t *)mixer withName:(char *)mixer_name
{
  snd_mixer_detach(mixer, mixer_name);
  snd_mixer_close(mixer);
}

struct element {
  struct element   *next;
  snd_mixer_elem_t *elem;
  int              index;
  char             *name;
  int              playback_volume;
  int              playback_volume_min;
  int              playback_volume_max;
  int              capture_volume;
  struct {
    int is_active:1;
    int is_mono:1;
    int is_playback:1;
    int has_common_volume:1;
  } flags;
};

- (struct card *)_enumerateCards
{
  snd_ctl_card_info_t	*info;
  struct card		*first_card;
  struct card 		*card, *prev_card = NULL;
  int 			count, number, err;
  char 			buf[16];
  snd_ctl_t		*ctl;
  
  // first_card.indexstr = "-";
  // first_card.name = "Default";
  // first_card.device_name = "default";
  count = 0;

  snd_ctl_card_info_alloca(&info);
  // prev_card = &first_card;
  number = -1;
  
  for (;;) {
    err = snd_card_next(&number);
    
    if (err < 0)
      fprintf(stderr, "ALSA: cannot enumerate sound cards: %i\n", err);
    if (number < 0)
      break;
    
    sprintf(buf, "hw:%d", number);
    err = snd_ctl_open(&ctl, buf, 0);
    if (err < 0)
      continue;
    
    err = snd_ctl_card_info(ctl, info);
    snd_ctl_close(ctl);
    if (err < 0)
      continue;
    
    card = calloc(1, sizeof *card);
    
    card->index = number;
    
    card->name = strdup(snd_ctl_card_info_get_name(info));
    sprintf(buf, "hw:%d", number);
    
    card->device_name = strdup(buf);

    {
      snd_mixer_t *mixer = [self _openMixerWithName:card->device_name];
      snd_hctl_t *hctl;
      snd_ctl_t *ctl;
      snd_ctl_card_info_t *card_info;
      snd_ctl_card_info_alloca(&card_info);
      if (card->device_name)
        err = snd_mixer_get_hctl(mixer, card->device_name, &hctl);
      else
        err = -1;
      if (err >= 0) {
        ctl = snd_hctl_ctl(hctl);
        err = snd_ctl_card_info(ctl, card_info);
        if (err >= 0) {
          card->name = strdup(snd_ctl_card_info_get_mixername(card_info));
        }
      }
      [self _closeMixer:mixer withName:card->device_name];
    }
    
    if (number == 0)
      first_card = card;

    if (prev_card)
      prev_card->next = card;
    
    prev_card = card;
    ++count;
  }

  return first_card;
}

- (void)_enumerateElementsForCard:(struct card *)card
{
  snd_mixer_t          *mixer;
  snd_mixer_elem_t     *elem;
  snd_mixer_selem_id_t *selem_id;
  
  while (card) {
    fprintf(stderr, "Mixer elements for `%s`:\n", card->device_name);
    mixer = [self _openMixerWithName:card->device_name];
  
    snd_mixer_selem_id_alloca(&selem_id);
  
    for (elem = snd_mixer_first_elem(mixer); elem; elem = snd_mixer_elem_next(elem)) {
      // controls_count += get_controls_count_for_elem(elem);
      snd_mixer_selem_get_id(elem, selem_id);
      fprintf(stderr, "\t%s (active:%i, capture:%i, common_switch:%i playback_switch:%i)\n",
              snd_mixer_selem_id_get_name(selem_id),
              snd_mixer_selem_is_active(elem),
              snd_mixer_selem_has_capture_volume(elem),
              snd_mixer_selem_has_common_switch(elem),
              snd_mixer_selem_has_playback_switch(elem));
    }
    [self _closeMixer:mixer withName:card->device_name];
    card = card->next;
  }
}

- (void)awakeFromNib
{
  struct card *first_card;
  struct card *card = [self _enumerateCards];

  first_card = card;

  [cardsList setRefusesFirstResponder:YES];
  [viewMode setRefusesFirstResponder:YES];
  
  [cardsList removeAllItems];
  while (card) {
    [cardsList addItemWithTitle:[NSString stringWithCString:card->name]];
    [[cardsList itemWithTitle:[NSString stringWithCString:card->name]]
      setTag:card->index];
    card = card->next;
  }

  elementsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(-2,-2,402,536)];
  [elementsScroll setHasVerticalScroller:YES];
  [elementsScroll setHasHorizontalScroller:NO];
  [elementsScroll setBorderType:NSBezelBorder];
  [elementsScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [[alsaWindow contentView] addSubview:elementsScroll];

  elementsView = [[ALSAElementsView alloc]
                   initWithFrame:[elementsScroll documentVisibleRect]];
  [elementsScroll setDocumentView:elementsView];

  // [elementsView addElement:[[ALSAElement alloc] init]];
  // [elementsView addElement:[[ALSAElement alloc] init]];

  [self _enumerateElementsForCard:first_card];
} 

- (void)showPanel
{
  if (alsaWindow == nil) {
    [NSBundle loadNibNamed:@"ALSA" owner:self];
  }
  [alsaWindow makeKeyAndOrderFront:self];
}

@end
