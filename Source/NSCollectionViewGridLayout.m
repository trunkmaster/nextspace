/* Implementation of class NSCollectionViewGridLayout
   Copyright (C) 2021 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 30-05-2021

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

#import "AppKit/NSCollectionViewGridLayout.h"

#import "GSGuiPrivate.h"

@implementation NSCollectionViewGridLayout

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self)
    {
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSMaximumNumberOfRows"])
            {
              _maximumNumberOfRows = [coder decodeIntegerForKey: @"NSMaximumNumberOfRows"];
            }

          if ([coder containsValueForKey: @"NSMaximumNumberOfColumns"])
            {
              _maximumNumberOfColumns = [coder decodeIntegerForKey: @"NSMaximumNumberOfColumns"];
            }

          if ([coder containsValueForKey: @"NSMaximumItemSize"])
            {
              _maximumItemSize = [coder decodeSizeForKey: @"NSMaximumItemSize"];
            }
          
          if ([coder containsValueForKey: @"NSMinimumItemSize"])
            {
              _minimumItemSize = [coder decodeSizeForKey: @"NSMinimumItemSize"];
            }
          
          if ([coder containsValueForKey: @"NSMinimumInteritemSpacing"])
            {
              _minimumInteritemSpacing = [coder decodeFloatForKey: @"NSMinimumInteritemSpacing"];
            }
          
          // margins...
          if ([coder containsValueForKey: @"NSCollectionViewGridLayoutMargins.bottom"])
            {
              _margins.bottom = [coder decodeFloatForKey: @"NSCollectionViewGridLayoutMargins.bottom"];
            }

          if ([coder containsValueForKey: @"NSCollectionViewGridLayoutMargins.top"])
            {
              _margins.top = [coder decodeFloatForKey: @"NSCollectionViewGridLayoutMargins.top"];
            }

          if ([coder containsValueForKey: @"NSCollectionViewGridLayoutMargins.left"])
            {
              _margins.left = [coder decodeFloatForKey: @"NSCollectionViewGridLayoutMargins.left"];
            }

          if ([coder containsValueForKey: @"NSCollectionViewGridLayoutMargins.right"])
            {
              _margins.right = [coder decodeFloatForKey: @"NSCollectionViewGridLayoutMargins.right"];
            }
        }
      else
        {
          decode_NSUInteger(coder, &_maximumNumberOfRows); 
          decode_NSUInteger(coder, &_maximumNumberOfColumns);
          
          _maximumItemSize = [coder decodeSize];
          _minimumItemSize = [coder decodeSize];
          
          [coder decodeValueOfObjCType: @encode(CGFloat) at: &_minimumInteritemSpacing];
          [coder decodeValueOfObjCType: @encode(CGFloat) at: &_margins.bottom];
          [coder decodeValueOfObjCType: @encode(CGFloat) at: &_margins.top];
          [coder decodeValueOfObjCType: @encode(CGFloat) at: &_margins.left];
          [coder decodeValueOfObjCType: @encode(CGFloat) at: &_margins.right];        
        }
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _maximumNumberOfRows
                    forKey: @"NSMaximumNumberOfRows"];
      [coder encodeInteger: _maximumNumberOfColumns
                    forKey: @"NSMaximumNumberOfColumns"];

      [coder encodeSize: _maximumItemSize
                 forKey: @"NSMaximumItemSize"];
      [coder encodeSize: _minimumItemSize
                 forKey: @"NSMinimumItemSize"];

      [coder encodeFloat: _minimumInteritemSpacing
                  forKey: @"NSMinimumInteritemSpacing"];
      
      [coder encodeFloat: _margins.bottom
                  forKey: @"NSCollectionViewGridLayoutMargins.bottom"];
      [coder encodeFloat: _margins.top
                  forKey: @"NSCollectionViewGridLayoutMargins.top"];
      [coder encodeFloat: _margins.left
                  forKey: @"NSCollectionViewGridLayoutMargins.left"];
      [coder encodeFloat: _margins.right
                  forKey: @"NSCollectionViewGridLayoutMargins.right"];
    }
  else
    {
      encode_NSUInteger(coder, &_maximumNumberOfRows);
      encode_NSUInteger(coder, &_maximumNumberOfColumns);

      [coder encodeSize: _maximumItemSize];
      [coder encodeSize: _minimumItemSize];

      [coder encodeValueOfObjCType: @encode(CGFloat) at: &_minimumInteritemSpacing];
      [coder encodeValueOfObjCType: @encode(CGFloat) at: &_margins.bottom];
      [coder encodeValueOfObjCType: @encode(CGFloat) at: &_margins.top];
      [coder encodeValueOfObjCType: @encode(CGFloat) at: &_margins.left];
      [coder encodeValueOfObjCType: @encode(CGFloat) at: &_margins.right];
    }
}

- (void) setMaximumNumberOfRows: (NSUInteger)maxRows
{
  _maximumNumberOfRows = maxRows;
}

- (NSUInteger) maximumNumberOfRows
{
  return _maximumNumberOfRows;
}

- (void) setMaximumNumberOfColumns: (NSUInteger)maxCols
{
  _maximumNumberOfColumns = maxCols;
}

- (NSUInteger) maximumNumberOfColumns
{
  return _maximumNumberOfColumns;
}

- (void) setMinimumItemSize: (NSSize)minSize
{
  _minimumItemSize = minSize;
}

- (NSSize) minimumItemSize
{
  return _minimumItemSize;
}

- (void) setMaximumItemSize: (NSSize)maxSize
{
  _maximumItemSize = maxSize;
}

- (NSSize) maximumItemSize
{
  return _maximumItemSize;
}

- (void) setMargins: (NSEdgeInsets)insets
{
  _margins = insets;
}

- (NSEdgeInsets) margins
{
  return _margins;
}

- (void) setMinimumInteritemSpacing: (CGFloat)spacing
{
  _minimumInteritemSpacing = spacing;
}
  
- (CGFloat) minimumInteritemSpacing
{
  return _minimumInteritemSpacing;
}

// Methods to override for specific layouts...
- (NSCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath: (NSIndexPath *)indexPath
{
  NSCollectionViewLayoutAttributes *attrs = AUTORELEASE([[NSCollectionViewLayoutAttributes alloc] init]);
  NSSize sz = NSZeroSize;
  NSInteger s = [indexPath section];
  NSInteger r = [indexPath item];
  NSEdgeInsets si;
  CGFloat mls = 0.0;
  CGFloat mis = 0.0;
  CGFloat h = 0.0, w = 0.0, x = 0.0, y = 0.0;
  NSRect f = NSZeroRect;
  NSRect vf = [_collectionView frame];
  NSInteger ns = [_collectionView numberOfSections];
  NSInteger ni = [_collectionView numberOfItemsInSection: s];
  CGFloat ph = 0.0;
  CGFloat pw = 0.0;
  
  sz = [self minimumItemSize];
  si = [self margins];
  mls = [self minimumInteritemSpacing];
  mis = [self minimumInteritemSpacing];

  // Calculations...
  h = sz.height;
  ph = vf.size.height / ns;
  if (ph > sz.height)
    {
      NSSize mx = [self maximumItemSize];
      if (ph > mx.height)
        {
          ph = mx.height;
        }
      h = ph;
    }
  
  w = sz.width;
  pw = vf.size.width / ni;
  if (pw > sz.width)
    {
      NSSize mx = [self maximumItemSize];
      if (pw > mx.width)
        {
          pw = mx.width;
        }
      w = pw;
    }
  
  x = (r * w) + si.left + mis;
  y = (s * h) + si.top + mls;
  f = NSMakeRect(x, y, w, h);

  // Build attrs object...
  [attrs setFrame: f];
  [attrs setZIndex: 0];
  [attrs setSize: f.size];
  [attrs setHidden: NO];
  [attrs setAlpha: 1.0];

  return attrs;
}

- (NSSize) collectionViewContentSize
{
  return [_collectionView frame].size;
}

@end
