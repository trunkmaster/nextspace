/* Implementation of class NSDockTile
   Copyright (C) 2019-2023 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
       Riccardo Mottola <rm@gnu.org>

   Date: Sat Nov 16 21:11:06 EST 2019

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "AppKit/NSApplication.h"
#import "AppKit/NSDockTile.h"
#import "AppKit/NSView.h"
#import "AppKit/NSImage.h"
#import "AppKit/NSImageRep.h"
#import "AppKit/NSCustomImageRep.h"
#import "AppKit/NSFont.h"
#import "AppKit/NSStringDrawing.h"
#import "AppKit/NSAttributedString.h"
#import "AppKit/NSBezierPath.h"


#import "GNUstepGUI/GSTheme.h"
#import "GNUstepGUI/GSDisplayServer.h"

@implementation NSDockTile

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      NSImageRep *_imageRep;
      GSDisplayServer *server = GSCurrentServer();
      NSSize size = [server iconSize]; 
      NSRect rect = NSMakeRect(0, 0, size.width, size.height);
      
      _size = size;
      _contentView = [[NSView alloc] initWithFrame: rect];
      _badgeLabel = nil;
      _owner = nil;
      _showsApplicationBadge = YES;
      _appIconImage = [NSImage imageNamed: @"NSApplicationIcon"];
      RETAIN(_appIconImage);
      _imageRep = [[NSCustomImageRep alloc] initWithDrawSelector: @selector(draw) delegate: self];
      [_imageRep setSize: [_appIconImage size]];
      _dockTileImage = [[NSImage alloc] initWithSize: [_appIconImage size]];
      [_dockTileImage setCacheMode: NSImageCacheNever]; // Only needed because NSImage caches NSCustomImageReps
      [_dockTileImage addRepresentation: _imageRep];
      RELEASE(_imageRep);
      [NSApp setApplicationIconImage: _dockTileImage];
    }
  return self;
}

- (oneway void) release
{
  RELEASE(_contentView);
  RELEASE(_badgeLabel);
  RELEASE(_appIconImage);
  RELEASE(_dockTileImage);
  [super release];
}

- (NSView *) contentView
{
  return _contentView;
}

- (void) setContentView: (NSView *)contentView
{
  ASSIGN(_contentView, contentView);
}

- (NSSize) size
{
  return _size;
}

- (id) owner
{
  return _owner;
}

- (void) setOwner: (id)owner
{
  _owner = owner; // weak...
}

- (BOOL) showsApplicationBadge
{
  return _showsApplicationBadge;
}

- (void) setShowsApplicationBadge: (BOOL)flag
{
  _showsApplicationBadge = flag;
  [self display];
}

- (NSString *) badgeLabel
{
  return _badgeLabel;
}

- (void) setBadgeLabel: (NSString *)label
{
  ASSIGNCOPY(_badgeLabel, label);
  [self display];
}

- (void) display
{
  [_contentView setNeedsDisplay: YES];
}

- (void)draw
{
  [_appIconImage compositeToPoint: NSZeroPoint operation: NSCompositeCopy];

  if (_showsApplicationBadge && _badgeLabel)
    {
      NSMutableDictionary *attrs;
      NSPoint textLocation;
      NSRect discRect;
      NSSize discSize;
      NSSize textSize;
      int pad;
      NSBezierPath *p;
      NSPoint point;
      CGFloat radius;
      NSSize imageSize;
      NSColor *badgeBackColor;
      NSColor *badgeDecorationColor;
      NSColor *badgeTextColor;
      NSString *displayString;

      badgeBackColor = [[GSTheme theme] badgeBackgroundColor];
      badgeDecorationColor = [[GSTheme theme] badgeDecorationColor];
      badgeTextColor = [[GSTheme theme] badgeTextColor];

      imageSize = [_appIconImage size];

      displayString = _badgeLabel;
      if ([_badgeLabel length] > 5)
	{
	  displayString = [NSString stringWithFormat: @"%@\u2026%@", [_badgeLabel substringToIndex: 2], [_badgeLabel substringFromIndex: [_badgeLabel  length]-2]];
	}

      attrs = [[NSMutableDictionary alloc] init];
      [attrs setObject: [NSFont boldSystemFontOfSize: imageSize.width/5]  forKey: NSFontAttributeName];
      [attrs setObject: badgeTextColor  forKey: NSForegroundColorAttributeName];

      textSize = [displayString sizeWithAttributes: attrs];

      pad = imageSize.width / 10;
      discSize = textSize;
      if (discSize.width < 12)
	{
	  discSize.width = 12;
	}
      discSize.height += pad;
      discSize.width += pad;

      discRect = NSMakeRect(imageSize.width - discSize.width,
			     imageSize.height - discSize.height,
			     discSize.width,
			     discSize.height);

      textLocation = NSMakePoint(imageSize.width -  discSize.width + (discSize.width - textSize.width)/2,
				 imageSize.height - discSize.height + (discSize.height - textSize.height)/2);

      radius = discRect.size.height / 2.0;
      point = discRect.origin;
      point.x += radius;
      point.y += radius - 0.5;

      // left half-circle
      p = [NSBezierPath bezierPath];
      [p appendBezierPathWithArcWithCenter: point
				    radius: radius
				startAngle: 90.0
				  endAngle: 270.0];

      // line to first point and right halfcircle
      point.x += discRect.size.width - discRect.size.height;
      [p appendBezierPathWithArcWithCenter: point
				    radius: radius
				startAngle: 270.0
				  endAngle: 90.0];
      [p closePath];

      [badgeBackColor set];
      [p fill];

      [p setLineWidth: 1.5];
      [badgeDecorationColor set];
      [p stroke];

      [displayString drawAtPoint: textLocation  withAttributes: attrs];

      RELEASE(attrs);
    }
}

@end
