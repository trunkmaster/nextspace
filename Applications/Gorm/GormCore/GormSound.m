/* GormSound.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	Dec 2004
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormSound.h"

// sound proxy object...
@implementation GormSound
+ (GormSound*) soundForPath: (NSString *)aPath
{
  return [GormSound soundForPath: aPath inWrapper: NO];
}

+ (GormSound*) soundForPath: (NSString *)aPath inWrapper: (BOOL)flag
{
  return AUTORELEASE([[GormSound alloc] initWithPath: aPath inWrapper: flag]);
}

+ (GormSound*)soundForData: (NSData *)aData withFileName: (NSString *)aName inWrapper: (BOOL)flag
{
  return AUTORELEASE([[GormSound alloc] initWithData: aData withFileName: aName inWrapper: flag]);
}

- (id) initWithData: (NSData *)aData withFileName: (NSString *)aName inWrapper: (BOOL)flag
{
  if((self = [super initWithData: aData withFileName: aName inWrapper: flag]))
    {
      // ASSIGN(sound, AUTORELEASE([[NSImage alloc] initWithData: aData]));
    }
  return self;
}

- (id) initWithName: (NSString *)aName
	       path: (NSString *)aPath
	  inWrapper: (BOOL)flag
{
  if((self = [super initWithName: aName path: aPath inWrapper: flag]) != nil)
    {
      NSSound *sound = [[NSSound alloc] initWithContentsOfFile: aPath
					byReference: YES];
      
      [(NSSound *)sound setName: aName]; // cache the sound under the given name.
    }
  return self;
}
@end

@implementation GormSound (IBObjectAdditions)
- (NSString *)inspectorClassName
{
  return @"GormSoundInspector";
}

- (NSString *) classInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString *) connectInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString *) objectNameForInspectorTitle
{
  return @"Sound";
}

- (NSImage *) imageForViewer
{
  static NSImage	*image = nil;

  if (image == nil)
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      NSString	*bpath = [bundle pathForImageResource: @"GormSound"];

      image = [[NSImage alloc] initWithContentsOfFile: bpath];
    }
  return image;
}
@end
