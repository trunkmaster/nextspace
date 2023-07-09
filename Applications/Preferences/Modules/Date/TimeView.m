/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
// Copyright (C) 2022-2023 Andres Morales
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

#import "TimeView.h"

@implementation TimeView

- (void) drawRect:(NSRect)TimeView
{
  NSRect bounds = [self bounds];
  NSString *imagePath;
  NSBundle *bundle;
  float mx, my;

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource: @"world" ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagePath];

  if (image) {
     for (mx = 0; mx < NSMaxY(bounds); mx += image.size.height) {
         for (my = 0; my < NSMaxX(bounds); my += image.size.width) {
             [image compositeToPoint:NSMakePoint(mx, my)
                           operation:NSCompositeSourceOver];
         }
     }
   } else {
      NSLog(@"Image not found");
     }
}

@end
