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
#import "DrawingTest.h"

@interface DrawingCanvas : NSView
{}
@end

@implementation DrawingCanvas : NSView

- (void)drawRect:(NSRect)rect
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  
  [super drawRect:rect];

  // [[NSColor blackColor] set];
  // DPSsetrgbcolor(ctxt, 0.0, 0.0, 0.0);
  DPSsetgray(ctxt, 0.0);
  
  // [NSBezierPath strokeLineFromPoint:NSMakePoint(5, 5)
  //                           toPoint:NSMakePoint(5, 100)];
  DPSsetgray(ctxt, 0.0);
  DPSsetlinewidth(ctxt, 1.0);
  DPSrectstroke(ctxt, 1.5, 1.5, 477.5, 377.5);
  
  // DPSsetgray(ctxt, 0.3);
  // DPSsetlinewidth(ctxt, 1.);
  // DPSrectstroke(ctxt, 2, 2, 476, 376);
  DPSmoveto(ctxt, 4.5, 4);
  DPSlineto(ctxt, 4.5, 376.5);
  DPSlineto(ctxt, 476.5, 376.5);
  DPSlineto(ctxt, 476.5, 4.5);
  DPSlineto(ctxt, 4.5, 4.5);
  DPSstroke(ctxt);
  
  // [NSBezierPath strokeRect:NSMakeRect(0,0,480,380)];
  // DPSsetgray(ctxt, 0.0);
  // DPSsetlinewidth(ctxt, 1.0);

  // DPSmoveto(ctxt, 2, 5);
  // DPSlineto(ctxt, 2, 100);
  // DPSstroke(ctxt);
  {
    NSImage *edgeLeft = [NSImage imageNamed:@"TabEdge_Left"];
    NSImage *edgeRight = [NSImage imageNamed:@"TabEdge_Right"];
    NSImage *interiorLeft = [NSImage imageNamed:@"TabInterior_Left"];
    NSImage *interiorRight = [NSImage imageNamed:@"TabInterior_Right"];

    NSLog(@"Interior left background color: %@", [interiorLeft backgroundColor]);
    [interiorLeft drawAtPoint:NSMakePoint(100, 100)
                     fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
                    operation:NSCompositeSourceOver
                     fraction:1.0];
    [edgeLeft drawAtPoint:NSMakePoint(100, 100)
                 fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
                operation:NSCompositeSourceOver
                 fraction:1.0];

    // Fill text background
    DPSsetgray(ctxt, 0.33);
    DPSrectfill(ctxt, 100 + edgeLeft.size.width, 100, 40 - edgeLeft.size.width,
                edgeLeft.size.height);

    DPSsetgray(ctxt, 1.0);
    DPSmoveto(ctxt, 100 + edgeLeft.size.width, 145);
    DPSlineto(ctxt, 140, 145);
    DPSstroke(ctxt);
    
    [edgeLeft drawAtPoint:NSMakePoint(140, 100)
                 fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
                operation:NSCompositeSourceOver
                 fraction:1.0];

    [interiorRight drawAtPoint:NSMakePoint(140, 100)
                      fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
                     operation:NSCompositeSourceAtop
                      fraction:1.0];
    [edgeRight drawAtPoint:NSMakePoint(140, 100)
                 fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
                operation:NSCompositeSourceAtop
                 fraction:1.0];
    
    // // [interiorLeft setBackgroundColor:[NSColor darkGrayColor]];
    // NSLog(@"Interior left background color: %@", [interiorLeft backgroundColor]);
    // [interiorLeft drawAtPoint:NSMakePoint(140, 100)
    //                  fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
    //                 operation:NSCompositeXOR
    //                  fraction:1.0];
    // [edgeLeft drawAtPoint:NSMakePoint(140, 100)
    //                  fromRect:NSMakeRect(0, 0, interiorLeft.size.width, interiorLeft.size.height)
    //                 operation:NSCompositeSourceOver
    //                  fraction:1.0];
  }
}

@end

@implementation DrawingTest : NSObject

- (id)init
{
  window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 400)
                                       styleMask:(NSTitledWindowMask | NSResizableWindowMask | NSClosableWindowMask)
                                         backing:NSBackingStoreRetained
                                           defer:YES];
  [window setMinSize:NSMakeSize(500, 400)];
  [window setTitle:@"NSBezierPath drawing test"];
  [window setReleasedWhenClosed:YES];
  [window setDelegate:self];

  canvas = [[DrawingCanvas alloc] initWithFrame:NSMakeRect(10, 10, 480, 380)];
  [[window contentView] addSubview:canvas];

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
