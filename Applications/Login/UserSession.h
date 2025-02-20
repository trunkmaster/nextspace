/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Description: Setup and start user desktop session.
//              Process user session requests.
//
// Copyright (C) 2011 Sergii Stoian
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

@class Controller;

@interface UserSession : NSObject
{
  Controller *appController;
  NSDictionary *appDefaults;
  NSMutableArray *sessionScript;
}

@property (assign) dispatch_queue_t run_queue;
@property (assign) BOOL isRunning;
@property (readonly) NSInteger exitStatus;
@property (readonly) NSString *userName;
@property (readonly) NSString *sessionLog;

// ---

- (id)initWithOwner:(Controller *)controller
               name:(NSString *)name
           defaults:(NSDictionary *)defaults;

// ---

- (int)launchCommand:(NSArray *)command logAppend:(BOOL)append wait:(BOOL)isWait;

@end

@interface UserSession (ScriptLaunch)
- (void)readSessionScript;
- (void)launchSessionScript;
@end
