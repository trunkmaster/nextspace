/* 
   Project: Mixer

   Author: me

   Created: 2018-12-31 01:20:21 +0200 by me
   
   Application Controller
*/
 
#import <AppKit/AppKit.h>

@interface AppController : NSObject
{
  PulseAudio    *audioServer;
  
  NSPopUpButton *sectionType;
  
  NSBrowser     *playbackStreamList;
  NSButton      *playbackMute;
  id            playbackStreamVolume;
  id            playbackStreamBalance;
  
  NSBrowser     *playbackDeviceList;
  NSButton      *playbackDeviceMute;
  id            playbackDeviceVolume;
  id            playbackDeviceBalance;
}

@end
