/*
   The icon sliding effect preferences.

   Copyright (C) 2005 Saso Kiselkov

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>
#import "EffectPrefs.h"

@implementation EffectPrefs

- (NSString *) moduleName
{
        return _(@"Effects");
}

- (NSView *) view
{
        if (box == nil)
                [NSBundle loadNibNamed: @"EffectPrefs" owner: self];

        return box;
}

- (void) dealloc
{
        TEST_RELEASE(box);

        [super dealloc];
}

- (void) awakeFromNib
{
        NXDefaults * df = [NXDefaults userDefaults];

        [box retain];
        [box removeFromSuperview];
        DESTROY(bogusWindow);
	
	[slideOnBadFop setRefusesFirstResponder:YES];
	[slideFromShelf setRefusesFirstResponder:YES];
	[slideWhenOpening setRefusesFirstResponder:YES];

        [slideFromShelf setState:![df boolForKey:
          @"DontSlideIconsFromShelf"]];
        [slideWhenOpening setState: ![df boolForKey:
          @"DontSlideIconsWhenOpening"]];
        [slideOnBadFop setState: ![df boolForKey:
          @"DontSlideIconBackOnBadFop"]];
}

- (void) setSlidesWhenChangingPath: (id)sender
{
        [[NXDefaults userDefaults]
          setBool:![slideFromShelf state]
           forKey:@"DontSlideIconsFromShelf"];
}


- (void) setSlidesBackOnBadOperation: (id)sender
{
        [[NXDefaults userDefaults]
          setBool:![slideOnBadFop state]
           forKey:@"DontSlideIconBackOnBadFop"];
}


- (void) setSlidesWhenOpeningFile: (id)sender
{
        [[NXDefaults userDefaults]
          setBool:![slideWhenOpening state]
           forKey:@"DontSlideIconsWhenOpening"];
}

@end
