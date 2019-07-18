/* All Rights reserved */

#import <DesktopKit/NXTOpenPanel.h>

#import "Player.h"

@implementation Player

- (void)dealloc
{
  NSLog(@"Player -dealloc");
  [infoOff release];
  [infoOn release];
  
  if (sound)
    [sound release];
  [[SNDServer sharedServer] disconnect];
  [[SNDServer sharedServer] release];
  
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
  [self setWindowTitleForFile:nil];

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

  [self setButtonsEnabled:NO];
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

- (void)open:(id)sender
{
  NXTOpenPanel *openPanel = [NXTOpenPanel new];
  NSString     *file;
  // NSString *file = @"/usr/NextSpace/Sounds/Bonk.snd";
  // NSString *file = @"/Users/me/Music/Shallow/1 - Lady Gaga, Bradley Cooper - Shallow.flac";
  // NSString *file = @"/usr/NextSpace/Sounds/Welcome-to-the-NeXT-world.snd";

  if (openPanel == nil) {
    return;
  }

  NSLog(@"Sounds: %@", [NSSound soundUnfilteredFileTypes]);
  [openPanel setAllowedFileTypes:[NSSound soundUnfilteredFileTypes]];
  
  // [openPanel setDirectory:NSHomeDirectory()];
  [openPanel runModal];
  NSLog(@"Selected file: %@ in %@", [openPanel filename], [openPanel directory]);

  if (sound != nil) {
    [self stop:stopBtn];
    [sound release];
  }
  
  file = [openPanel filename];
  [self setWindowTitleForFile:file];
  [songTitle setStringValue:[file lastPathComponent]];
  sound = [[NXTSound alloc] initWithContentsOfFile:file
                                       byReference:YES];
  [sound setDelegate:self];
  
  [self setButtonsEnabled:YES];
  
  [openPanel release];
  openPanel = nil;
}

- (void)play:(id)sender
{
  [playBtn setState:NSOnState];
  [pauseBtn setState:NSOffState];
  [stopBtn setState:NSOffState];
  
  [infoView setImage:infoOn];

  if (sound != nil && [sound isPlaying]) {
    NSLog(@"[Player] sound is playing");
    [sound resume];
  }
  else {
    NSLog(@"[Player] sound is stopped");
    [sound play];
  }
}
// NXTSound deleagate method
- (void)sound:(NXTSound *)snd didFinishPlaying:(BOOL)aBool
{
  NSLog(@"Sound did finish playing; RC: %lu", [sound retainCount]);
  if (aBool != NO) {
    [self stop:playBtn];
    // [sound release];
    // sound = nil;
  }
}
- (void)pause:(id)sender
{
  [sound pause];
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
  if (sound != nil && [sound isPlaying]) {
    [sound stop];
  }
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

- (void)setWindowTitleForFile:(NSString *)filename
{
  NSString *name;

  if (filename == nil) {
    name = @"No sound";
  }
  else {
    name = [[filename lastPathComponent] stringByDeletingPathExtension];
  }

  [window setTitle:[NSString stringWithFormat:@"Player \u2014 %@", name]];
}

- (BOOL)windowShouldClose:(id)sender
{
  [self eject:self];
  [NSApp terminate:self];
  return YES;
}

@end
