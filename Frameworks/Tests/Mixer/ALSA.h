/* All Rights reserved */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class ALSAElementsView;

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

  NSWindow	*alsaWindow;
  NSPopUpButton	*cardsList;
  NSPopUpButton	*viewMode;
  
  NSScrollView		*elementsScroll;
  ALSAElementsView	*elementsView;
}

- (void)showPanel;

@end
