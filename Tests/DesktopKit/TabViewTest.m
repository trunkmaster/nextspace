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
@property (readwrite, copy) NSColor *unselectedBackgroundColor;
@property (readwrite, copy) NSColor *selectedBackgroundColor;
@end

@implementation TabView : NSView

// `name` - Left or Right
- (NSImage *)imageForSide:(NSString *)side
          backgroundColor:(NSColor *)color
                 selected:(BOOL)isSelected
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

  // NSLog(@"Image %@ - %@", [edgePath lastPathComponent], NSStringFromSize(edgeRep.size));

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
      } else if ([edgeColor alphaComponent] > 0 && [_unselectedBackgroundColor whiteComponent] < 0.5) {
        if (isSelected == NO && [side isEqualToString:@"Left"]) {
          [edgeRep setColor:[edgeColor colorWithAlphaComponent:0.505] atX:x y:y];
        }
      }
    }
  }

  // NSLog(@"Edge rep: bitsPerSample: %li bitsPerPixel: %ld", [edgeRep bitsPerSample],
  //       [edgeRep bitsPerSample]);

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
  NSColor *background = isSelected ? _selectedBackgroundColor : _unselectedBackgroundColor;
  NSImage *edgeLeft = [self imageForSide:@"Left" backgroundColor:background selected:isSelected];
  NSImage *edgeRight = [self imageForSide:@"Right" backgroundColor:background selected:isSelected];
  CGFloat titleWidth = rect.size.width - edgeLeft.size.width - edgeRight.size.width;

  NSLog(@"Draw tab with width: %f, left edge: %f, right edge: %f", rect.size.width,
        edgeLeft.size.width, edgeRight.size.width);

  {
    NSRect titleRect = NSMakeRect(rect.origin.x + edgeLeft.size.width, rect.origin.y, titleWidth,
                                  rect.size.height - 1);
    NSPoint titlePosition;
    NSFont *textFont = [NSFont systemFontOfSize:12];

    // Fill text background
    DPSsetgray(ctxt, [background whiteComponent]);
    DPSrectfill(ctxt, titleRect.origin.x, titleRect.origin.y, titleRect.size.width,
                titleRect.size.height);

    titlePosition = NSMakePoint(
        titleRect.origin.x + (titleRect.size.width - [textFont widthOfString:title]) / 2,
        titleRect.origin.y + (titleRect.size.height - [textFont defaultLineHeightForFont]) / 2);
    [title drawAtPoint:titlePosition
        withAttributes:@{
          NSForegroundColorAttributeName : [NSColor blackColor],
          NSFontAttributeName : textFont
        }];
  }

  [edgeLeft drawAtPoint:NSMakePoint(rect.origin.x, rect.origin.y)
               fromRect:NSMakeRect(0, edgeLeft.size.height - rect.size.height, edgeLeft.size.width,
                                   rect.size.height)
              operation:NSCompositeSourceOver
               fraction:1.0];

  [edgeRight drawAtPoint:NSMakePoint((rect.origin.x + rect.size.width) - edgeRight.size.width,
                                     rect.origin.y)
                fromRect:NSMakeRect(0, edgeRight.size.height - rect.size.height,
                                    edgeRight.size.width, rect.size.height)
               operation:NSCompositeSourceAtop
                fraction:1.0];

  // Top white line
  if (isSelected != NO || (_unselectedBackgroundColor.whiteComponent > 0.4)) {
    DPSsetgray(ctxt, 1.0);
  } else {
    DPSsetgray(ctxt, 0.67);
  }
  DPSmoveto(ctxt, rect.origin.x + edgeLeft.size.width - 2, rect.origin.y + rect.size.height);
  DPSlineto(ctxt, rect.origin.x + edgeLeft.size.width + titleWidth + 2,
            rect.origin.y + rect.size.height);

  DPSstroke(ctxt);

  [edgeLeft release];
  [edgeRight release];  
}

- (void)drawRect:(NSRect)rect
{
  // NSLog(@"Unselected background color: %f", [_unselectedBackgroundColor whiteComponent]);
  // NSLog(@"Selected background color: %@", _selectedBackgroundColor);

  NSGraphicsContext *ctxt = GSCurrentContext();
  CGFloat tabHeight = 45;
  CGFloat tabOverlap = 22;
  CGFloat offset = 6;
  // CGFloat tabWidth = floorf([self frame].size.width / 5);
  int tabCount = 4;
  CGFloat tabWidth = (([self frame].size.width + (tabOverlap * (tabCount - 1))) / tabCount);

  NSLog(@"TabView frame: %@, Tab width: %f", NSStringFromRect([self frame]), tabWidth);

  // Fill top view background
  DPSsetgray(ctxt, [_unselectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height);

  // Fill subview background
  DPSsetgray(ctxt, [_selectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height - offset - tabHeight);

  // Draw unselected
  NSString *title;
  for (int i = tabCount - 1; i > 0; i--) {
    switch (i) {
      case 3:
        title = @"Images";
        break;
      case 2:
        title = @"Sounds";
        break;
      case 1:
        title = @"Classes";
        break;
    }
    [self drawTabWithFrame:NSMakeRect((tabWidth - tabOverlap) * i, rect.size.height - offset - tabHeight,
                                      tabWidth, tabHeight)
                     title:title
                  selected:NO];
  }

  // White line between views and tabs
  NSDrawButton(NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width,
                          (rect.size.height - offset - tabHeight) + 1),
               NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width,
                          (rect.size.height - offset - tabHeight) + 1));
  // DPSsetgray(ctxt, 1.0);
  // DPSmoveto(ctxt, 0, (rect.size.height - offset - tabHeight) + 1);
  // DPSlineto(ctxt, rect.size.width, (rect.size.height - offset - tabHeight) + 1);
  DPSstroke(ctxt);


  // Draw selected
  [self drawTabWithFrame:NSMakeRect(0, rect.size.height - offset - tabHeight, tabWidth,
                                    tabHeight)
                   title:@"Instances"
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

  // TabView *tabView = [[TabView alloc] initWithFrame:NSMakeRect(0, 0, 355, 240)];
  TabView *tabView = [[TabView alloc] initWithFrame:NSMakeRect(6, 6, 343, 234)];
  tabView.unselectedBackgroundColor = [NSColor lightGrayColor];
  tabView.selectedBackgroundColor = [NSColor lightGrayColor];
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
