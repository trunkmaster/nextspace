/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <AppKit/AppKit.h>

@interface WMPermissions : NSView
{
  BOOL displaysExecute;

  unsigned long mode;
  unsigned long nochange;

  NSImage *check;
  NSImage *cross;
  NSImage *dash;

  id target;
  SEL action;

  BOOL editable;
}

- initWithFrame:(NSRect)frame;

- (void)setMode:(unsigned)mod;
- (unsigned)mode;
- (void)setNoChangeMask:(unsigned)mask;
- (unsigned)noChangeMask;

- (void)setDisplaysExecute:(BOOL)flag;
- (BOOL)displaysExecute;

- (void)setTarget:aTarget;
- target;

- (void)setAction:(SEL)anAction;
- (SEL)action;

- (void)setEditable:(BOOL)flag;
- (BOOL)isEditable;

@end
