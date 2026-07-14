/** <title>GormSoundView</title>

   <abstract>Visualizes a sound.<abstract>

   Copyright (C) 2004 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: May 2004

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
#include <AppKit/PSOperators.h>

#include "GormSoundView.h"

// add a data method to the NSSound class...
@interface NSSound (SoundView)
- (NSData *)data;
@end

@implementation NSSound (SoundView)
- (NSData *)data
{
  return _data;
}
@end

/*
static float findMax(NSData *data)
{
  float max = 0.0;
  NSInteger index = 0;
  float *array = (float *)[data bytes];
  NSInteger len = [data length];

  // find the maximum...
  for(index = 0; index < len; index++)
    {
      float d = array[index];
      if(d > max)
	{
	  max = d;
	}
    }

  return max;
}
*/

@implementation GormSoundView
- (void) setSound: (NSSound *)sound
{
  NSLog(@"Set sound...");
  ASSIGN(_sound,sound);
  [self setNeedsDisplay: YES];
}

- (NSSound *)sound
{
  return _sound;
}

/*
- (void) drawRect: (NSRect)aRect
{
  float w = aRect.size.width;
  float h = aRect.size.height;
  float offset = (h/2);
  NSData *soundData = [_sound data];
  float *data = 0;
  float x1 = 0, x2 = 0, y1 = offset, y2 = offset;
  float max = findMax(soundData);
  float multiplier = h/max;
  NSInteger length = [soundData length];
  NSInteger index = 0;
  NSInteger step = (length/(int)w);

  [super drawRect: aRect];
  
  PSsetrgbcolor(1.0,0,0); // red
  data = (float *)[soundData bytes];
  
  if( length > 2 )
    {

      x1 = (data[0] * multiplier);
      y1 = offset; 
      for(index = step; index < w; index+=step)
	{
	  NSInteger i = (int)index;
	  float d = data[i];
	  
	  // calc new position...
	  x2 = d * multiplier;
	  y2 = index + offset;

	  PSmoveto(x1,y1);
	  PSlineto(x2,y2);
	  
	  // move to old vars...
	  x1 = x2;
	  y1 = y2;
	}
    }
}
*/
@end
