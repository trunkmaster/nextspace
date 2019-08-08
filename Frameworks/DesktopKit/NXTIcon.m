/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2005 Saso Kiselkov
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <AppKit/AppKit.h>
#import <SystemKit/OSEMouse.h>

#import "NXTIcon.h"
#import "NXTIconLabel.h"
#import "Utilities.h"

@interface NXTIcon (Private)

/* 
   Rebuilds the collapsed label string, puts it into the collapsed label
   and readjusts it's position.
*/
- (void)rebuildCollapsedLabelString;

@end

@implementation NXTIcon

static float defaultMaximumCollapsedLabelWidth = 100;

+ (void)setDefaultMaximumCollapsedLabelWidth:(float)newWidth
{
  if (newWidth <= 0)
    [NSException raise: NSInvalidArgumentException
		format: _(@"+setDefaultMaximumCollapsedLabelWidth:"
			  @" argument must be greater than zero")];
  
  defaultMaximumCollapsedLabelWidth = newWidth;
}

+ (float)defaultMaximumCollapsedLabelWidth
{
  return defaultMaximumCollapsedLabelWidth;
}

- (void)dealloc
{
  TEST_RELEASE(shortLabel);
  TEST_RELEASE(longLabel);
  TEST_RELEASE(labelString);
  TEST_RELEASE(bgColor);

  [super dealloc];
}

- initWithFrame:(NSRect)frame
{
  NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
  NSDictionary   *colorDict;
  NSDictionary   *fontDict;
  NSRect         labelFrame;

  [super initWithFrame:frame];

  shortLabel = [[NXTIconLabel alloc] initWithFrame:NSMakeRect(0, 0, 10, 15)
                                              icon:self];
  longLabel = [[NXTIconLabel alloc] initWithFrame:NSMakeRect(0, 0, 10, 15)
                                             icon:self];

  ASSIGN(bgColor, [NSColor highlightColor]);

  [shortLabel setDrawsBackground:NO];
  [shortLabel setEditable:NO];
  [shortLabel setSelectable:NO];

  if ((fontDict = [df objectForKey:@"NXTIconLabelFont"])
      && [fontDict isKindOfClass:[NSDictionary class]]) {
    float    size = 0.0;
    NSString *name = [fontDict objectForKey:@"Name"];

    if ([fontDict objectForKey: @"Size"]) {
      size = [[fontDict objectForKey:@"Size"] floatValue];
    }

    if (name) {
      [shortLabel setFont:[NSFont fontWithName:name size:size]];
    }
    else {
      [shortLabel setFont:[NSFont systemFontOfSize:size]];
    }
  }

  [longLabel setDrawsBackground:YES];
  [longLabel setBackgroundColor:bgColor];

  if ((fontDict = [df objectForKey:@"NXLongIconLabelFont"])
      && [fontDict isKindOfClass:[NSDictionary class]]) {
    float    size = 0.0;
    NSString *name = [fontDict objectForKey:@"Name"];
    
    if ([fontDict objectForKey: @"Size"]) {
      size = [[fontDict objectForKey: @"Size"] floatValue];
    }

    if (name) {
      [longLabel setFont:[NSFont fontWithName:name size:size]];
    }
    else {
      [longLabel setFont:[NSFont systemFontOfSize:size]];
    }
  }

  maximumCollapsedLabelWidth = defaultMaximumCollapsedLabelWidth;
  showsExpandedLabelWhenSelected = YES;

  // readjust the real heights
  labelFrame = [shortLabel frame];
  labelFrame.size.height = [[shortLabel font] defaultLineHeightForFont];
  [shortLabel setFrame:labelFrame];

  labelFrame = [longLabel frame];
  labelFrame.size.height = [[longLabel font] defaultLineHeightForFont];
  [longLabel setFrame:labelFrame];

  isEditable = YES;
  isSelectable = YES;

  return self;
}

- (void)drawRect:(NSRect)r
{
  NSSize  mySize = [self frame].size;
  NSSize  imgSize;
  NSPoint p;

  if (isSelected) {
    NSImage *hiliteImage = [NSImage imageNamed:@"hilite"];
      
    imgSize = [hiliteImage size];
    p = NSMakePoint(roundf((mySize.width - imgSize.width) / 2),
                    roundf((mySize.height - imgSize.height) / 2));

    [hiliteImage compositeToPoint:p
                        operation:NSCompositeSourceOver];
  }

  if (iconImage) {
    imgSize = [iconImage size];
    p = NSMakePoint(roundf((mySize.width - imgSize.width) / 2),
                    roundf((mySize.height - imgSize.height) / 2));

    if (isDimmed) {
      [iconImage dissolveToPoint:p fraction:0.5];
    }
    else {
      [iconImage compositeToPoint:p
                        operation:NSCompositeSourceOver];
    }
  }
}

