/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// MiscProgressView.m -- a simple view class for displaying progress
// Written originally by Don Yacktman Copyright (c) 1993 by James Heiser.
// Modified from an example in the NeXT documentation.
// This file is maintained by James Heiser, jheiser@adobe.com.
// Version 1.0.  All rights reserved.
//
// This notice may not be removed from this source code.
//
// This object is included in the MiscKit by permission from the author
// and its use is governed by the MiscKit license, found in the file
// "LICENSE.rtf" in the MiscKit distribution.  Please refer to that file
// for a list of all applicable permissions and restrictions.
//	

#import <GNUstepGUI/GSTheme.h>
#import "NXTProgressView.h"

@implementation NXTProgressView

- initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];
  bg = [[NSColor lightGrayColor] retain];
  fg = [[NSColor grayColor] retain];
  bd = [[NSColor blackColor] retain];
  total = MISC_PROGRESS_MAXSIZE;
  stepSize = MISC_PROGRESS_DEFAULTSTEPSIZE;
  count = 0;
  ratio = 0.0;

  return self;
}

- (void)dealloc
{
  [bg release];
  [fg release];
  [bd release];

  return [super dealloc];
}

- (void)renderBackground
{
  [bg set];
  NSRectFill([self bounds]);
}

- (void)renderBarEdge
{
  if ((ratio > 0) && (ratio <= 1.0)) {
    NSRect r = [self bounds];
    r.size.width = [self bounds].size.width * ratio;

    [bd set];
    PSnewpath();
    PSmoveto(r.size.width, 0);
    PSlineto(r.size.width, r.size.height);
    PSstroke();
  }
}

- (void)renderBar
{
  if ((ratio > 0) && (ratio <= 1.0)) {
    NSRect r = [self bounds];
    r.size.width = [self bounds].size.width * ratio;
    [fg set];
    NSRectFill(r);
  }
}

- (void)renderBorder
{
  switch(border_type)
    {
    case NSNoBorder:
      return;
    case NSBezelBorder:
      [[GSTheme theme] drawGrayBezel:[self bounds] withClip:NSZeroRect];
      break;
    default:
      [bd set];
      NSFrameRect([self bounds]);
      break;
    }
}


- (void)drawRect:(NSRect)rect
{
  // Note from Don on why this -drawSelf: is split up --
  // The three separate rendering methods make things a little less efficient,
  // but make it a lot easier to subclass and retain parts of the original
  // rendering.  I wish NeXT had done something like this with the various
  // control classes so that subclasses could override parts of the steps
  // in the rendering process...or insert things at certain points in time.
  [self renderBackground];
  [self renderBar];
  [self renderBorder];
}

- (void)setStepSize:(int)value
{
  stepSize = value;
}

- (int)stepSize
{
  return stepSize;
}

- (NSColor *)backgroundColor
{
  return bg;
}

- (NSColor *)foregroundColor
{
  return fg;
}

- (NSColor *)borderColor
{
  return bd;
}

- (NSBorderType)borderType
{
  return border_type;
}

- (void)setBackgroundColor:(NSColor *)color
{
  if ([bg isEqual:color]) {
    return;
  }
  [bg release];
  bg = [color retain];
}

- (void)setForegroundColor:(NSColor *)color
{
  if ([fg isEqual:color]) {
    return;
  }
  [fg release];
  fg = [color retain];
}

- (void)setBorderColor:(NSColor *)color
{
  if ([bd isEqual:color]) {
    return;
  }
  [bd release];
  bd = [color retain];
}

- (void)setBorderType:(NSBorderType)borderType
{
  if (border_type != borderType) {
    border_type = borderType;
    [self setNeedsDisplay:YES];
  }
}

- (void)setRatio:(float)newRatio
{
  if (newRatio > 1.0) {
    newRatio = 1.0;
  }
  if (ratio != newRatio) {
    ratio = newRatio;
    [self setNeedsDisplay:YES];
  }
}


- (void)takeIntValueFrom:(id)sender
{
  int temp = [sender intValue];

  if ((temp < 0) || (temp > total)) {
    return;
  }
  count = temp;
  [self setRatio:(float)count/(float)total];
}

- (void)increment:(id)sender
{
  count += stepSize;
  [self setRatio:(float)count/(float)total];
}

- (void)takeFloatValueFrom:(id)sender
{
  [self setRatio:[sender floatValue]];
  count = ceil(ratio * (float)total);
}

- (NSString *)inspectorClassName
{
  return @"NXTProgressViewInspector";
}

- (void)clear:(id)sender
{
  count = 0;
  [self setRatio:0];
}


- (id)initWithCoder:(NSCoder *)aCoder
{
  [super initWithCoder:aCoder];
  [aCoder decodeValuesOfObjCTypes:"ii", &total, &stepSize];
  bg = [[aCoder decodeObject] retain];
  fg = [[aCoder decodeObject] retain];
  bd = [[aCoder decodeObject] retain];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeValuesOfObjCTypes:"ii", &total, &stepSize];
  [aCoder encodeObject:bg];
  [aCoder encodeObject:fg];
  [aCoder encodeObject:bd];
}

@end
