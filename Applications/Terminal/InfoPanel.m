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
  // [NSTimer scheduledTimerWithTimeInterval:2.0
  //                                  target:self
  //                                selector:@selector(showAnimation)
  //                                userInfo:nil
  //                                 repeats:YES];
}

- (void)awakeFromNib
{
  [versionField setStringValue:@"0.98"];
}

- (void)dealloc
{
  [super dealloc];
}

- (void)showAnimation
{
  NSString *mPath = [[NSBundle mainBundle] pathForResource:@"ScrollingMach" ofType:@"tiff"];
  NSImage *scrollingMach = [[NSImage alloc] initWithContentsOfFile:mPath];
  NSImageView *machView;

  machView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 27, 25)];
  [machView setImageScaling:NSScaleNone];
  [machView setImage:[scrollingMach autorelease]];
  [[panel contentView] addSubview:machView];
  [machView release];

  for (int i = 0; i < 10; i++) {
    [machView lockFocus];
    [scrollingMach compositeToPoint:NSMakePoint(0, 0)
                           fromRect:NSMakeRect(0, i, 27, 25)
                          operation:NSCompositeSourceOver];
    [machView unlockFocus];
    // [machView scrollRectToVisible:NSMakeRect(0, i, 27, 25)];
    // [machView setNeedsDisplay:YES];
  }

  // [[panel contentView] removeSubview:machView];
}

@end
