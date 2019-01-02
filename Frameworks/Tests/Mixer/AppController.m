/* 
   Project: Mixer
   Author: me
   Created: 2018-12-31 01:20:21 +0200 by me
   Application Controller
*/

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
  audioServer = [[PulseAudio alloc] init];
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

@end
