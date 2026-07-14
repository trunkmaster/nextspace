/* Implementation of class NSTableCellView
   Copyright (C) 2022 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 12-12-2022

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

#import "AppKit/NSTableCellView.h"
#import "AppKit/NSImageView.h"
#import "AppKit/NSTextField.h"

@implementation NSTableCellView

- (instancetype) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self != nil)
    {
      _rowSizeStyle = NSTableViewRowSizeStyleDefault;
      _backgroundStyle = NSBackgroundStyleLight;
    }
  return self;
}

- (instancetype) init
{
  return [self initWithFrame: NSZeroRect];
}

- (void) dealloc
{
  RELEASE(_objectValue);
  RELEASE(_imageView);
  RELEASE(_textField);
  RELEASE(_draggingImageComponents);

  [super dealloc];
}

- (id) objectValue
{
  return _objectValue;
}

- (void) setObjectValue: (id)objectValue
{
  ASSIGN(_objectValue, objectValue);
}

- (NSImageView *) imageView
{
  return _imageView;
}

- (void) setImageView: (NSImageView *)imageView
{
  ASSIGN(_imageView, imageView);
}

- (NSTextField *) textField
{
  return _textField;
}

- (void) setTextField: (NSTextField *)textField
{
  ASSIGN(_textField, textField);
}

- (NSBackgroundStyle) backgroundStyle
{
  return _backgroundStyle;
}

- (void) setBackgroundStyle: (NSBackgroundStyle)backgroundStyle
{
  _backgroundStyle = backgroundStyle;
}

- (NSTableViewRowSizeStyle) rowSizeStyle
{
  return _rowSizeStyle;
}

- (void) setRowSizeStyle: (NSTableViewRowSizeStyle)rowSizeStyle
{
  _rowSizeStyle = rowSizeStyle;
}

- (NSArray *) draggingImageComponents
{
  return _draggingImageComponents;
}

- (void) setDraggingImageComponents: (NSArray *)draggingImageComponents
{
  ASSIGNCOPY(_draggingImageComponents, draggingImageComponents);
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: [self objectValue]
		   forKey: @"NSObjectValue"];
      [coder encodeObject: [self imageView]
		   forKey: @"NSImageView"];
      [coder encodeObject: [self textField]
		   forKey: @"NSTextField"];
      [coder encodeInt: [self backgroundStyle]
		forKey: @"NSBackgroundStyle"];
      [coder encodeInt: [self rowSizeStyle]
		forKey: @"NSTableViewRowSizeStyle"];
      [coder encodeObject: [self draggingImageComponents]
		   forKey: @"NSDraggingImageComponents"];
    }
  else
    {
      [coder encodeObject: _objectValue];
      [coder encodeObject: _imageView];
      [coder encodeObject: _textField];
      [coder encodeObject: _draggingImageComponents];

      [coder encodeValueOfObjCType: @encode(NSBackgroundStyle)
				at: &_backgroundStyle];
      [coder encodeValueOfObjCType: @encode(NSTableViewRowSizeStyle)
				at: &_rowSizeStyle];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
	{
	  if ([coder containsValueForKey: @"NSObjectValue"])
	    {
	      [self setObjectValue: [coder decodeObjectForKey: @"NSObjectValue"]];	      
	    }

	  if ([coder containsValueForKey: @"NSImageView"])
	    {
	      [self setImageView: [coder decodeObjectForKey: @"NSImageView"]];	      
	    }

	  if ([coder containsValueForKey: @"NSTextField"])
	    {
	      [self setTextField: [coder decodeObjectForKey: @"NSTextField"]];	      
	    }
	  
	  if ([coder containsValueForKey: @"NSBackgroundStyle"])
	    {
	      [self setBackgroundStyle: [coder decodeIntForKey: @"NSBackgroundStyle"]];
	    }

	  if ([coder containsValueForKey: @"NSTableViewRowSizeStyle"])
	    {
	      [self setRowSizeStyle: [coder decodeIntForKey: @"NSTableViewRowSizeStyle"]];
	    }

	  if ([coder containsValueForKey: @"NSDraggingImageComponents"])
	    {
	      [self setDraggingImageComponents: [coder decodeObjectForKey: @"NSDraggingImageComponents"]];
	    }
	}
      else
	{
	  [self setObjectValue: [coder decodeObject]];
	  [self setImageView: [coder decodeObject]];
	  [self setTextField: [coder decodeObject]];
	  [self setDraggingImageComponents: [coder decodeObject]];
	  
	  [coder decodeValueOfObjCType: @encode(NSBackgroundStyle)
				    at: &_backgroundStyle];
	  [coder decodeValueOfObjCType: @encode(NSTableViewRowSizeStyle)
				    at: &_rowSizeStyle];	  
	}
    }
  return self;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSTableCellView *copy = [[NSTableCellView allocWithZone: zone] init];

  [copy setObjectValue: [self objectValue]];
  [copy setImageView: [self imageView]];
  [copy setTextField: [self textField]];
  [copy setDraggingImageComponents: [self draggingImageComponents]];
  [copy setBackgroundStyle: [self backgroundStyle]];
  [copy setRowSizeStyle: [self rowSizeStyle]];

  return copy;
}

@end
