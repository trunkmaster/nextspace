/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2024 Sergii Stoian
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

#import "NXTTabView.h"

@implementation NXTTabView

#pragma mark - Overridings

- (BOOL)isFlipped
{
  return NO;
}

- (NSSize)minimumSize
{
  return NSMakeSize(3, 21);
}

#pragma mark - Drawing

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

// - (void)drawTabTitleForItem:(NSTabViewItem *)item withFrame:(NSRect)titleRect
- (void)drawTabTitle:(NSString *)title
           withFrame:(NSRect)titleRect
          background:(NSColor *)background
          foreground:(NSColor *)foreground
{
  NSPoint titlePosition;
  NSDictionary *titleAttributes;

  // Fill text background
  [background set];
  NSRectFill(titleRect);

  if (title) {
    titlePosition = NSMakePoint(
        titleRect.origin.x + (titleRect.size.width - [_font widthOfString:title]) / 2,
        titleRect.origin.y + floorf((titleRect.size.height - [_font defaultLineHeightForFont]) / 2));
    titleAttributes =
        @{NSForegroundColorAttributeName : foreground, NSFontAttributeName : _font};
    [title drawAtPoint:titlePosition withAttributes:titleAttributes];
  }
}

// `rect` includes left and right image, white top line, title
- (void)drawTabForItem:(NSTabViewItem *)item
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  BOOL isSelected = item.tabState == NSSelectedTab;
  NSRect tabRect = item._tabRect;
  NSString *title = item.label;
  NSColor *background = isSelected ? _selectedBackgroundColor : _unselectedBackgroundColor;
  NSColor *textColor = [NSColor blackColor];
      // isSelected ? [NSColor blackColor] : [NSColor colorWithDeviceWhite:0.6 alpha:1.0];
  NSImage *edgeLeft = [self imageForSide:@"Left" backgroundColor:background selected:isSelected];
  NSImage *edgeRight = [self imageForSide:@"Right" backgroundColor:background selected:isSelected];
  CGFloat titleWidth = tabRect.size.width - edgeLeft.size.width - edgeRight.size.width;

  // NSLog(@"Draw tab with width: %f, left edge: %f, right edge: %f", rect.size.width,
  //       edgeLeft.size.width, edgeRight.size.width);

  [self drawTabTitle:title
           withFrame:NSMakeRect(tabRect.origin.x + edgeLeft.size.width, tabRect.origin.y, titleWidth,
                                tabRect.size.height)
          background:background
          foreground:textColor];

  // Draw edges and top
  [edgeLeft drawAtPoint:NSMakePoint(tabRect.origin.x, tabRect.origin.y)
               fromRect:NSMakeRect(0, edgeLeft.size.height - tabRect.size.height, edgeLeft.size.width,
                                   tabRect.size.height)
              operation:NSCompositeSourceOver
               fraction:1.0];

  [edgeRight drawAtPoint:NSMakePoint((tabRect.origin.x + tabRect.size.width) - edgeRight.size.width,
                                     tabRect.origin.y)
                fromRect:NSMakeRect(0, edgeRight.size.height - tabRect.size.height,
                                    edgeRight.size.width, tabRect.size.height)
               operation:NSCompositeSourceAtop
                fraction:1.0];

  // Top white line
  if (isSelected != NO || (_unselectedBackgroundColor.whiteComponent > 0.4)) {
    [[NSColor whiteColor] set];
  } else {
    [[NSColor lightGrayColor] set];
  }
  DPSmoveto(ctxt, tabRect.origin.x + edgeLeft.size.width - 2, tabRect.origin.y + tabRect.size.height);
  DPSlineto(ctxt, tabRect.origin.x + edgeLeft.size.width + titleWidth + 2,
            tabRect.origin.y + tabRect.size.height);

  DPSstroke(ctxt);

  [edgeLeft release];
  [edgeRight release];  
}

- (void)drawRect:(NSRect)rect
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  CGFloat subviewTopLineHeight = 1;
  CGFloat tabHeight = 21;
  CGFloat tabOverlap = 25;
  CGFloat offset = 6;

  // NSLog(@"TabView rect: %@, Tab width: %f, Items: %lu", NSStringFromRect(rect), tabWidth,
  //       [_items count]);

  // Fill top view background
  DPSsetgray(ctxt, [_unselectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, _frame.size.width, _frame.size.height);

  // Fill subview background
  DPSsetgray(ctxt, [_selectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height - offset - tabHeight);

  DPSstroke(ctxt);

  // Draw unselected
  NSUInteger tabCount = [_items count];
  if (tabCount > 0) {
    CGFloat tabWidth = roundf(([self frame].size.width + (tabOverlap * (tabCount - 1))) / tabCount);
    NSRect tabRect = NSMakeRect(0, (_frame.size.height - offset - tabHeight - subviewTopLineHeight),
                                tabWidth, tabHeight);
    NXTTabViewItem *item;
    int selectedTabIndex = 0;

    for (int i = tabCount - 1; i >= 0; i--) {
      item = [_items objectAtIndex:i];
      tabRect.origin.x = (tabWidth - tabOverlap) * i;
      [item setTabRect:tabRect];
      // NSLog(@"Drawing tab `%@` with rect: %@ selected: %@", item.label,
      //       NSStringFromRect(item._tabRect), !item.tabState ? @"Yes" : @"No");
      // [self drawTabWithFrame:tabRect title:item.label selected:NO];
      if (item.tabState != NSSelectedTab) {
        [self drawTabForItem:item];
      } else {
        selectedTabIndex = i;
      }
    }

    // White line between views and tabs
    NSDrawButton(NSMakeRect(0, 0, _frame.size.width, (_frame.size.height - offset - tabHeight)),
                 rect);
    
    // Draw selected
    item = [_items objectAtIndex:selectedTabIndex];
    tabRect.origin.x = (tabWidth - tabOverlap) * selectedTabIndex;;
    [item setTabRect:tabRect];
    // NSLog(@"Drawing tab `%@` with rect: %@ selected: %@", item.label,
    //       NSStringFromRect(item._tabRect), !item.tabState ? @"Yes" : @"No");
    // [self drawTabWithFrame:tabRect title:item.label selected:YES];
    [self drawTabForItem:item];
  } else {
    // Draw "No Items" text at the center of view
    NSString *message = @"No Tab View Items";
    NSFont *msgFont = [NSFont systemFontOfSize:18];
    CGFloat msgWidth = [msgFont widthOfString:message];
    CGFloat msgHeight = [msgFont defaultLineHeightForFont];
    NSPoint msgPoint = NSMakePoint((_frame.size.width - msgWidth) / 2,
                                   (_frame.size.height - offset - tabHeight - msgHeight) / 2);
    // White line between views and tabs
    NSDrawButton(NSMakeRect(0, 0, _frame.size.width, (_frame.size.height - offset - tabHeight)),
                 rect);
    [message drawAtPoint:msgPoint
          withAttributes:@{
            NSForegroundColorAttributeName : [NSColor darkGrayColor],
            NSFontAttributeName : msgFont
          }];
  }
}

@end