/*
  Descritopn: Testing GNUstep drawing operations.

  Copyright (c) 2019 Sergii Stoian

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
#include "Foundation/NSObjCRuntime.h"
#include "AppKit/NSWindow.h"
#import "TabViewTest.h"

@interface TabView : NSView
{}
@end

@implementation TabView : NSView

// `name` - Left or Right
- (NSImage *)imageForSide:(NSString *)side backgroundColor:(NSColor *)color
{
  NSImage *image = nil;
  NSString *imagePath;
  NSArray *representations = [image representations];
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *edgePath, *interiorPath;
  NSBitmapImageRep *edgeRep, *interiorRep;
  NSColor *edgeColor, *interiorColor;

  imagePath = [bundle pathForResource:[NSString stringWithFormat:@"TabEdge_%@", side]
                               ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  edgePath = [bundle pathForResource:[NSString stringWithFormat:@"TabEdge_%@", side]
                              ofType:@"tiff"];
  edgeRep = (NSBitmapImageRep *)[image bestRepresentationForRect:NSMakeRect(100, 100, 10, 10)
                                                         context:GSCurrentContext()
                                                           hints:NULL];
  
  interiorPath = [bundle pathForResource:[NSString stringWithFormat:@"TabInterior_%@", side]
                                  ofType:@"tiff"];
  interiorRep = (NSBitmapImageRep *)[NSImageRep imageRepWithContentsOfFile:interiorPath];

  NSLog(@"Image %@ - %@", [edgePath lastPathComponent], NSStringFromSize(edgeRep.size));

  for (int x = 0; x < interiorRep.size.width; x++) {
    for (int y = 0; y < interiorRep.size.height; y++) {
      interiorColor = [interiorRep colorAtX:x y:y];
      edgeColor = [edgeRep colorAtX:x y:y];
      if ([interiorColor alphaComponent] == 1.0 && [edgeColor alphaComponent] == 0.0) {
        [edgeRep setColor:color atX:x y:y];
      }
    }
  }

  NSLog(@"Edge rep: bitsPerSample: %li bitsPerPixel: %ld", [edgeRep bitsPerSample],
        [edgeRep bitsPerSample]);

  for (id rep in representations) {
    if ([rep bitsPerSample] == 8) {
      [image removeRepresentation:rep];
    }
  }
  [image addRepresentation:edgeRep];

  return image;
}

- (void)drawRect:(NSRect)rect
{
  // [super drawRect:rect];

  NSGraphicsContext *ctxt = GSCurrentContext();
  NSColor *selectedBackground = [NSColor lightGrayColor];
  NSColor *unselectedBackground = [NSColor darkGrayColor];
  NSImage *edgeLeft;
  NSImage *edgeRight;
  CGFloat tabHeight = 21;
  CGFloat tabWidth = 60;
  CGFloat offset = 6;

  // Fill view background
  DPSsetgray(ctxt, 0.33);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height);

  // // Fill text background
  // DPSsetgray(ctxt, 0.66);
  // DPSrectfill(ctxt, offset + edgeLeft.size.width, rect.size.height - offset,
  //             40 - edgeLeft.size.width, tabHeight);

  // DPSsetgray(ctxt, 1.0);
  // DPSmoveto(ctxt, offset + edgeLeft.size.width, rect.size.height - offset);
  // DPSlineto(ctxt, offset + edgeLeft.size.width + 40, rect.size.height - offset);
  // DPSstroke(ctxt);


  edgeLeft = [self imageForSide:@"Left" backgroundColor:selectedBackground];
  [edgeLeft
      drawAtPoint:NSMakePoint(0, rect.size.height - offset - tabHeight)
         fromRect:NSMakeRect(0, edgeLeft.size.height - tabHeight, edgeLeft.size.width, tabHeight)
        operation:NSCompositeSourceOver
         fraction:1.0];
  // Left white line
  DPSsetgray(ctxt, 0.95);
  DPSmoveto(ctxt, 0, (rect.size.height - offset - tabHeight) + 1);
  DPSlineto(ctxt, offset + 2, (rect.size.height - offset - tabHeight) + 1);
  // Fill text background
  DPSsetgray(ctxt, 0.66);
  DPSrectfill(ctxt, edgeLeft.size.width, rect.size.height - offset - tabHeight, tabWidth,
              tabHeight);
  // Top white line
  DPSsetgray(ctxt, 1.0);
  DPSmoveto(ctxt, edgeLeft.size.width, rect.size.height - offset);
  DPSlineto(ctxt, edgeLeft.size.width + tabWidth, rect.size.height - offset);
  DPSstroke(ctxt);
  [edgeLeft release];

  edgeLeft = [self imageForSide:@"Left" backgroundColor:unselectedBackground];
  [edgeLeft
      drawAtPoint:NSMakePoint(edgeLeft.size.width + tabWidth,
                              rect.size.height - offset - tabHeight)
         fromRect:NSMakeRect(0, edgeLeft.size.height - tabHeight, edgeLeft.size.width, tabHeight)
        operation:NSCompositeSourceOver
         fraction:1.0];
  [edgeLeft release];

  edgeRight = [self imageForSide:@"Right" backgroundColor:selectedBackground];
  [edgeRight
      drawAtPoint:NSMakePoint(edgeRight.size.width + tabWidth,
                              rect.size.height - offset - tabHeight)
         fromRect:NSMakeRect(0, edgeRight.size.height - tabHeight, edgeRight.size.width, tabHeight)
        operation:NSCompositeSourceAtop
         fraction:1.0];
  [edgeRight release];
}

@end

@implementation TabViewTest : NSObject

- (id)init
{
  window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 355, 240)
                                       styleMask:(NSTitledWindowMask | NSResizableWindowMask |
                                                  NSClosableWindowMask | NSMiniaturizableWindowMask)
                                         backing:NSBackingStoreRetained
                                           defer:YES];
  [window setMinSize:NSMakeSize(355, 240)];
  [window setTitle:@"TabView test"];
  [window setReleasedWhenClosed:YES];
  [window setDelegate:self];

  tabView = [[TabView alloc] initWithFrame:NSMakeRect(0, 0, 355, 240)];
  [[window contentView] addSubview:tabView];

  [window center];
  [window orderFront:nil];
  [window makeKeyWindow];

  return self;
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
