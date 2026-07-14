/** <title>GormSoundInspector</title>

   <abstract>allow user to select custom classes</abstract>

   Copyright (C) 2002 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: September 2002

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormSoundInspector.h"
#include "GormPrivate.h"
#include "GormClassManager.h"
#include "GormDocument.h"
#include "GormPrivate.h"
#include "GormSoundView.h"
#include "GormSound.h"

@implementation GormSoundInspector
+ (void) initialize
{
  if (self == [GormSoundInspector class])
    {
      // TBD
    }
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];

      // load the gui...
      if (![bundle loadNibNamed: @"GormSoundInspector"
			  owner: self
			topLevelObjects: NULL])
	{
	  NSLog(@"Could not open gorm GormSoundInspector");
	  return nil;
	}
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [super dealloc];
}

- (void) setObject: (id)anObject
{
  // if its not nil, load it...
  if(anObject != nil)
    {
      if([anObject isKindOfClass: [GormSound class]])
	{
	  id snd;

	  NSDebugLog(@"Sound inspector notified: %@",anObject);
	  snd = AUTORELEASE([[NSSound alloc] initWithContentsOfFile: [anObject path]
					     byReference: YES]);
	  [super setObject: snd];
	  [soundView setSound: snd];
	  NSDebugLog(@"Loaded sound");
	}
    }
}

- (void) stop: (id)sender
{
  NSDebugLog(@"Stop");
  [(NSSound *)object stop];
}

- (void) play: (id)sender
{
  NSDebugLog(@"Play");
  [(NSSound *)object play];
}

- (void) pause: (id)sender
{
  NSDebugLog(@"Pause");
  [(NSSound *)object pause];
}

- (void) record: (id)sender
{
  NSDebugLog(@"Record");
  // [object record];
}
@end
