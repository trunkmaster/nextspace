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
  [artistName setStringValue:@""];
  [albumTitle setStringValue:@""];
  [songTitle setStringValue:@"No Sound Loaded"];
  [window setTitle:@"\u2014"];

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
    [self play:playBtn];
  }
  else if (server.state == SKServerFailedState ||
           server.state == SKServerTerminatedState) {
    [self stop:stopBtn];
    [self setButtonsEnabled:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [server release];
    server = nil;
  }
}
- (void)setButtonsEnabled:(BOOL)yn
{
  [playBtn setEnabled:yn];
  [pauseBtn setEnabled:yn];
  [stopBtn setEnabled:yn];
  [prevBtn setEnabled:yn];
  [nextBtn setEnabled:yn];
  [repeatBtn setEnabled:yn];
  [shuffleBtn setEnabled:yn];
}


- (void)play:(id)sender
{
  NSString *path;
  NSImage  *image;
  
  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  path = [NSBundle pathForResource:@"PlayerInfo-2"
                            ofType:@"tiff"
                       inDirectory:@"Resources/PlayerWindow.gorm"];
  image = [[NSImage alloc] initByReferencingFile:path];
  [infoView setImage:image];
  [image release];
}
- (void)pause:(id)sender
{
  if ([(NSButton *)sender state] == NSOnState) {
    [playBtn setState:NSOffState];
    [stopBtn setState:NSOffState];
  }
  else {
    [playBtn setState:NSOnState];
  }
}
- (void)stop:(id)sender
{
  NSString *path;
  NSImage  *image;
  
  [playBtn setState:NSOffState];
  [pauseBtn setState:NSOffState];
  
  path = [NSBundle pathForResource:@"PlayerInfo-1"
                            ofType:@"tiff"
                       inDirectory:@"Resources/PlayerWindow.gorm"];
  image = [[NSImage alloc] initByReferencingFile:path];
  [infoView setImage:image];
  
  [image release];
  [sender setState:NSOffState];
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
  if (server != nil) {
    NSLog(@"Server retain count: %lu", [server retainCount]);
    [server disconnect];
  }
}

@end
