/* All Rights reserved */

#import <alsa/asoundlib.h>

#import "ALSA.h"

static snd_mixer_t      *handle;
static snd_mixer_elem_t *volumeElem;
static snd_mixer_elem_t *bassElem;
static snd_mixer_elem_t *trebleElem;
static snd_mixer_elem_t *pcmElem;
static snd_mixer_elem_t *lineElem;
static BOOL             mixerOpened = NO;

/* The "default" device seems to be managed by pulseaudio these days
   (at least on most desktops), so stick to the real one.  This
   doesn't cope well with multiple cards, but we have a hardcoded GUI
   anyway so that is the last problem.  */
#define DEVICE_NAME "hw:0"

/* Convenience macro to die in informational manner.  */
#define DIE(msg) {                                                     \
    NSRunCriticalAlertPanel (@"Error",                                 \
                             msg @"\nThe application will terminate.", \
			     @"OK", nil, nil);                         \
    exit(EXIT_FAILURE);                                                \
  }

@implementation ALSA

- (void)dealloc
{
  snd_mixer_detach(handle, DEVICE_NAME);
  snd_mixer_close(handle);
  
  [super dealloc];
}

/* read volume settings, and set buttons */
- (void)awakeFromNib
{
  snd_mixer_elem_t     *elem;
  snd_mixer_selem_id_t *sid;
  long                 lvol, lvol_r, min, max;

  if (!mixerOpened)
    [self openMixer];

  snd_mixer_selem_id_alloca(&sid);

  for (elem = snd_mixer_first_elem(handle); elem; elem = snd_mixer_elem_next(elem)) {
    if (snd_mixer_selem_is_active(elem) && snd_mixer_selem_has_playback_volume(elem)) {
      /* Because our controls are hardcoded in the .gorm file we
         can't construct the UI on the fly based on the
         available elements, as it should be done normally.  So
         resort to dumb parsing in the hope that the names of
         the elements match ours.  This is far from ideal; the
         master element may be called "Front", for example.  */
      snd_mixer_selem_get_id(elem, sid);
      if (!strcmp(snd_mixer_selem_id_get_name(sid), "Master")) {
        snd_mixer_selem_get_playback_volume (elem, SND_MIXER_SCHN_FRONT_LEFT, &lvol);
        snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        [volL setMinValue:min];
        [volL setMaxValue:max];
        [volL setIntValue:lvol];
        [volR setMinValue:min];
        [volR setMaxValue:max];
        if (snd_mixer_selem_is_playback_mono(elem)) {
          [volR setIntValue:lvol];
        }
        else {
          snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_RIGHT, &lvol_r);
          [volR setIntValue:lvol_r];
        }

        volumeElem = elem;
      }

      /* It seems that most cards do not have bass/treble
         controls.  Oh well.  */
      if (!strcmp(snd_mixer_selem_id_get_name(sid), "Bass")) {
        snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &lvol);
        snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        [bassL setMinValue:min];
        [bassL setMaxValue:max];
        [bassL setIntValue:lvol];
        [bassR setMinValue:min];
        [bassR setMaxValue:max];

        if (snd_mixer_selem_is_playback_mono(elem)) {
          [bassR setIntValue:lvol];
        }
        else {
          snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_RIGHT, &lvol_r);
          [bassR setIntValue:lvol_r];
        }

        bassElem = elem;
      }

      if (!strcmp(snd_mixer_selem_id_get_name(sid), "Treble")) {
        snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &lvol);
        snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        [trebleL setMinValue:min];
        [trebleL setMaxValue:max];
        [trebleL setIntValue:lvol];
        [trebleR setMinValue:min];
        [trebleR setMaxValue:max];

        if (snd_mixer_selem_is_playback_mono(elem)) {
          [trebleR setIntValue:lvol];
        }
        else {
          snd_mixer_selem_get_playback_volume (elem, SND_MIXER_SCHN_FRONT_RIGHT, &lvol_r);
          [trebleR setIntValue:lvol_r];
        }

        trebleElem = elem;
      }

      if (!strcmp(snd_mixer_selem_id_get_name(sid), "PCM")) {
        snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &lvol);
        snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        [pcmL setMinValue:min];
        [pcmL setMaxValue:max];
        [pcmL setIntValue:lvol];
        [pcmR setMinValue:min];
        [pcmR setMaxValue:max];
        if (snd_mixer_selem_is_playback_mono(elem)) {
          [pcmR setIntValue:lvol];
        }
        else {
          snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_RIGHT, &lvol_r);
          [pcmR setIntValue:lvol_r];
        }

        pcmElem = elem;
      }

      if (!strcmp (snd_mixer_selem_id_get_name(sid), "Line")) {
        snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &lvol);
        snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        [lineL setMinValue:min];
        [lineL setMaxValue:max];
        [lineL setIntValue:lvol];
        [lineR setMinValue:min];
        [lineR setMaxValue:max];

        if (snd_mixer_selem_is_playback_mono(elem)) {
          [lineR setIntValue:lvol];
        }
        else {
          snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_RIGHT, &lvol_r);
          [lineR setIntValue:lvol_r];
        }

        lineElem = elem;
      }
    }
  }

  /* Disable controls that are beyond our control.  */
  if (!volumeElem) { /* <= Could happen in practice...  */
    [volL setAction:@selector(controlNotAvailable:)];
    [volR setEnabled:NO];
    [volMute setEnabled:NO];
    [volLock setEnabled:NO];
  }
  if (!bassElem) {
    [bassL setAction:@selector(controlNotAvailable:)];
    [bassR setEnabled:NO];
    [bassMute setEnabled:NO];
    [bassLock setEnabled:NO];
  }
  if (!trebleElem) {
    [trebleL setAction:@selector(controlNotAvailable:)];
    [trebleR setEnabled:NO];
    [trebleMute setEnabled:NO];
    [trebleLock setEnabled:NO];
  }
  if (!pcmElem) {
    [pcmL setAction:@selector(controlNotAvailable:)];
    [pcmR setEnabled:NO];
    [pcmMute setEnabled:NO];
    [pcmLock setEnabled:NO];
  }
  if (!lineElem) {
    [lineL setAction:@selector(controlNotAvailable:)];
    [lineR setEnabled:NO];
    [lineMute setEnabled:NO];
    [lineLock setEnabled:NO];
  }
}

