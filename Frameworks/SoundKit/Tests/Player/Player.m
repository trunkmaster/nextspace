/* All Rights reserved */

#import "Player.h"

@implementation Player

- (void)dealloc
{
  [infoOff release];
  [infoOn release];
  if (sound)
    [sound release];
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
  NSString *path, *imagePath;

  [window setFrameAutosaveName:@"Player"];
  [window makeKeyAndOrderFront:self];
  
  [artistName setStringValue:@"Artist name"];
  [albumTitle setStringValue:@"Album title"];
  [songTitle setStringValue:@"Song title"];
  [window setTitle:@"Player \u2014 No loaded sound"];

  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  imagePath = @"Resources/PlayerWindow.gorm/PlayerInfo-1.tiff";
  path = [NSString stringWithFormat:@"%@/%@",
                        [[NSBundle mainBundle] bundlePath], imagePath];
  infoOff = [[NSImage alloc] initByReferencingFile:path];
  
  imagePath = @"Resources/PlayerWindow.gorm/PlayerInfo-2.tiff";
  path = [NSString stringWithFormat:@"%@/%@",
                        [[NSBundle mainBundle] bundlePath], imagePath];
  infoOn = [[NSImage alloc] initByReferencingFile:path];
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
  NSString *file;

  [playBtn setState:NSOnState];
  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  [infoView setImage:infoOn];

  file = @"/usr/NextSpace/Sounds/Bonk.snd";
  [songTitle setStringValue:file];
  sound = [[NXTSound alloc] initWithContentsOfFile:file
                                       byReference:NO];
  [sound play];
  [sound setDelegate:self];
}
// NXTSound deleagate method
- (void)sound:(NXTSound *)snd didFinishPlaying:(BOOL)aBool
{
  NSLog(@"Sound did finish playing; RC: %lu", [snd retainCount]);
  if (aBool != NO) {
    [self stop:playBtn];
    [snd release];
  }
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
  if (sound) {
    [sound stop];
  }
  
  [songTitle setStringValue:@"--"];
  
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
}

- (BOOL)windowShouldClose:(id)sender
{
  [self eject:self];
  [NSApp terminate:self];
  return YES;
}

@end
