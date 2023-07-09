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

#import "Calendar.h"

@implementation Calendar

- (void) drawRect:(NSRect)calendar
{
  NSString *imagePathWeek, *imagePathDay;
  NSBundle *bundleWeek,*bundleDay;
  int n,x=0;

  bundleWeek = [NSBundle bundleForClass:[self class]];
  imagePathWeek = [bundleWeek pathForResource: @"weeks" ofType: @"tiff"];
  imageWeek = [[NSImage alloc] initWithContentsOfFile: imagePathWeek];

  bundleDay = [NSBundle bundleForClass:[self class]];
  imagePathDay = [bundleDay pathForResource: @"days" ofType: @"tiff"];
  imageDay = [[NSImage alloc] initWithContentsOfFile: imagePathDay];

  if (imageWeek) {
     [imageWeek compositeToPoint:NSMakePoint(0, 0)
                       operation:NSCompositeSourceOver];

       for (n=1; n<=109; n+=18) {
           [imageDay drawAtPoint:NSMakePoint(n,82)
                        fromRect:NSMakeRect(x,91,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //1

           [imageDay drawAtPoint:NSMakePoint(n,66)
                        fromRect:NSMakeRect(x,78,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //2

           [imageDay drawAtPoint:NSMakePoint(n,50)
                        fromRect:NSMakeRect(x,65,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //3

           [imageDay drawAtPoint:NSMakePoint(n,34)
                        fromRect:NSMakeRect(x,52,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //4

           [imageDay drawAtPoint:NSMakePoint(n,18)
                        fromRect:NSMakeRect(x,39,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //5

           [imageDay drawAtPoint:NSMakePoint(n,2)
                        fromRect:NSMakeRect(x,26,17,13)
                       operation:NSCompositeHighlight
                        fraction:1.0]; //6
            x+=17;       
       }
  } else {
      [[NSColor redColor] set];
      NSLog(@"Image not found");
     }
}

@end
