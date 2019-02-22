/* All Rights reserved */

#include <AppKit/AppKit.h>
#include <SoundKit/SKSoundServer.h>

@interface Player : NSObject
{
  id window;
  id infoView;
  NSImage *infoOff;
  NSImage *infoOn;
  
  id albumTitle;
  id artistName;
  id songTitle;
  id time;
  id track;
  id progressBox;
  id progressSlider;

  id playBtn;
  id pauseBtn;
  id stopBtn;
  
  id nextBtn;
  id prevBtn;

  id repeatBtn;
  id shuffleBtn;
  
  id ejectBtn;

  SKSoundServer *server;
}
- (void)setButtonsEnabled:(BOOL)yn;
  
- (void)eject:(id)sender;
- (void)next:(id)sender;
- (void)pause:(id)sender;
- (void)play:(id)sender;
- (void)prev:(id)sender;
- (void)repeat:(id)sender;
- (void)shuffle:(id)sender;
- (void)stop:(id)sender;
@end
