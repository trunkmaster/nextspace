/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "Player.h"

@implementation Player

- init
{
  self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"PlayerWindow" owner:self];
  }

  return self;
}

- (void)awakeFromNib
{
  [window makeKeyAndOrderFront:self];

  // 1. Connect to PulseAudio on locahost
  server = [SKSoundServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SKServerStateDidChangeNotification
         object:server];
}

- (void)serverStateChanged:(NSNotification *)notif
{
  if (server.state == SKServerReadyState) {
    NSLog(@"Sound server is ready!");
  }
}


- (void)play:(id)sender
{
  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
}
- (void)pause:(id)sender
{
  [playBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
}
- (void)stop:(id)sender
{
  [playBtn setState:NSOffState];
  [pauseBtn setState:NSOffState];
}

- (void)next:(id)sender
{
  NSLog(@"Next");
}
- (void)prev:(id)sender
{
  NSLog(@"Previous");
}

- (void)repeat:(id)sender
{
  [shuffleBtn setState:NSOffState];
}
- (void)shuffle:(id)sender
{
  [repeatBtn setState:NSOffState];
}

- (void)eject:(id)sender
{
  NSLog(@"Eject");
}

@end
