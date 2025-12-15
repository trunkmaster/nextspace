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
#include "AppKit/NSGraphicsContext.h"
#import "DrawingTest.h"

@interface DrawingCanvas : NSView
{}
@end

@implementation DrawingCanvas : NSView

- (void)drawRect:(NSRect)rect
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  NSLog(@"Canvas context: %p", ctxt);
  
  [super drawRect:rect];

  // [[NSColor blackColor] set];
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

  NSImage *grayAlpha = [NSImage imageNamed:@"SharedGrayAlpha"];
  NSImage *knobSlotPattern = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
  // NSBitmapImageRep *rep;

  // NSLog(@"knb slot pattern representations: %lu", [[knobSlotPattern representations] count]);
  // rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
  //                                               pixelsWide:12
  //                                               pixelsHigh:12
  //                                            bitsPerSample:2
  //                                          samplesPerPixel:2
  //                                                 hasAlpha:YES
  //                                                 isPlanar:YES
  //                                           colorSpaceName:NSDeviceWhiteColorSpace
  //                                              bytesPerRow:48
  //                                             bitsPerPixel:4];
  // NSLog(@"rep was added - slot pattern representations: %lu", [[knobSlotPattern representations] count]);

  // NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
  // [NSGraphicsContext saveGraphicsState];
  // [NSGraphicsContext setCurrentContext:ctx];

  // [knobSlotPattern setCacheMode:NSImageCacheDefault];

  // NSLog(@"0");
  NSLog(@"slot pattern representations: %lu", [[knobSlotPattern representations] count]);
  [knobSlotPattern lockFocusOnRepresentation:nil];
  // NSLog(@"1");
  NSLog(@"slot pattern representations: %lu", [[knobSlotPattern representations] count]);
  [grayAlpha drawAtPoint:NSZeroPoint
                fromRect:NSMakeRect(49, 88, 12, 12)
               operation:NSCompositeSourceOver
                fraction:1.0];
  // NSLog(@"2");
  [knobSlotPattern unlockFocus];
  // NSLog(@"3");
  // [knobSlotPattern addRepresentation:rep];
  // NSLog(@"4");

  // NSLog(@"Canvas context: %p, pattern context: %p", ctxt, ctx);
  // [ctxt flushGraphics];
  // [NSGraphicsContext restoreGraphicsState];

  // [[knobSlotPattern TIFFRepresentation] writeToFile:@"KnobSlotPattern.tiff" atomically:NO];

  [knobSlotPattern drawAtPoint:NSMakePoint(18, 6)
                      fromRect:NSMakeRect(0, 0, 12, 12)
                     operation:NSCompositeSourceOver
                      fraction:1.0];

  NSLog(@"slot pattern representations: %lu", [[knobSlotPattern representations] count]);

  // knobSlotPattern = [NSImage imageNamed:@"ScrollerPattern"];
  NSLog(@"Canvas context: %p", ctxt);
  NSData *tiffRep = [knobSlotPattern TIFFRepresentation];
  NSImage *slotPattern = [[NSImage alloc] initWithData:tiffRep];
  @try {
    [ctxt GSSetPatterColor:slotPattern];
  } @catch (NSException *ex) {
    NSLog(@"Exception: %@", ex);
  }
  DPSrectfill(ctxt, 6, 6, 16, 369);
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