- (void)showPanel
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"ALSA" owner:self];
  }
  [window makeKeyAndOrderFront:self];
}

- (void)refresh
{
  int poll_count, fill_count;
  long lvol, lvol_r;
  struct pollfd *polls;
  unsigned short revents;

  poll_count = snd_mixer_poll_descriptors_count (handle);
  if (poll_count <= 0)
    DIE (@"Cannot obtain mixer poll descriptors.");

  polls = alloca ((poll_count + 1) * sizeof (struct pollfd));
  fill_count = snd_mixer_poll_descriptors (handle, polls, poll_count);
  NSAssert (poll_count = fill_count, @"poll counts differ");

  poll (polls, fill_count + 1, 5);

  /* Ensure that changes made via other programs (alsamixer, etc.) get
     reflected as well.  */
  snd_mixer_poll_descriptors_revents (handle, polls, poll_count, &revents);
  if (revents & POLLIN)
    snd_mixer_handle_events (handle);

  if (volumeElem)
    {
      snd_mixer_selem_get_playback_volume (volumeElem,
					   SND_MIXER_SCHN_FRONT_LEFT,
					   &lvol);
      [volL setIntValue: lvol];
      if (snd_mixer_selem_is_playback_mono (volumeElem))
	[volR setIntValue: lvol];
      else
	{
	  snd_mixer_selem_get_playback_volume (volumeElem,
					       SND_MIXER_SCHN_FRONT_RIGHT,
					       &lvol_r);
	  [volR setIntValue: lvol_r];
	}
    }

  if (bassElem)
    {
      snd_mixer_selem_get_playback_volume (bassElem,
					   SND_MIXER_SCHN_FRONT_LEFT,
					   &lvol);
      [bassL setIntValue: lvol];
      if (snd_mixer_selem_is_playback_mono (bassElem))
	[bassR setIntValue: lvol];
      else
	{
	  snd_mixer_selem_get_playback_volume (bassElem,
					       SND_MIXER_SCHN_FRONT_RIGHT,
					       &lvol_r);
	  [bassR setIntValue: lvol_r];
	}
    }

  if (trebleElem)
    {
      snd_mixer_selem_get_playback_volume (trebleElem,
					   SND_MIXER_SCHN_FRONT_LEFT,
					   &lvol);
      [trebleL setIntValue: lvol];
      if (snd_mixer_selem_is_playback_mono (trebleElem))
	[trebleR setIntValue: lvol];
      else
	{
	  snd_mixer_selem_get_playback_volume (trebleElem,
					       SND_MIXER_SCHN_FRONT_RIGHT,
					       &lvol_r);
	  [trebleR setIntValue: lvol_r];
	}
    }

  if (pcmElem)
    {
      snd_mixer_selem_get_playback_volume (pcmElem,
					   SND_MIXER_SCHN_FRONT_LEFT,
					   &lvol);
      [pcmL setIntValue: lvol];
      if (snd_mixer_selem_is_playback_mono (pcmElem))
	[pcmR setIntValue: lvol];
      else
	{
	  snd_mixer_selem_get_playback_volume (pcmElem,
					       SND_MIXER_SCHN_FRONT_RIGHT,
					       &lvol_r);
	  [pcmR setIntValue: lvol_r];
	}
    }

  if (lineElem)
    {
      snd_mixer_selem_get_playback_volume (lineElem,
					   SND_MIXER_SCHN_FRONT_LEFT,
					   &lvol);
      [lineL setIntValue: lvol];
      if (snd_mixer_selem_is_playback_mono (lineElem))
	[lineR setIntValue: lvol];
      else
	{
	  snd_mixer_selem_get_playback_volume (lineElem,
					       SND_MIXER_SCHN_FRONT_RIGHT,
					       &lvol_r);
	  [lineR setIntValue: lvol_r];
	}
    }
}

