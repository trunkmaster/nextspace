/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "Generic.h"

#include <sys/soundcard.h>
#include <sys/ioctl.h>                  /* control device */
#include <fcntl.h>
#include <unistd.h>

#define DEVICE_NAME "/dev/mixer"
int        mixer_fd;
static int ovol,ovol2,ovol3,ovol4,ovol5;

@implementation Generic

/* read volume settings, and set buttons */
- (void)awakeFromNib
{
  int vol;

  if ((mixer_fd = open(DEVICE_NAME, O_RDONLY | O_NONBLOCK, 0)) == -1) {
    printf("can't open mixer %s.\n",DEVICE_NAME);
    exit(1);
  }
  ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_VOLUME),&vol);
  [volL setIntValue:vol & 255];
  [volR setIntValue:vol >> 8];
  ovol=vol;
  ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_BASS),&vol);
  [bassL setIntValue:vol & 255];
  [bassR setIntValue:vol >> 8];
  ovol2=vol;
  ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_TREBLE),&vol);
  [trebleL setIntValue:vol & 255];
  [trebleR setIntValue:vol >> 8];
  ovol3=vol;
  ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_PCM),&vol);
  [pcmL setIntValue:vol & 255];
  [pcmR setIntValue:vol >> 8];
  ovol4=vol;
  ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_LINE),&vol);
  [lineL setIntValue:vol & 255];
  [lineR setIntValue:vol >> 8];
  ovol5=vol;
  close(mixer_fd);

  timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                           target:self
                                         selector:@selector(awakeFromNib)
                                         userInfo:nil
                                          repeats:NO];
}

/* set volume according to the buttons */
- (void)setVolume:(id)sender
{
  int vol,vol2,vol3,vol4,vol5;
    
  /*
    NSLog(@"%d",[volL intValue]);
    NSLog(@"%d",[volR intValue]);
    NSLog(@"%d",[volMute state]);
    NSLog(@"%d",[volLock state]);
  */

  if ([volLock state]) {
    if ((ovol & 255) != ([volL intValue]))
      vol=([volL intValue] | ([volL intValue] << 8)); 
    else
      vol=([volR intValue] | ([volR intValue] << 8)); 

    [volL setIntValue:vol & 255]; [volR setIntValue:vol & 255];
    ovol=vol;
  }
  if ([bassLock state]) {
    if ((ovol2 & 255) != ([bassL intValue]))
      vol2=([bassL intValue] | ([bassL intValue] << 8)); 
    else
      vol2=([bassR intValue] | ([bassR intValue] << 8)); 

    [bassL setIntValue:vol2 & 255]; [bassR setIntValue:vol2 & 255];
    ovol2=vol2;
  }
  if ([trebleLock state]) {
    if ((ovol3 & 255) != ([trebleL intValue]))
      vol3=([trebleL intValue] | ([trebleL intValue] << 8)); 
    else
      vol3=([trebleR intValue] | ([trebleR intValue] << 8)); 

    [trebleL setIntValue:vol3 & 255]; [trebleR setIntValue:vol3 & 255];
    ovol3=vol3;
  }
  if ([pcmLock state]) {
    if ((ovol4 & 255) != ([pcmL intValue]))
      vol4=([pcmL intValue] | ([pcmL intValue] << 8)); 
    else
      vol4=([pcmR intValue] | ([pcmR intValue] << 8)); 

    [pcmL setIntValue:vol4 & 255]; [pcmR setIntValue:vol4 & 255];
    ovol4=vol4;
  }
  if ([lineLock state]) {
    if ((ovol5 & 255) != ([lineL intValue]))
      vol5=([lineL intValue] | ([lineL intValue] << 8)); 
    else
      vol5=([lineR intValue] | ([lineR intValue] << 8)); 

    [lineL setIntValue:vol5 & 255]; [lineR setIntValue:vol5 & 255];
    ovol5=vol5;
  }

  if (![volMute state]) vol=[volL intValue] | ([volR intValue] << 8); else vol=0;
  if (![bassMute state]) vol2=[bassL intValue] | ([bassR intValue] << 8); else vol2=0;
  if (![trebleMute state]) vol3=[trebleL intValue] | ([trebleR intValue] << 8); else vol3=0;
  if (![pcmMute state]) vol4=[pcmL intValue] | ([pcmR intValue] << 8); else vol4=0;
  if (![lineMute state]) vol5=[lineL intValue] | ([lineR intValue] << 8); else vol5=0;

  if ((mixer_fd=open(DEVICE_NAME, O_RDONLY | O_NONBLOCK, 0)) == -1) {
    printf("can't open mixer %s.\n",DEVICE_NAME);
    exit(1);
  }
  ioctl(mixer_fd,MIXER_WRITE(SOUND_MIXER_VOLUME),&vol);
  ioctl(mixer_fd,MIXER_WRITE(SOUND_MIXER_BASS),&vol2);
  ioctl(mixer_fd,MIXER_WRITE(SOUND_MIXER_TREBLE),&vol3);
  ioctl(mixer_fd,MIXER_WRITE(SOUND_MIXER_PCM),&vol4);
  ioctl(mixer_fd,MIXER_WRITE(SOUND_MIXER_LINE),&vol5);

  close(mixer_fd);
}

@end
