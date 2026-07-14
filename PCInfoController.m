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

#import <ProjectCenter/ProjectCenter.h>

#import "PCInfoController.h"

@implementation PCInfoController

- (id)init
{
  if ((self = [super init]))
    {
      NSString *file;

      file = [[NSBundle mainBundle] pathForResource:@"Info-gnustep" 
	ofType:@"plist"];

      infoDict = [NSDictionary dictionaryWithContentsOfFile:file];
      RETAIN(infoDict);

      if ([NSBundle loadNibNamed:@"Info" owner:self] == NO)
	{
	  return nil;
	}
      [versionField setStringValue:[NSString stringWithFormat:@"Version %@", [infoDict objectForKey:@"ApplicationRelease"]]];
      [copyrightField setStringValue:[infoDict objectForKey:@"Copyright"]];
      [infoWindow center];
    }

  return self;
}

- (void)dealloc
{
  RELEASE(infoDict);

  if (infoWindow) 
    {
      RELEASE(infoWindow);
    }

  [super dealloc];
}

- (void)showInfoWindow:(id)sender
{
  [infoWindow makeKeyAndOrderFront:self];
}

@end