- (void)openMixer
{
  if (snd_mixer_open(&handle, 0) < 0)
    DIE(@"Cannot open mixer.");
  if (snd_mixer_attach(handle, DEVICE_NAME) < 0)
    DIE(@"Cannot attach mixer.");
  if (snd_mixer_selem_register(handle, NULL, NULL) < 0)
    DIE (@"Cannot register the mixer elements.");
  if (snd_mixer_load(handle) < 0)
    DIE (@"Cannot load mixer.");

  [NSTimer scheduledTimerWithTimeInterval:0.5
                                   target:self
                                 selector:@selector(refresh)
                                 userInfo:nil
                                  repeats:YES];
  [NSApp setDelegate:self];
  mixerOpened = YES;
}

- (void)controlNotAvailable:(id)sender
{
  NSRunInformationalAlertPanel(@"Control missing",
                               @"It looks like the sound card does not "
                               @"have this type of control.",
                               @"OK", nil, nil);
  [sender setIntValue:0];
  [sender setEnabled:NO];
}

/* set volume according to the buttons */
- (void)setVolume:(id)sender
{
  long vol;

  if (volumeElem) {
    if (![volMute state]) {
      vol = [volL intValue];
      snd_mixer_selem_set_playback_volume(volumeElem, SND_MIXER_SCHN_FRONT_LEFT, vol);
      if ([volLock state]) {
        [volR setIntValue:vol];
        if (!snd_mixer_selem_is_playback_mono(volumeElem))
          snd_mixer_selem_set_playback_volume(volumeElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
      else if (!snd_mixer_selem_is_playback_mono(volumeElem)) {
        vol = [volR intValue];
        snd_mixer_selem_set_playback_volume(volumeElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
    }
    else {
      snd_mixer_selem_set_playback_volume(volumeElem, SND_MIXER_SCHN_FRONT_LEFT, 0);
      if (!snd_mixer_selem_is_playback_mono(volumeElem))
        snd_mixer_selem_set_playback_volume(volumeElem, SND_MIXER_SCHN_FRONT_RIGHT, 0);
    }
  }

  if (bassElem) {
    if (![bassMute state]) {
      vol = [bassL intValue];
      snd_mixer_selem_set_playback_volume(bassElem, SND_MIXER_SCHN_FRONT_LEFT, vol);
      if ([bassLock state]) {
        [bassR setIntValue: vol];
        if (!snd_mixer_selem_is_playback_mono(bassElem))
          snd_mixer_selem_set_playback_volume(bassElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
      else if (!snd_mixer_selem_is_playback_mono (bassElem)) {
        vol = [bassR intValue];
        snd_mixer_selem_set_playback_volume(bassElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
    }
    else {
      snd_mixer_selem_set_playback_volume (bassElem, SND_MIXER_SCHN_FRONT_LEFT, 0);
      if (!snd_mixer_selem_is_playback_mono (bassElem))
        snd_mixer_selem_set_playback_volume (bassElem, SND_MIXER_SCHN_FRONT_RIGHT, 0);
    }
  }

  if (trebleElem) {
    if (![trebleMute state]) {
      vol = [trebleL intValue];
      snd_mixer_selem_set_playback_volume(trebleElem, SND_MIXER_SCHN_FRONT_LEFT, vol);
      if ([trebleLock state]) {
        [trebleR setIntValue: vol];
        if (!snd_mixer_selem_is_playback_mono(trebleElem))
          snd_mixer_selem_set_playback_volume(trebleElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
      else if (!snd_mixer_selem_is_playback_mono (trebleElem))
        vol = [trebleR intValue];
      snd_mixer_selem_set_playback_volume(trebleElem, SND_MIXER_SCHN_FRONT_RIGHT,vol);
    }
    else {
      snd_mixer_selem_set_playback_volume(trebleElem, SND_MIXER_SCHN_FRONT_LEFT, 0);
      if (!snd_mixer_selem_is_playback_mono (trebleElem))
        snd_mixer_selem_set_playback_volume (trebleElem, SND_MIXER_SCHN_FRONT_RIGHT, 0);
    }
  }

  if (pcmElem) {
    if (![pcmMute state]) {
      vol = [pcmL intValue];
      snd_mixer_selem_set_playback_volume(pcmElem, SND_MIXER_SCHN_FRONT_LEFT, vol);
      if ([pcmLock state]) {
        [pcmR setIntValue:vol];
        if (!snd_mixer_selem_is_playback_mono (pcmElem))
          snd_mixer_selem_set_playback_volume (pcmElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
      else if (!snd_mixer_selem_is_playback_mono (pcmElem)) {
        vol = [pcmR intValue];
        snd_mixer_selem_set_playback_volume (pcmElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
    }
    else {
      snd_mixer_selem_set_playback_volume (pcmElem, SND_MIXER_SCHN_FRONT_LEFT, 0);
      if (!snd_mixer_selem_is_playback_mono (pcmElem))
        snd_mixer_selem_set_playback_volume (pcmElem, SND_MIXER_SCHN_FRONT_RIGHT, 0);
    }
  }

  if (lineElem) {
    if (![lineMute state]) {
      vol = [lineL intValue];
      snd_mixer_selem_set_playback_volume(lineElem, SND_MIXER_SCHN_FRONT_LEFT, vol);
      if ([lineLock state]) {
        [lineR setIntValue: vol];
        if (!snd_mixer_selem_is_playback_mono(lineElem))
          snd_mixer_selem_set_playback_volume (lineElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
      else if (!snd_mixer_selem_is_playback_mono (lineElem)) {
        vol = [lineR intValue];
        snd_mixer_selem_set_playback_volume (lineElem, SND_MIXER_SCHN_FRONT_RIGHT, vol);
      }
    }
    else {
      snd_mixer_selem_set_playback_volume (lineElem, SND_MIXER_SCHN_FRONT_LEFT, 0);
      if (!snd_mixer_selem_is_playback_mono (lineElem))
        snd_mixer_selem_set_playback_volume (lineElem, SND_MIXER_SCHN_FRONT_RIGHT, 0);
    }
  }
}

@end
