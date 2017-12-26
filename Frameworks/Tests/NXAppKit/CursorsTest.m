/*
  Class:               CursorsTest
  Inherits from:       NSObject
  Class descritopn:    Testing GNUstep mouse cursors operations.

  Copyright (c) 2017 Sergii Stoian

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

#import "CursorsTest.h"

@implementation CursorsTest : NSObject

- (id)init
{
  self = [super init];

  if (![NSBundle loadNibNamed:@"Cursors" owner:self])
    {
      NSLog (@"CursorsTest: Could not load nib, aborting.");
      return nil;
    }

  return self;
}

- (void)awakeFromNib
{
  [window center];  
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
