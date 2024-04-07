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

#import <AppKit/AppKit.h>
#import "TerminalIcon.h"

@interface InfoPanel : NSObject
{
  id panel;
  id versionField;
  id appIcon;

  TerminalIcon *machView;
  NSTimer *animationTimer;
  NSTimer *iconTimer;
}

- (void)activatePanel;
- (void)closePanel;

@end