- (void)setIconSize:(NSSize)newIconSize
{
  NSRect rect = [self frame];

  rect.origin.x -= roundf((newIconSize.width - rect.size.width) / 2);
  rect.origin.y -= roundf((newIconSize.height - rect.size.height) / 2);

  rect.size.width = newIconSize.width;
  rect.size.height = newIconSize.height;

  [self setFrame:rect];

  // if we're in a superview, reposition the label as well
  if ([self superview]) {
    if (isSelected)
      [longLabel adjustFrame];
    else
      [shortLabel adjustFrame];
  }
}

- (NSSize)iconSize
{
  return [self frame].size;
}

- (void)putIntoView:(NSView *)view atPoint:(NSPoint)p
{
  NSRect frame;
  NSRect labelFrame;

  frame = [self frame];
  labelFrame = [shortLabel frame];

  frame.origin.x = p.x - roundf(frame.size.width/2);
  frame.origin.y = p.y - roundf((frame.size.height+labelFrame.size.height)/2);

  [self setFrame:frame];
  [view addSubview:self];

  if (isSelected && showsExpandedLabelWhenSelected) {
    [view addSubview:longLabel];
    [longLabel adjustFrame];
  }
  else {
    [view addSubview:shortLabel];
    [shortLabel adjustFrame];
  }
}

- (void)removeFromSuperview
{
  [shortLabel removeFromSuperview];
  [longLabel removeFromSuperview];
  [super removeFromSuperview];
}

- (NXTIconLabel *)label
{
  return longLabel;
}

- (NXTIconLabel *)shortLabel
{
  return shortLabel;
}

- (void)setIconImage:(NSImage *)newImage
{
  ASSIGN(iconImage, newImage);
  [self setNeedsDisplay:YES];
}

- (NSImage *)iconImage
{
  return iconImage;
}

- (void)setLabelString:(NSString *)aLabel
{
  ASSIGN(labelString, aLabel);

  [longLabel setString:labelString];
  [longLabel adjustFrame];
  [self rebuildCollapsedLabelString]; // construct short label string
  [self setNeedsDisplay:YES];
}

- (NSString *)labelString
{
  return labelString;
}

- (void)setSelected:(BOOL)sel
{
  if (isSelected == sel &&
      showsExpandedLabelWhenSelected == YES &&
      [longLabel superview] != nil) {
    return;
  }

  isSelected = sel;

  if (isSelected == YES &&
      showsExpandedLabelWhenSelected &&
      [longLabel superview] == nil) {
    [shortLabel removeFromSuperview];
    [[self superview] addSubview:longLabel];
    [longLabel adjustFrame];
  }
  else if ([shortLabel superview] == nil) {
    [longLabel removeFromSuperview];
    [[self superview] addSubview:shortLabel];
    
    if (![[longLabel string] isEqualToString:labelString]) {
      ASSIGN(labelString, [[[longLabel string] copy] autorelease]);
      [self rebuildCollapsedLabelString];
    } 
    else {
      [shortLabel adjustFrame];
    }
  }

  [self setNeedsDisplay:YES];
}

- (BOOL)isSelected
{
  return isSelected;
}

- (void)select:(id)sender
{
  [self setSelected:YES];
}

- (void)deselect:(id)sender
{
  [self setSelected:NO];
}

- (void)setDimmed:(BOOL)dimm
{
  if (isDimmed != dimm) {
    NSColor *textColor;
    
    isDimmed = dimm;
    [self setNeedsDisplay:YES];

    if (isDimmed == YES)
      textColor = [NSColor darkGrayColor];
    else
      textColor = [NSColor blackColor];

    [shortLabel setTextColor:textColor];
    [longLabel setTextColor:textColor];
  }
}

- (BOOL)isDimmed
{
  return isDimmed;
}

- (void)setSelectable:(BOOL)sel
{
  isSelectable = sel;

  [longLabel setSelectable:sel];
}

- (BOOL)isSelectable
{
  return isSelectable;
}

- (void)setEditable:(BOOL)edit
{
  [longLabel setEditable:edit];
  isEditable = edit;
  if (edit) {
    [longLabel setBackgroundColor:bgColor];
  }
  else {
    [longLabel setBackgroundColor:[NSColor windowBackgroundColor]];
  }
}

- (BOOL)isEditable
{
  return isEditable;
}

- (void)setMaximumCollapsedLabelWidth:(float)newWidth
{
  if (newWidth <= 0)
    [NSException raise: NSInvalidArgumentException
		format: _(@"-setMaximumCollapsedLabelWidth:"
			  @" argument must be greater than zero")];
  maximumCollapsedLabelWidth = newWidth;
  [self rebuildCollapsedLabelString];
}

- (float)maximumCollapsedLabelWidth
{
  return maximumCollapsedLabelWidth;
}

- (void)setBackgroundColor:(NSColor *)aColor
{
  ASSIGN(bgColor, aColor);
  [self setNeedsDisplay:YES];
  [longLabel setBackgroundColor:aColor];
}

