/* All Rights reserved */

#import <alsa/asoundlib.h>

#import "ALSA.h"
#import "ALSAElement.h"

static snd_mixer_t      *mixer;
static char		*mixer_name;
static BOOL             mixerOpened = NO;

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
  [[element view] setFrameOrigin:NSMakePoint()];
  [super addSubview:[element view]
         positioned:NSWindowAbove
         relativeTo:lastAddedElement];
  lastAddedElement = [element view];
}
@end

@implementation ALSA

- (void)dealloc
{
  snd_mixer_detach(mixer, mixer_name);
  snd_mixer_close(mixer);
  
  [super dealloc];
}

struct card {
  struct card	*next;
  int		index;
  char		*indexstr;
  char		*name;
  char		*device_name;
};
static struct card first_card;

- (struct card *)_enumerateCards
{
  snd_ctl_card_info_t	*info;
  struct card 		*card, *prev_card;
  int 			count, number, err;
  char 			buf[16];
  snd_ctl_t		*ctl;
  
  first_card.indexstr = "-";
  first_card.name = "Default";
  first_card.device_name = "default";
  count = 1;

  snd_ctl_card_info_alloca(&info);
  prev_card = &first_card;
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
    sprintf(buf, "%d", number);
    card->indexstr = strdup(buf);
    
    card->name = strdup(snd_ctl_card_info_get_name(info));
    sprintf(buf, "hw:%d", number);
    
    card->device_name = strdup(buf);
    
    prev_card->next = card;
    prev_card = card;
    ++count;
  }

  return &first_card;
}

- (void)_openMixer
{
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
}

- (void)_closeMixer
{
  snd_mixer_detach(mixer, mixer_name);
  snd_mixer_close(mixer);
}

- (void)awakeFromNib
{
  struct card *card = [self _enumerateCards];

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

  elementsView = [[ALSAElementsView alloc] initWithFrame:[elementsScroll documentVisibleRect]];
  [elementsScroll setDocumentView:elementsView];

  [elementsView addElement:[[ALSAElement alloc] init]];
  [elementsView addElement:[[ALSAElement alloc] init]];

  // snd_mixer_elem_t *elem;
  // for (elem = snd_mixer_first_elem(handle); elem; elem = snd_mixer_elem_next(elem)) {
  //   controls_count += get_controls_count_for_elem(elem);
  // }
} 

- (void)showPanel
{
  if (alsaWindow == nil) {
    [NSBundle loadNibNamed:@"ALSA" owner:self];
  }
  [alsaWindow makeKeyAndOrderFront:self];
}

@end
