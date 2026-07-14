/* Implementation of class NSAutoresizingMaskLayoutConstraint
   Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson <benjaminkylejohnson@gmail.com>
   Date: 2023

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/
#import "NSAutoresizingMaskLayoutConstraint.h"

@implementation NSAutoresizingMaskLayoutConstraint

static NSUInteger minXAttribute = 32;
static NSUInteger minYAttribute = 33;
static NSUInteger maxXAttribute = 36;
static NSUInteger maxYAttribute = 37;

+ (NSAutoresizingMaskLayoutConstraint *)
    _xConstraintForAutoresizingMask: (NSAutoresizingMaskOptions)autoresizingMask
                            subitem: (NSView *)subItem
                              frame: (NSRect)frame
                          superitem: (NSView *)superItem
                             bounds: (NSRect)bounds
{
  if ((autoresizingMask & NSViewMinXMargin)
      && (autoresizingMask & NSViewMaxXMargin))
    {
      CGFloat width = bounds.size.width - frame.size.width;
      CGFloat x = frame.origin.x - bounds.origin.x;
      CGFloat xWidthRatio = x / width;
      CGFloat constant = xWidthRatio * frame.size.width * -1;

      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minXAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: superItem
                   attribute: NSLayoutAttributeWidth
                  multiplier: xWidthRatio
                    constant: constant];
    }
  else if (autoresizingMask & NSViewMinXMargin)
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: superItem
                   attribute: NSLayoutAttributeWidth
                   relatedBy: NSLayoutRelationEqual
                      toItem: subItem
                   attribute: maxXAttribute
                  multiplier: 1.0
                    constant: (frame.size.width + frame.origin.x
                              - bounds.size.width - bounds.origin.x)
                             * -1];
    }
  else if (autoresizingMask & NSViewMaxXMargin)
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minXAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: frame.origin.x - bounds.origin.x];
    }
  else
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minXAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: frame.origin.x - bounds.origin.x];
    }
}

+ (NSAutoresizingMaskLayoutConstraint *)
    _yConstraintForAutoresizingMask: (NSAutoresizingMaskOptions)autoresizingMask
                            subitem: (NSView *)subItem
                              frame: (NSRect)frame
                          superitem: (NSView *)superItem
                             bounds: (NSRect)bounds
{
  if ((autoresizingMask & NSViewMinYMargin)
      && (autoresizingMask & NSViewMaxYMargin))
    {
      CGFloat height = bounds.size.height - frame.size.height;
      CGFloat y = frame.origin.y - bounds.origin.y;
      CGFloat yHeightRatio = y / height;
      CGFloat constant = yHeightRatio * frame.size.height * -1;

      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minYAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: superItem
                   attribute: NSLayoutAttributeHeight
                  multiplier: yHeightRatio
                    constant: constant];
    }
  else if (autoresizingMask & NSViewMinYMargin)
    {
      CGFloat constant = ((frame.size.height + frame.origin.y)
                          - (bounds.size.height + bounds.origin.y))
                         * -1;
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: superItem
                   attribute: NSLayoutAttributeHeight
                   relatedBy: NSLayoutRelationEqual
                      toItem: subItem
                   attribute: maxYAttribute
                  multiplier: 1.0
                    constant: constant];
    }
  else if (autoresizingMask & NSViewMaxYMargin)
    {
      CGFloat constant = (frame.origin.y - bounds.origin.y);
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minYAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: constant];
    }
  else
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: minYAttribute
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: frame.origin.y - bounds.origin.y];
    }
}

+ (NSAutoresizingMaskLayoutConstraint *)
    _widthConstraintForAutoresizingMask:
        (NSAutoresizingMaskOptions)autoresizingMask
                                subitem: (NSView *)subItem
                                  frame: (NSRect)frame
                              superitem: (NSView *)superItem
                                 bounds: (NSRect)bounds
{
  if (autoresizingMask & NSViewWidthSizable)
    {
      CGFloat widthConstant = ((frame.size.width + frame.origin.x)
                               - (bounds.origin.x + bounds.size.width))
                              * -1;
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: superItem
                   attribute: NSLayoutAttributeWidth
                   relatedBy: NSLayoutRelationEqual
                      toItem: subItem
                   attribute: maxXAttribute
                  multiplier: 1.0
                    constant: widthConstant];
    }
  else
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: NSLayoutAttributeWidth
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: frame.size.width];
    }
}

+ (NSAutoresizingMaskLayoutConstraint *)
    _heightConstraintForAutoresizingMask:
        (NSAutoresizingMaskOptions)autoresizingMask
                                 subitem: (NSView *)subItem
                                   frame: (NSRect)frame
                               superitem: (NSView *)superItem
                                  bounds: (NSRect)bounds
{
  if (autoresizingMask & NSViewHeightSizable)
    {
      CGFloat heightConstant = (frame.size.height + frame.origin.y
                                - (bounds.origin.y + bounds.size.height))
                               * -1;
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: superItem
                   attribute: NSLayoutAttributeHeight
                   relatedBy: NSLayoutRelationEqual
                      toItem: subItem
                   attribute: maxYAttribute
                  multiplier: 1.0
                    constant: heightConstant];
    }
  else
    {
      return [NSAutoresizingMaskLayoutConstraint
          constraintWithItem: subItem
                   attribute: NSLayoutAttributeHeight
                   relatedBy: NSLayoutRelationEqual
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: frame.size.height];
    }
}

+ (NSArray *)constraintsWithAutoresizingMask:
                 (NSAutoresizingMaskOptions) autoresizingMask
                                     subitem: (NSView *) subItem
                                       frame: (NSRect) frame
                                   superitem: (NSView *) superItem
                                      bounds: (NSRect) bounds
{
  if (autoresizingMask == NSViewNotSizable)
    {
      return [NSArray array];
    }

  NSAutoresizingMaskLayoutConstraint *xConstraint =
      [self _xConstraintForAutoresizingMask: autoresizingMask
                                    subitem: subItem
                                      frame: frame
                                  superitem: superItem
                                     bounds: bounds];
  NSAutoresizingMaskLayoutConstraint *yConstraint =
      [self _yConstraintForAutoresizingMask: autoresizingMask
                                    subitem: subItem
                                      frame: frame
                                  superitem: superItem
                                     bounds: bounds];
  NSAutoresizingMaskLayoutConstraint *widthConstraint =
      [self _widthConstraintForAutoresizingMask: autoresizingMask
                                        subitem: subItem
                                          frame: frame
                                      superitem: superItem
                                         bounds: bounds];
  NSAutoresizingMaskLayoutConstraint *heightConstraint =
      [self _heightConstraintForAutoresizingMask: autoresizingMask
                                         subitem: subItem
                                           frame: frame
                                       superitem: superItem
                                          bounds: bounds];

  NSMutableArray *constraints = [NSMutableArray arrayWithCapacity:4];

  // The order of constraints was determined from MacOS behaviour.
  // For the majority of users it will not matter, but we should assume that users have coupled to the ordering.
  if ((autoresizingMask & NSViewMinXMargin)
      && (autoresizingMask & NSViewMaxXMargin))
    {
      [constraints addObject: widthConstraint];
      [constraints addObject: xConstraint];
    }
  else
    {
      [constraints addObject: xConstraint];
      [constraints addObject: widthConstraint];
    }

  if ((autoresizingMask & NSViewMinYMargin)
      && (autoresizingMask & NSViewMaxYMargin))
    {
      [constraints addObject: heightConstraint];
      [constraints addObject: yConstraint];
    }
  else
    {
      [constraints addObject: yConstraint];
      [constraints addObject: heightConstraint];
    }

  return constraints;
}

@end
