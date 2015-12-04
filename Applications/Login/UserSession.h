/*
   UserSession.h
   Setup and start user desktop session.
   (?) Process user session requests.

   This file is part of CUBE.

   Copyright (C) 2011 

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

@class Controller;

@interface UserSession : NSObject
{
  Controller          *appController;
  NSMutableDictionary *threadDict;

  NSString            *userName;
  NSDictionary        *sessionScript;
}

// ---

- (id)initWithOwner:(Controller *)owner
	     script:(NSDictionary *)script
	       name:(NSString *)name;

- (void)setSessionScript:(NSDictionary *)script;

- (void)setSessionName:(NSString *)name;

// ---

- (NSString *)sessionName;

- (void)launchSession;

- (BOOL)setUserEnvironment;

- (int)launchCommand:(NSArray *)command;

@end

