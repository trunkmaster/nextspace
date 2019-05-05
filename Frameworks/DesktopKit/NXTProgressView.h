/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// MiscProgressView.h -- a simple view class for displaying progress
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

#import <AppKit/AppKit.h>

#define MISC_PROGRESS_DEFAULTSTEPSIZE 5
#define MISC_PROGRESS_MAXSIZE 100

@interface NXTProgressView : NSView <NSCoding>
{
  int total, count, stepSize;
  float ratio;
  NSColor *bg, *fg, *bd; // foreground, background, border colors
  NSBorderType border_type;
}

- initWithFrame:(NSRect)frameRect;
- (void)renderBackground;
- (void)renderBarEdge;
- (void)renderBar;
- (void)renderBorder;
- (void)drawRect:(NSRect)rect;
- (void)setStepSize:(int)value;
- (int)stepSize;
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)borderColor;
- (NSBorderType)borderType;
- (void)setBackgroundColor:(NSColor *)color;
- (void)setForegroundColor:(NSColor *)color;
- (void)setBorderColor:(NSColor *)color;
- (void)setBorderType:(NSBorderType)borderType;

- (void)setRatio:(float)newRatio;
- (void)takeIntValueFrom:(id)sender;
- (void)increment:(id)sender;
- (void)takeFloatValueFrom:(id)sender;
- (NSString *)inspectorClassName;
- (void)clear:(id)sender;

@end
