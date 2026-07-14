/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

   Authors: Serg Stoyan

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <AppKit/AppKit.h>

#import <ProjectCenter/PCFileNameField.h>

NSString *PCFileNameFieldNoFiles = @"No files selected";

@implementation PCFileNameField

- (void)setFont:(NSFont *)fontObject
{
  NSLog(@"PCFNF: setFont");
}

- (void)setEditableField:(BOOL)yn
{
  NSRect frame = [self frame];
  NSRect fontFrame = [[self font] boundingRectForFont];

//  NSLog (@"TF height: %f font height: %f", 
//	 frame.size.height, fontFrame.size.height);

  if ([self textShouldSetEditable:[self stringValue]] == NO)
    {
      return;
    }

  // Correct self size wrt font bounding rect
  if (frame.size.height > fontFrame.size.height+3)
    {
      frame.origin.y += (frame.size.height - (fontFrame.size.height+3))/2;
      frame.size.height = fontFrame.size.height+3;
    }

  if (yn == YES)
    {
      frame.size.width += 4;
      if ([self alignment] != NSRightTextAlignment)
	{
	  frame.origin.x -= 4;
	}
      [self setFrame:frame];
      
      [self setBordered:YES];
      [self setBackgroundColor:[NSColor whiteColor]];
      [self setEditable:YES];
      [self setNeedsDisplay:YES];
      [[self superview] setNeedsDisplay:YES];
    }
  else
    {
      frame.size.width -= 4;
      if ([self alignment] != NSRightTextAlignment)
	{
	  frame.origin.x += 4;
	}
      [self setFrame:frame];

      [self setBackgroundColor:[NSColor lightGrayColor]];
      [self setBordered:NO];
      [self setEditable:NO];
      [self setNeedsDisplay:YES];
      [[self superview] setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self setEditableField:YES];
  [super mouseDown:theEvent];
}

- (void)setStringValue:(NSString *)aString
{
  id  delegate = [self delegate];
  SEL action = @selector(controlStringValueDidChange:);

  [super setStringValue:aString];

  if ([delegate respondsToSelector:action])
    {
      [delegate performSelector:action withObject:aString];
    }
}

- (BOOL)textShouldSetEditable:(NSString *)text
{
  id delegate = [self delegate];

  if ([text isEqualToString:PCFileNameFieldNoFiles])
    {
      return NO;
    }

  if ([delegate respondsToSelector:@selector(textShouldSetEditable:)])
    {
      return [delegate textShouldSetEditable:text];
    }

  return YES;
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
  [self setEditableField:NO];
  [super textDidEndEditing:aNotification];
}

@end

