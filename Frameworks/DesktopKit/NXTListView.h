/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2019- Sergii Stoian
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

#include <AppKit/AppKit.h>

@class NXTListMatrix;

@interface NXTListView : NSView
{
  NXTListMatrix *listMatrix;
  NSScrollView  *scrollView;
  NSColor       *backgroundColor;
  NSColor       *selBackgroundColor;

  // Items loading related
  BOOL       initialLoadDidComplete;
  unsigned   items_count;
  NSSize     cellSize;  
}

- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects;
- (void)addItemWithTitle:(NSAttributedString *)title
       representedObject:(id)object;
- (void)setTarget:(id)target;
- (void)setAction:(SEL)action;
- (void)setBackgroundColor:(NSColor *)color;
- (void)setSelectionBackgroundColor:(NSColor *)color;

- (id)selectedItem;
- (void)selectItemAtIndex:(NSInteger)index;
- (NSCell *)itemAtIndex:(NSInteger)index;
- (NSInteger)indexOfItem:(NSCell *)item;
- (NSInteger)indexOfItemWithObjectRep:(id)object;
- (NSInteger)indexOfItemWithStringRep:(NSString *)string;

@end