- (NSColor *)backgroundColor
{
  return bgColor;
}

//-----------------------------------------------------------------------------
// Actions
//-----------------------------------------------------------------------------

- (void)mouseDown:(NSEvent *)ev
{
  int clickCount;
  NSInteger moveThreshold = [[[OSEMouse new] autorelease] accelerationThreshold];

  if (target == nil || isSelectable == NO || [ev type] != NSLeftMouseDown) {
    return;
  }

  NSLog(@"NXTIcon: mouseDown");

  [self setSelected:YES];
    
  clickCount = [ev clickCount];
  modifierFlags = [ev modifierFlags];

  // Dragging
  if ([target respondsToSelector:dragAction]) {
    NSPoint startPoint = [ev locationInWindow];
    unsigned int mask = NSLeftMouseDraggedMask | NSLeftMouseUpMask;

    //      while ([(ev = [[self window] nextEventMatchingMask:NSAnyEventMask]) type]
    //	     == NSLeftMouseDragged)
    while ([(ev = [[self window] nextEventMatchingMask:mask]) type]
           != NSLeftMouseUp) {
      NSPoint endPoint = [ev locationInWindow];

      if (absolute_value(startPoint.x - endPoint.x) > moveThreshold ||
          absolute_value(startPoint.y - endPoint.y) > moveThreshold) {
        [target performSelector:dragAction
                     withObject:self
                     withObject:ev];
        return;
      }
    }
  }

  // Clicking
  if (clickCount == 2) {
    [self setSelected:NO];
    if ([target respondsToSelector:doubleAction]) {
      [target performSelector:doubleAction withObject:self];
    }
  }
  else if (clickCount == 1) {
    [self setSelected:NO];
    if ([target respondsToSelector:action])
      {
        [target performSelector:action withObject:self];
      }
  }
}

- (void)setTarget:aTarget
{
  target = aTarget;
}

- target
{
  return target;
}

- (void)setDelegate:aDelegate
{
  delegate = aDelegate;
}

- delegate
{
  return delegate;
}

- (void)setAction:(SEL)anAction
{
  action = anAction;
}

- (SEL)action
{
  return action;
}

- (void)setDoubleAction:(SEL)anAction
{
  doubleAction = anAction;
}

- (SEL)doubleAction
{
  return doubleAction;
}

- (void)setDragAction:(SEL)anAction
{
  dragAction = anAction;
}

- (SEL)dragAction
{
  return dragAction;
}

- (void)setShowsExpandedLabelWhenSelected:(BOOL)showsExpanded
{
  showsExpandedLabelWhenSelected = showsExpanded;
  [self setSelected:isSelected];
}

- (BOOL)showsExpandedLabelWhenSelected
{
  return showsExpandedLabelWhenSelected;
}

- (NSUInteger)modifierFlags
{
  return modifierFlags;
}

//-----------------------------------------------------------------------------
// Dragging (NSDraggingSource)
//-----------------------------------------------------------------------------
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return [delegate draggingSourceOperationMaskForLocal:isLocal
						  icon:self];
}

//-----------------------------------------------------------------------------
// Dragging (NSDraggingDestination)
//-----------------------------------------------------------------------------

// Before the Image is Released

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(draggingEntered:icon:)]) {
    dragEnteredResult = [delegate draggingEntered:sender icon:self];
    return dragEnteredResult;
  }
  else {
    return NSDragOperationNone;
  }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(draggingUpdated:icon:)]) {
    return [delegate draggingUpdated:sender icon:self];
  }
  else {
    return dragEnteredResult;
  }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(draggingExited:icon:)]) {
    [delegate draggingExited:sender icon:self];
  }
}

// After the Image is Released

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(prepareForDragOperation:icon:)]) {
    return [delegate prepareForDragOperation:sender icon:self];
  }
  else {
    return NO;
  }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(performDragOperation:icon:)]) {
    return [delegate performDragOperation:sender icon:self];
  }
  else {
    return NO;
  }
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(concludeDragOperation:icon:)]) {
    [delegate concludeDragOperation:sender icon:self];
  }
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
  if (delegate &&
      [delegate respondsToSelector:@selector(draggingEnded:icon:)]) {
    [delegate draggingEnded: sender icon: self];
  }
}

//-----------------------------------------------------------------------------
// Overridings
//-----------------------------------------------------------------------------
- (BOOL)acceptsFirstResponder
{
  return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
}

@end

@implementation NXTIcon (Private)

- (void)rebuildCollapsedLabelString
{
  NSString *str = NXTShortenString(labelString,
                                   maximumCollapsedLabelWidth,
                                   [shortLabel font],
                                   NXSymbolElement,
                                   NXTDotsAtRight);
  [shortLabel setString:str];
  [shortLabel adjustFrame];
}

@end
