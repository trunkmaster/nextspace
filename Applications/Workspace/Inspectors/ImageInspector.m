/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import <DesktopKit/NXTBundle.h>
#import <SystemKit/OSEFileManager.h>

#import <dispatch/dispatch.h>

#import "ImageInspector.h"

@interface ImageInspector (Private)

@end

@implementation ImageInspector (Private)

@end

static id imageInspector = nil;

@implementation ImageInspector

static inline NSSize scaleProportionally(NSSize imageSize, NSSize canvasSize, BOOL scaleUpOrDown)
{
  CGFloat ratio;

  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return NSMakeSize(0, 0);
  }

  /* Get the smaller ratio and scale the image size by it.  */
  ratio = MIN(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height);

  /* Only scale down, unless scaleUpOrDown is YES */
  if (ratio < 1.0 || scaleUpOrDown) {
    imageSize.width *= ratio;
    imageSize.height *= ratio;
  }

  return imageSize;
}

// Class Methods

+ new
{
  if (imageInspector == nil) {
    imageInspector = [super new];
    if (![NSBundle loadNibNamed:@"ImageInspector" owner:imageInspector]) {
      imageInspector = nil;
    }
  }

  return imageInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FileContentsInspector: dealloc");

  TEST_RELEASE(view);

  [super dealloc];
}

- (void)awakeFromNib
{
  // [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
}

- (BOOL)isLocalFile
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *fp;
  NSString *path = nil;
  NSArray *files = nil;

  [self getSelectedPath:&path andFiles:&files];

  fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];

  NSDebugLLog(@"Ispector", @"Image Inspector-isLocalFile: %@", fp);

  if (![fm isReadableFileAtPath:fp]) {
    return NO;
  }

  return YES;
}

// Public Methods

- ok:sender
{
  NSString *fp;

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];

  [[NSApp delegate] openFile:fp];

  return self;
}

- revert:sender
{
  NSString *fp;
  NSImage *image;
  NSSize imageSize;
  NSRect cellFrame;
  NSSize cellSize;
  CGFloat scaleFactor;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];

  image = [[NSImage alloc] initWithContentsOfFile:fp];
  imageSize = [image size];
  [widthField setStringValue:[NSString stringWithFormat:@"%0.f", imageSize.width]];
  [heightField setStringValue:[NSString stringWithFormat:@"%0.f", imageSize.height]];
  [imageView setImage:image];
  [image release];

  cellFrame = [(NSImageCell *)[imageView cell] drawingRectForBounds:[imageView bounds]];
  // cellFrame = [imageView drawingRectForBounds:[imageView bounds]];
  cellSize = scaleProportionally(imageSize, cellFrame.size, NO);

  // Image scaled proportionally and we can calculate from any size parameter
  scaleFactor = cellSize.width / imageSize.width;
  [zoomPercentField setStringValue:[NSString stringWithFormat:@"%0.f%%", scaleFactor * 100]];

  // Buttons state and title, window edited state
  [super revert:self];

  [[[self okButton] cell] setTitle:@"Display"];
  [[self okButton] setEnabled:YES];

  return self;
}

@end
