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

- (void)_initSoundWithFile:(NSString *)filename
{
  sound = [[NXTSound alloc] initWithContentsOfFile:filename
                                       byReference:YES
                                        streamType:SNDApplicationType];
  [sound setDelegate:self];
}

- (void)open:(id)sender
{
  NXTOpenPanel *openPanel = [NXTOpenPanel new];

  if (openPanel == nil) {
    return;
  }

  NSLog(@"Sounds: %@", [NSSound soundUnfilteredFileTypes]);
  [openPanel setAllowedFileTypes:[NSSound soundUnfilteredFileTypes]];
  
  // [openPanel setDirectory:NSHomeDirectory()];
  [openPanel runModal];
  NSLog(@"Selected file: %@ in %@", [openPanel filename], [openPanel directory]);

  if (file) {
    [file release];
  }
  file = [[NSString alloc] initWithString:[openPanel filename]];
  [openPanel release];
  if (file == nil || [file length] == 0) {
    return;
  }
  
  if (sound != nil) {
    [self stop:stopBtn];
    [sound release];
  }
  
  [songTitle setStringValue:[file lastPathComponent]];
  [self _initSoundWithFile:file];
  [self setWindowTitleForFile:file]; 
  [self setButtonsEnabled:YES];
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
  }
}
- (void)pause:(id)sender
{
  if ([sender isKindOfClass:[NSMenuItem class]]) {
    [pauseBtn setState:![pauseBtn state]];
  }

  
  [sound pause];
  if ([pauseBtn state] == NSOnState) {
    [playBtn setState:NSOffState];
    [stopBtn setState:NSOffState];
    [[[[[NSApp mainMenu] itemWithTitle:@"Sound"] submenu] itemWithTag:2]
      setTitle:@"Resume"];
  }
  else {
    [[[[[NSApp mainMenu] itemWithTitle:@"Sound"] submenu] itemWithTag:2]
      setTitle:@"Pause"];
    [self play:sender];
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
  if ([sender isKindOfClass:[NSMenuItem class]]) {
    [repeatBtn setState:NSOnState];
  }
  [shuffleBtn setState:NSOffState];
}
- (void)shuffle:(id)sender
{
  if ([sender isKindOfClass:[NSMenuItem class]]) {
    [shuffleBtn setState:NSOnState];
  }
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
