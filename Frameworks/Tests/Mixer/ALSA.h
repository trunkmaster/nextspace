/* All Rights reserved */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface ALSA : NSObject
{
  NSTimer *timer;

  NSWindow *window;

  id volL;
  id volR;
  id volLock;
  id volMute;
  
  id bassL;
  id bassR;
  id bassLock;
  id bassMute;
  
  id trebleL;
  id trebleR;
  id trebleLock;
  id trebleMute;
  
  id pcmL;
  id pcmR;
  id pcmLock;
  id pcmMute;

  id lineL;
  id lineR;
  id lineLock;
  id lineMute;
}

- (void)showPanel;
- (void)refresh;
- (void)openMixer;
- (void)setVolume:(id)sender;

@end
