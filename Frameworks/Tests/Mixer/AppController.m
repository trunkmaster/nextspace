/* 
   Project: Mixer
   Author: me
   Created: 2018-12-31 01:20:21 +0200 by me
   Application Controller
*/

#import "ALSA.h"
#import "PulseAudio.h"
#import "AppController.h"

@implementation AppController

- (void)dealloc
{
  [audioServer release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
}

- (BOOL)applicationShouldTerminate:(id)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

// --- Menu actions

- (void)openALSAPanel:(id)sender
{
  if (audioServer) {
    [audioServer release];
  }
  audioServer = [[ALSA alloc] init];
  if ([audioServer respondsToSelector:@selector(showPanel)]) {
    [audioServer showPanel];
  }
}

- (void)openPulseAudioPanel:(id)sender
{
  if (audioServer) {
    [audioServer release];
  }
  audioServer = [[PulseAudio alloc] init];
}

@end
