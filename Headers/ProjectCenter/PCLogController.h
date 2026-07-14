/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001 Free Software Foundation

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _PCLOGCONTROLLER_H
#define _PCLOGCONTROLLER_H

#import <AppKit/AppKit.h>

#define INFO	0
#define STATUS	1
#define WARNING	2
#define ERROR	3

// --- Functions
void
PCLog(id sender, int tag, NSString* format, va_list args);
void
PCLogInfo(id sender, NSString* format, ...);
void
PCLogStatus(id sender, NSString* format, ...);
void
PCLogWarning(id sender, NSString* format, ...);
void
PCLogError(id sender, NSString* format, ...);


@interface PCLogController : NSObject
{
  IBOutlet NSPanel    *panel;
  IBOutlet NSTextView *textView;

  NSMutableDictionary *textAttributes;
}

+ (PCLogController *)sharedLogController;

- (void)showPanel;
- (void)logMessage:(NSString *)message withTag:(int)tag sender:(id)sender;
- (void)putMessageOnScreen:(NSAttributedString *)message;

@end

#endif
