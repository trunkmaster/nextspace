/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description:
//
// Copyright (C) 2005 Saso Kiselkov
// Copyright (C) 2014 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "IconPrefs.h"
#import <SystemKit/OSEDefaults.h>

#define DEFAULT_LABEL_WIDTH 100

static inline NSRect IncrementedRect(NSRect r)
{
  r.origin.x--;
  r.origin.y--;
  r.size.width += 2;
  r.size.height += 2;

  return r;
}

@interface IconPrefs (Private)

- (void)setupArrows;

@end

@implementation IconPrefs (Private)

- (void)setupArrows
{
  NSRect frame;
  NSSize s = [[leftArr superview] frame].size;
  float width;
  OSEDefaults *df = [OSEDefaults userDefaults];

  if ([df objectForKey:@"IconSlotWidth"]) {
    width = [df floatForKey:@"IconSlotWidth"];
  } else {
    width = DEFAULT_LABEL_WIDTH;
  }

  if (width == DEFAULT_LABEL_WIDTH) {
    [button setEnabled:NO];
  } else {
    [button setEnabled:YES];
  }

  frame = [leftArr frame];
  frame.origin.x = s.width / 2 - width / 2 - frame.size.width;
  [leftArr setFrame:frame];

  frame = [rightArr frame];
  frame.origin.x = s.width / 2 + width / 2;
  [rightArr setFrame:frame];

  frame = [iconLabel frame];
  frame.origin.x = [leftArr frame].origin.x + [leftArr frame].size.width;
  frame.size.width = ([rightArr frame].origin.x - frame.origin.x);
  [iconLabel setFrame:frame];
  [[iconLabel superview] setNeedsDisplay:YES];
}

@end

@implementation IconPrefs

- (void)dealloc
{
  NSDebugLLog(@"IconPrefs", @"IconPrefs: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  TEST_RELEASE(box);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSRect frame;
  NSRect shortLabelFrame;
  NSRect box2Frame;

  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];
  DESTROY(bogusWindow);

  // configure the arrows
  box2Frame = [[box2 contentView] frame];

  [iconImage setImage:[NSImage imageNamed:@"GNUstep48x48"]];
  [iconLabel setStringValue:@"Workspace.app"];

  [self setupArrows];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(changedSelection:)
                                               name:@"FileViewerDidChangeSelectionNotification"
                                             object:nil];
}

- (NSString *)moduleName
{
  return _(@"Icon View");
}

- (NSView *)view
{
  if (box == nil) {
    [NSBundle loadNibNamed:@"IconPrefs" owner:self];
  }

  return box;
}

- (BOOL)arrowView:(NXTSizer *)sender shouldMoveByDelta:(float)delta
{
  NSView *superview = [sender superview];
  NSSize s = [superview frame].size;
  NSRect arrowFrame;
  NSRect textFrame = [iconLabel frame];
  float diff;
  unsigned newWidth;

  if (sender == rightArr) {
    arrowFrame = [rightArr frame];

    diff = (arrowFrame.origin.x + delta) - s.width / 2;

    if (diff <= 40 || diff >= 100)
      return NO;

    textFrame.origin.x = textFrame.origin.x - delta;

    arrowFrame = [leftArr frame];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
    arrowFrame.origin.x = s.width / 2 - diff - arrowFrame.size.width;
    [leftArr setFrame:arrowFrame];
    [leftArr setNeedsDisplay:YES];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
  } else {
    arrowFrame = [leftArr frame];

    diff = s.width / 2 - (arrowFrame.origin.x + delta + arrowFrame.size.width);

    if (diff <= 40 || diff >= 100)
      return NO;

    textFrame.origin.x = textFrame.origin.x + delta;

    arrowFrame = [rightArr frame];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
    arrowFrame.origin.x = s.width / 2 + diff;
    [rightArr setFrame:arrowFrame];
    [rightArr setNeedsDisplay:YES];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
  }

  newWidth = diff * 2;

  textFrame.size.width = newWidth;
  [iconLabel setFrame:textFrame];

  [iconLabel setStringValue:NXTShortenString(@"Workspace.app", newWidth - 4, [iconLabel font],
                                             NXSymbolElement, NXTDotsAtRight)];
  if (newWidth == DEFAULT_LABEL_WIDTH)
    [button setEnabled:NO];
  else
    [button setEnabled:YES];

  return YES;
}

- (void)arrowViewStoppedMoving:(NXTSizer *)sender
{
  [[OSEDefaults userDefaults] setFloat:[iconLabel frame].size.width forKey:@"IconSlotWidth"];

  [[NSNotificationCenter defaultCenter] postNotificationName:@"IconSlotWidthDidChangeNotification"
                                                      object:self];
}

- (void)revert:sender
{
  [[OSEDefaults userDefaults] setFloat:DEFAULT_LABEL_WIDTH forKey:@"IconSlotWidth"];
  [self setupArrows];

  [[NSNotificationCenter defaultCenter] postNotificationName:@"IconSlotWidthDidChangeNotification"
                                                      object:self];
}

- (void)changedSelection:(NSNotification *)notif
{
  NSString *path;
  NSArray *selection;
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];

  path = [[notif userInfo] objectForKey:@"Path"];
  selection = [[notif userInfo] objectForKey:@"Selection"];

  if ([selection count] == 0) {
    [icon setIconImage:[ws iconForFile:path]];
    if ([path isEqualToString:@"/"]) {
      [icon setLabelString:[[NSHost currentHost] name]];
    } else {
      [icon setLabelString:[path lastPathComponent]];
    }
  } else if ([selection count] == 1) {
    path = [path stringByAppendingPathComponent:[selection objectAtIndex:0]];
    [icon setIconImage:[ws iconForFile:path]];
    [icon setLabelString:[path lastPathComponent]];
  } else {
    [icon setIconImage:[NSImage imageNamed:@"MultipleSelection"]];
    [icon setLabelString:[NSString stringWithFormat:_(@"%lu Elements"), [selection count]]];
  }
}

@end
