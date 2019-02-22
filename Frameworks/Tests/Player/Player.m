/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "Player.h"

@implementation Player

- (void)dealloc
{
  [infoOff release];
  [infoOn release];
  [super dealloc];
}

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
  NSString *path;
  
  [window makeKeyAndOrderFront:self];
  [artistName setStringValue:@""];
  [albumTitle setStringValue:@""];
  [songTitle setStringValue:@"No Sound Loaded"];
  [window setTitle:@"\u2014"];

  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  path = [NSBundle pathForResource:@"PlayerInfo-1"
                            ofType:@"tiff"
                       inDirectory:@"Resources/PlayerWindow.gorm"];
  infoOff = [[NSImage alloc] initByReferencingFile:path];
  path = [NSBundle pathForResource:@"PlayerInfo-2"
                            ofType:@"tiff"
                       inDirectory:@"Resources/PlayerWindow.gorm"];
  infoOn = [[NSImage alloc] initByReferencingFile:path];

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
  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  [infoView setImage:infoOn];
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
  [playBtn setState:NSOffState];
  [pauseBtn setState:NSOffState];
  
  [infoView setImage:infoOff];
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


- (BOOL)windowShouldClose:(id)sender
{
  [self eject:self];
  [NSApp terminate:self];
  return YES;
}

@end
