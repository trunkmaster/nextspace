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
#import "TabViewTest.h"

@interface TabView : NSView
{}
@end

@implementation TabView : NSView

// `name` - Left or Right
- (NSImage *)imageForSide:(NSString *)side backgroundColor:(NSColor *)color
{
  NSImage *image = nil;
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *edgePath, *interiorPath;
  NSBitmapImageRep *edgeRep, *interiorRep;
  NSColor *edgeColor, *interiorColor;

  edgePath = [bundle pathForResource:[NSString stringWithFormat:@"TabEdge_%@", side]
                              ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:edgePath];
  edgeRep = (NSBitmapImageRep *)[image bestRepresentationForRect:NSMakeRect(0, 0, 10, 10)
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
      if ([interiorColor alphaComponent] == 1.0) {
        // Apply mask defined by TabInterior_ image to TabEdge_ image
        if ([edgeColor alphaComponent] == 0.0) {
          [edgeRep setColor:color atX:x y:y];
        } else if ([edgeColor alphaComponent] > 0) {
          // On the edge of TabEdge_ images semi-transparent pixels exist - blend it with background
          // color
          NSColor *blendedColor = [color blendedColorWithFraction:[edgeColor alphaComponent]
                                                          ofColor:edgeColor];
          [edgeRep setColor:blendedColor atX:x y:y];
        }
      }
    }
  }

  NSLog(@"Edge rep: bitsPerSample: %li bitsPerPixel: %ld", [edgeRep bitsPerSample],
        [edgeRep bitsPerSample]);

  for (id rep in [image representations]) {
    if ([rep bitsPerSample] == 8) {
      [image removeRepresentation:rep];
    }
  }
  [image addRepresentation:edgeRep];

  return image;
}

// `rect` includes left and right image, white top line, title
- (void)drawTabWithFrame:(NSRect)rect title:(NSString *)title selected:(BOOL)isSelected
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  NSColor *background = isSelected ? [NSColor lightGrayColor] : [NSColor darkGrayColor];
  NSImage *edgeLeft = [self imageForSide:@"Left" backgroundColor:background];
  NSImage *edgeRight = [self imageForSide:@"Right" backgroundColor:background];
  CGFloat titleWidth = rect.size.width - edgeLeft.size.width - edgeRight.size.width;

  // Fill text background
  if (isSelected == NO) {
    DPSsetgray(ctxt, 0.67);
  } else {
    DPSsetgray(ctxt, 0.33);
  }
  // NSLog(@"Background black component: %f", [background blackComponent]);
  // DPSsetgray(ctxt, [background whiteComponent]);
  DPSrectfill(ctxt, rect.origin.x + edgeLeft.size.width, rect.origin.y, titleWidth, rect.size.height - 1);

  // Top white line
  if (isSelected == NO) {
    DPSsetgray(ctxt, 1.0);
  } else {

  }
  DPSmoveto(ctxt, rect.origin.x + edgeLeft.size.width, rect.origin.y + rect.size.height);
  DPSlineto(ctxt, rect.origin.x + edgeLeft.size.width + titleWidth,
            rect.origin.y + rect.size.height);
  DPSstroke(ctxt);

  // edgeLeft = [self imageForSide:@"Left" backgroundColor:background];
  [edgeLeft drawAtPoint:NSMakePoint(rect.origin.x, rect.origin.y)
               fromRect:NSMakeRect(0, edgeLeft.size.height - rect.size.height, edgeLeft.size.width,
                                   rect.size.height)
              operation:NSCompositeSourceOver
               fraction:1.0];

  // edgeRight = [self imageForSide:@"Right" backgroundColor:background];
  [edgeRight drawAtPoint:NSMakePoint((rect.origin.x + rect.size.width) - edgeRight.size.width,
                                     rect.origin.y)
                fromRect:NSMakeRect(0, edgeRight.size.height - rect.size.height,
                                    edgeRight.size.width, rect.size.height)
               operation:NSCompositeSourceAtop
                fraction:1.0];

  [edgeLeft release];
  [edgeRight release];
}

- (void)drawRect:(NSRect)rect
{
  // [super drawRect:rect];

  NSGraphicsContext *ctxt = GSCurrentContext();
  CGFloat tabHeight = 21;
  CGFloat offset = 6;
  CGFloat tabWidth = floorf(rect.size.width / 4) + (22 - offset);

  // Fill view background
  DPSsetgray(ctxt, 0.33);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height);

  // Fill subview background
  DPSsetgray(ctxt, 0.67);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height - offset - tabHeight);

  // Draw unselected
  for (int i = 3; i > 0; i--) {
    [self drawTabWithFrame:NSMakeRect((tabWidth - 22) * i, rect.size.height - offset - tabHeight,
                                      tabWidth, tabHeight)
                     title:@"Unseleccted"
                  selected:NO];
  }

  // White line between views and tabs
  DPSsetgray(ctxt, 1.0);
  DPSmoveto(ctxt, 0, (rect.size.height - offset - tabHeight) + 1);
  DPSlineto(ctxt, rect.size.width, (rect.size.height - offset - tabHeight) + 1);

  DPSstroke(ctxt);

  // Draw selected
  [self drawTabWithFrame:NSMakeRect(0, rect.size.height - offset - tabHeight, tabWidth, tabHeight)
                   title:@"Selected"
                selected:YES];
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
