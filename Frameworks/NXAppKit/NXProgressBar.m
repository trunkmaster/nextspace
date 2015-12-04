//
// MiscProgressBar.h -- a simple view class for displaying progress bar
// Written and Copyright (c) 1993 by James Heiser.  (jheiser@adobe.com)
// Version 1.0.  All rights reserved.
//
// This notice may not be removed from this source code.
//
// This object is included in the MiscKit by permission from the author
// and its use is governed by the MiscKit license, found in the file
// "LICENSE.rtf" in the MiscKit distribution.  Please refer to that file
// for a list of all applicable permissions and restrictions.
//	


// Added two methoods -setTicksVisible: (BOOL) and -isTicksVisible:
// Allows the user to select whether ticmarks are Visible or not.
// James Heiser  Sat Sep 25 13:59:15 GMT-0800 1993
//
// Added two methoods -setTicksOverBar:(BOOL) and -isTicksOverBar
// Allows the user to select whether ticmarks are drawn above or
// below progress bar.
// Don Yacktman  Mon Oct 18 22:58:52 MDT 1993
//
// Added two methoods -setTickColor:(NXColor) and -tickColor
// Allows user to set color of ticmarks.
// Don Yacktman  Mon Oct 18 22:58:52 MDT 1993

#import "NXProgressBar.h"

#define MISC_DEFALUT_TICKS 24	// number of ticks to show + 1
				// (so 24 divisions between 0-1 ratio)
									
#define MISC_DEFAULT_EMPHASIS 3	// every nth tick is longer...


@implementation NXProgressBar

- initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];
  isTicksVisible = YES;
  isTicksOverBar = NO;
  numTicks = MISC_DEFALUT_TICKS;
  emphasis = MISC_DEFAULT_EMPHASIS;
  tc = [[NSColor darkGrayColor] retain];
  return self;
}

- (void)dealloc
{
  [tc release];
  return [super dealloc];
}


- (NSColor *)tickColor 
{
  return tc;
}

- (void)setTickColor:(NSColor *)color
{
  if([tc isEqual:color])
    return;
  [tc release];
  tc = [color retain];
}

- (void)renderTicks
{
  if (isTicksVisible == YES)
    {
      int linecount;
      [tc set];
      for (linecount = 1; linecount <= numTicks; ++linecount)
        {
          int xcoord = ([self bounds].size.width / numTicks) * linecount;
          PSnewpath();
          PSmoveto(xcoord, 0);
          if (linecount % emphasis)
            {
              PSlineto(xcoord, (int)([self bounds].size.height / 4));
            }
          else
            {
              PSlineto(xcoord, (int)([self bounds].size.height / 2));
            }
          PSstroke();
        }
    }
}

- (void)renderBar
{
  if (isTicksOverBar)
    {
      [super renderBar];
      [self renderTicks];
      [super renderBarEdge];
    } 
  else 
    {
      [self renderTicks];
      [super renderBar];
      [super renderBarEdge];
    }
}

- (void)setTicksVisible:(BOOL)aBool
{
  isTicksVisible = aBool;
  [self display];
}

- (BOOL)isTicksVisible
{
  return isTicksVisible;
}

- (void)setTicksOverBar:(BOOL)aBool
{
  isTicksOverBar = aBool;
  [self display];
}

- (BOOL)isTicksOverBar
{
  return isTicksOverBar;
}

- (void)setNumTicks:(int)anInt
{
  numTicks = MAX(anInt + 1, 1);
  [self display];
}

- (int)numTicks
{
  return (numTicks - 1);
}

- (void)setEmphasis:(int)anInt
{
  emphasis = MAX(anInt, 1);
  [self display];
}

- (int)emphasis
{
  return emphasis;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
  [super initWithCoder:aDecoder];
  [aDecoder decodeValuesOfObjCTypes:"ccii", &isTicksVisible, &isTicksOverBar,
            &numTicks, &emphasis];
  tc = [[aDecoder decodeObject] retain];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeValuesOfObjCTypes:"ccii", &isTicksVisible, &isTicksOverBar,
          &numTicks, &emphasis];
  [aCoder encodeObject:tc];
}

- (NSString *)inspectorClassName
{
  return @"NXProgressBarInspector";
}


@end
