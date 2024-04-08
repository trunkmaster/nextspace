/*
  Project: Terminal

  Copyright (c) 2024-present Sergii Stoian <stoyan255@gmail.com>

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

#import <AppKit/AppKit.h>

@interface TerminalIcon : NSImageView
{
  NSTextFieldCell *titleCell;
  CGFloat yPosition;
}
@property (readwrite, assign) BOOL isMiniWindow;
@property (readwrite, assign) BOOL isAnimates;
@property (readwrite, assign) NSImage *iconImage;
@property (readwrite, assign) NSImage *scrollingImage;
@property (readwrite, assign) NSRect scrollingRect;

- (instancetype)initWithFrame:(NSRect)rect scrollingFrame:(NSRect)scrollingRect;
- (void)setTitle:(NSString *)title;
- (void)animate;

@end
