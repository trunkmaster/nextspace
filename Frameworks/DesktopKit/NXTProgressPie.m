/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// MiscProgressPie.m -- a simple view class for displaying a pie
// Written and Copyright (c) 1993 by James Heiser.  (jheiser@adobe.com)
// Rendering code massaged by Don Yacktman.
// Version 1.0.  All rights reserved.
//
// This notice may not be removed from this source code.
//
// This object is included in the MiscKit by permission from the author
// and its use is governed by the MiscKit license, found in the file
// "LICENSE.rtf" in the MiscKit distribution.  Please refer to that file
// for a list of all applicable permissions and restrictions.
//	

#import "NXTProgressPie.h"

@implementation NXTProgressPie

- initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];
  [self setHidden:NO];
  return self;
}

- (void)renderBar
{
  float angle = 90.0;
  if ([self isHidden] || (ratio <= 0.0)) {
    return;
  }
  if (ratio >= 1.0) {
    angle = -270.0;
  }
  if (ratio < 1.0 && ratio > 0.0) {
    angle = 90.0 - 360.0 * ratio;
  }
  PSmoveto(NSWidth([self bounds]) / 2.0, NSHeight([self bounds]) / 2.0);
  PSarcn(NSWidth([self bounds]) / 2.0, NSHeight([self bounds]) / 2.0,
         NSHeight([self bounds]) / 2.0, 90.0, angle);
  PSclosepath();
  [fg set];
  PSfill();
  PSstroke();
}

- (void)renderBorder
{
  float angle = 90.0;
  CGFloat vWidth, vHeight;
  CGFloat center_x, center_y;

  if ([self isHidden]) {
    return;
  }

  [bd set];

  vWidth = [self bounds].size.width;
  vHeight = [self bounds].size.height;
  //  PSsetlinewidth(1.0);
  PSarc(vWidth/2.0, vHeight/2.0, (vHeight-2)/2.0, 0.0, 360.0);
  PSstroke();

  if (ratio >= 1.0) {
    angle = -270.0;
  }
  if ((ratio < 1.0) && (ratio > 0.0)) {
    angle = 90.0 - 360.0 * ratio;
  }
  PSmoveto(vWidth/2.0, vHeight/2.0);
  PSarcn(vWidth/2.0, vHeight/2.0, (vHeight-2)/2.0, 90.0, angle);
  PSclosepath();
  PSstroke();
}

- (void)setHidden:(BOOL)aBool
{
  isHidden = aBool;
}

- (BOOL)isHidden
{
  return isHidden;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  [super initWithCoder:aDecoder];
  [aDecoder decodeValuesOfObjCTypes:"c", &isHidden];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeValuesOfObjCTypes:"c", &isHidden];
}

- (NSString *)inspectorClassName
{
  return @"NXTProgressPieInspector";
}

@end
