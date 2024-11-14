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

#import <DesktopKit/Utilities.h>
#import "NXTTabView.h"

@implementation NXTTabView

#pragma mark - Overridings

- (id)initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];

  _topTabOffset = 6;
  _itemLeftOffset = 1;
  _itemBottomOffset = 2;
  _tabHeight = [_font defaultLineHeightForFont] + _topTabOffset;
  _subviewTopLineHeight = 1;

  // frameRect.size.width -= 3;
  // frameRect.size.height -= (_topTabOffset + _tabHeight + _subviewTopLineHeight + _itemBottomOffset);
  // frameRect.origin = NSMakePoint(_itemLeftOffset, _itemBottomOffset);
  // _itemContentView = [[NSBox alloc] initWithFrame:frameRect];
  // [_itemContentView setTitlePosition:NSNoTitle];
  // [_itemContentView setBorderType:NSNoBorder];
  // [_itemContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  // [_itemContentView setContentViewMargins:NSMakeSize(0, 0)];
  // [self addSubview:_itemContentView];
  // [_itemContentView release];

  return self;
}

- (void)addTabViewItem:(NSTabViewItem *)tabViewItem
{
  NXTTabViewItem *item = (NXTTabViewItem *)tabViewItem;

  [super addTabViewItem:tabViewItem];

  item.superviewOldSize = _frame.size;
}

- (BOOL)isFlipped
{
  return NO;
}

- (NSSize)minimumSize
{
  return NSMakeSize(3, 21);
}

- (void)selectTabViewItem:(NSTabViewItem *)tabViewItem
{
  BOOL canSelect = YES;
  NSView *selectedView = nil;

  if ([_delegate respondsToSelector:@selector(tabView:shouldSelectTabViewItem:)]) {
    canSelect = [_delegate tabView:self shouldSelectTabViewItem:tabViewItem];
  }

  if (canSelect) {
    if ([_delegate respondsToSelector:@selector(tabView:willSelectTabViewItem:)]) {
      [_delegate tabView:self willSelectTabViewItem:tabViewItem];
    }

    if (_selected != nil) {
      [_selected _setTabState:NSBackgroundTab];
      // NB: If [_selected view] is nil this does nothing, which is fine.
      [[_selected view] removeFromSuperview];
    }

    _selected = tabViewItem;
    selectedView = [_selected view];
    [_selected _setTabState:NSSelectedTab];
    if (selectedView != nil) {
      NSView *firstResponder;

      [self addSubview:selectedView];
      [(NXTTabViewItem *)_selected resizeViewToSuperview:self];
      // [_itemContentView setContentView:selectedView];

      firstResponder = [_selected initialFirstResponder];
      if (firstResponder == nil) {
        firstResponder = selectedView;
        [_selected setInitialFirstResponder:firstResponder];
        // [firstResponder _setUpKeyViewLoopWithNextKeyView:_original_nextKeyView];
      }
      [self setNextKeyView:firstResponder];
      [_window makeFirstResponder:firstResponder];
    }

    // Will need to redraw tabs and content area.
    [self setNeedsDisplay:YES];

    if ([_delegate respondsToSelector:@selector(tabView:didSelectTabViewItem:)]) {
      [_delegate tabView:self didSelectTabViewItem:_selected];
    }
  }
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

  edgePath = [bundle pathForImageResource:[NSString stringWithFormat:@"TabEdge_%@", side]];
  edgeRep = (NSBitmapImageRep *)[NSImageRep imageRepWithContentsOfFile:edgePath];

  interiorPath = [bundle pathForImageResource:[NSString stringWithFormat:@"TabInterior_%@", side]];
  interiorRep = (NSBitmapImageRep *)[NSImageRep imageRepWithContentsOfFile:interiorPath];

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

  image = [[NSImage alloc] initWithContentsOfFile:edgePath];
  for (id rep in [image representations]) {
    [image removeRepresentation:rep];
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
  NSString *label = title;

  // Fill text background
  [background set];
  NSRectFill(titleRect);

  if (title) {
    // TODO: `_trancated_label` is weird name. Use `_allowsTrancatedLabels` instead.
    if (_truncated_label != NO) {
      label = NXTShortenString(title, titleRect.size.width, _font, NXSymbolElement, NXTDotsAtRight);
    }
    titlePosition = NSMakePoint(
        titleRect.origin.x + (titleRect.size.width - [_font widthOfString:label]) / 2,
        titleRect.origin.y + floorf((titleRect.size.height - [_font defaultLineHeightForFont]) / 2));
    titleAttributes =
        @{NSForegroundColorAttributeName : foreground, NSFontAttributeName : _font};
    [label drawAtPoint:titlePosition withAttributes:titleAttributes];
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
  CGFloat tabOverlap = 25;

  // NSLog(@"NXTabView: line height is: %f", [_font defaultLineHeightForFont]);
  // NSLog(@"TabView rect: %@, Tab width: %f, Items: %lu", NSStringFromRect(rect), tabWidth,
  //       [_items count]);

  // Fill top view background
  DPSsetgray(ctxt, [_unselectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, _frame.size.width, _frame.size.height);

  // Fill subview background
  DPSsetgray(ctxt, [_selectedBackgroundColor whiteComponent]);
  DPSrectfill(ctxt, 0, 0, rect.size.width, rect.size.height - _topTabOffset - _tabHeight);

  DPSstroke(ctxt);

  // Draw unselected
  NSUInteger tabCount = [_items count];
  if (tabCount > 0) {
    CGFloat tabWidth = roundf(([self frame].size.width + (tabOverlap * (tabCount - 1))) / tabCount);
    NSRect tabRect = NSMakeRect(0, (_frame.size.height - _topTabOffset - _tabHeight - _subviewTopLineHeight),
                                tabWidth, _tabHeight);
    NXTTabViewItem *item;
    NSUInteger selectedTabIndex = 0;

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
    NSDrawButton(NSMakeRect(0, 0, _frame.size.width, (_frame.size.height - _topTabOffset - _tabHeight)),
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
                                   (_frame.size.height - _topTabOffset - _tabHeight - msgHeight) / 2);
    // White line between views and tabs
    NSDrawButton(NSMakeRect(0, 0, _frame.size.width, (_frame.size.height - _topTabOffset - _tabHeight)),
                 rect);
    [message drawAtPoint:msgPoint
          withAttributes:@{
            NSForegroundColorAttributeName : [NSColor darkGrayColor],
            NSFontAttributeName : msgFont
          }];
  }
}

@end