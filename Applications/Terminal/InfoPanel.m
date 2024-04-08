/*
  Class:               InfoPanel
  Inherits from:       NSObject
  Class descritopn:    Panel to show information about application.
                       Called from menu Info->Info Panel...

  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "InfoPanel.h"
#import "Controller.h"

@implementation InfoPanel : NSObject

- (void)activatePanel
{
  if (panel == nil) {
    if (![NSBundle loadNibNamed:@"Info" owner:self]) {
      NSLog(@"Failed to load Info.gorm");
      return;
    }
    [panel center];
  }
  [panel makeKeyAndOrderFront:self];

  if (iconTimer == nil) {
    iconTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                 target:self
                                               selector:@selector(animateAppIcon)
                                               userInfo:nil
                                                repeats:YES];
  }
}

- (void)closePanel
{
  if (iconTimer && [iconTimer isValid]) {
    [iconTimer invalidate];
  }
  [panel close];
  [panel release];
}

- (void)awakeFromNib
{
  NSString *scrImagePath = [[NSBundle mainBundle] pathForResource:@"ScrollingMach" ofType:@"tiff"];

  [versionField setStringValue:@"0.98"];

  machView = [[TerminalIcon alloc] initWithFrame:[appIcon frame]
                                  scrollingFrame:NSMakeRect(13, 17, 27, 23)];
  [machView setImageScaling:NSScaleNone];
  machView.iconImage = [NSApp applicationIconImage];
  machView.scrollingImage = [[NSImage alloc] initWithContentsOfFile:scrImagePath];
  [[panel contentView] replaceSubview:appIcon with:machView];
  [machView release];
}

- (void)dealloc
{
  [animationTimer invalidate];
  [super dealloc];
}

- (void)animateAppIcon
{
  if ([panel isVisible] == NO) {
    machView.isAnimates = NO;
    [iconTimer invalidate];
    iconTimer = nil;
  }
  machView.isAnimates = YES;
  if (animationTimer == nil) {
    animationTimer = [NSTimer timerWithTimeInterval:0.1
                                             target:machView
                                           selector:@selector(animate)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:animationTimer forMode:NSDefaultRunLoopMode];
  }
  [animationTimer fire];
}

@end
