/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015-2019 Sergii Stoian
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

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTIcon.h>
#import <DesktopKit/NXTIconLabel.h>

#import "FileViewer.h"
#import "PathIcon.h"
#import "PathView.h"
#import "PathViewScroller.h"

#define BROWSER_DEF_COLUMN_WIDTH 180

@implementation PathView

- (void)dealloc
{
  TEST_RELEASE(_path);
  TEST_RELEASE(_files);
  TEST_RELEASE(_multiIcon);
  TEST_RELEASE(_iconDragTypes);

  [super dealloc];
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer
{
  PathViewScroller *scroller;
  NSScrollView *sv;

  self = [super initWithFrame:r];
  [self updateSlotSize];

  _owner = fileViewer;

  // Options
  allowsMultipleSelection = NO;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;
  autoAdjustsToFitIcons = YES;
  adjustsToFillEnclosingScrollView = NO;
  fillWithHoleWhenRemovingIcon = NO;
  isSlotsTallFixed = YES;
  slotsTall = 1;

  sv = [self enclosingScrollView];
  scroller = [[PathViewScroller new] autorelease];
  [scroller setDelegate:self];
  [sv setHorizontalScroller:scroller];
  [sv setHasHorizontalScroller:YES];
  [sv setBackgroundColor:[NSColor windowBackgroundColor]];

  [self setDelegate:self];
  [self setTarget:self];
  [self setAction:@selector(iconClicked:)];
  [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(iconDragged:event:)];
  [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];

  // [[NSPasteboard generalPasteboard] declareTypes:@[NSFilenamesPboardType] owner:nil];
  // ASSIGN(_iconDragTypes, @[NSFilenamesPboardType]);
  // [icons makeObjectsPerform:@selector(unregisterDraggedTypes)];
  // [icons makeObjectsPerform:@selector(registerForDraggedTypes:)
  //       	 withObject:_iconDragTypes];

  _arrowImage = [[NSImage alloc]
      initByReferencingFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"RightArrow"
                                                                             ofType:@"tiff"]];

  _multiImage = [[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[self class]]
                                                           pathForResource:@"MultipleSelection"
                                                                    ofType:@"tiff"]];

  _multiIcon = [[PathIcon alloc] init];
  [_multiIcon setIconImage:_multiImage];
  [_multiIcon setLabelString:@"Multiple items"];
  [_multiIcon setEditable:NO];
  // this is not a dragging destination
  [_multiIcon unregisterDraggedTypes];

  return self;
}

- (void)updateSlotSize
{
  NSSize size;

  size.height = PATH_VIEW_HEIGHT;
  size.width = [[OSEDefaults userDefaults] floatForKey:@"BrowserViewerColumnWidth"];
  if (size.width <= 0) {
    size.width = BROWSER_DEF_COLUMN_WIDTH;
  }
  [self setSlotSize:size];
}

- (void)drawRect:(NSRect)r
{
  // NSDebugLLog(@"PathView", @"drawRect of PathView at origin: %.0f, %.0f with size: %.0f x %.0f",
  //             r.origin.x, r.origin.y, r.size.width, r.size.height);

  for (unsigned int i = 1, n = [icons count]; i < n; i++) {
    NSPoint p;

    p = NSMakePoint((i * slotSize.width) - ([_arrowImage size].width + 5), slotSize.height / 2);

    p.x = floorf(p.x);
    p.y = floorf(p.y);
    [_arrowImage compositeToPoint:p operation:NSCompositeSourceOver];
  }

  [super drawRect:r];
}

- (void)setPath:(NSString *)relativePath selection:(NSArray *)filenames
{
  PathIcon *pathIcon;
  NXTIconLabel *pathIconLabel;
  id<Viewer> theViewer = [_owner viewer];
  NSUInteger length;
  NSUInteger componentsCount = [[relativePath pathComponents] count];
  NSUInteger i, n;
  NSUInteger lii;  // last icon index in array of icons
  PathIcon *icon;
  NSString *path = @"";

  // NSDebugLLog(@"PathView", @"PathView: setPath:`%@` selection:`%@`", relativePath, filenames);

  if (delegate == nil) {
    NSDebugLLog(@"PathView", @"PathView: attempt to set path without a delegate "
                             @"assigned to define the icons to use.");
    return;
  }

  length = [relativePath length];

  // Remove a trailing "/" character from 'aPath'
  if (length > 1 && [relativePath characterAtIndex:length - 1] == '/') {
    relativePath = [relativePath substringToIndex:length - 1];
  }

  // NSDebugLLog(@"PathView", @"[PathView] displayDirectory:%@(%i) andFiles:%@", aPath,
  //             [[aPath pathComponents] count], aFiles);

  // NSDebugLLog(@"PathView", @"1. [PathView] icons count: %i components: %i", [icons count],
  //             componentsCount);

  if ([icons count] > [self slotsWide]) {
    NSDebugLLog(@"PathView", @"WARNING!!! # of icons > slotsWide! PathView must have 1 row!");
  }

  // Always clear last time selection
  [[icons lastObject] deselect:nil];
  [[icons lastObject] setEditable:NO];

  // Remove trailing icons
  lii = componentsCount;
  if ([filenames count] > 0) {
    lii++;
  }

  for (n = [icons count], i = lii; i < n; i++) {
    PathIcon *itr = nil;
    // NSDebugLLog(@"PathView", @"[PathView] remove icon [%@] in slot: %i(%i)", [icons lastObject], i,
    //             [icons count]);
    // [self removeIconInSlot:NXTMakeIconSlot(i, 0)];
    itr = [icons lastObject];
    [self removeIcon:itr];
  }
  if ([icons lastObject] == _multiIcon) {
    // to avoid setting attributes by file selection
    [self removeIcon:_multiIcon];
  }

  // NSDebugLLog(@"PathView", @"2. [PathView] icons count: %lu components: %lu %@", [icons count],
  //             componentsCount, [aPath pathComponents]);

  // Set icons for path of "folders"
  if (![path isEqualToString:relativePath]) {
    NSArray *pathComponents = [relativePath pathComponents];

    ASSIGN(_path, relativePath);

    for (i = 0; i < componentsCount; i++) {
      NSString *component = [pathComponents objectAtIndex:i];

      path = [path stringByAppendingPathComponent:component];

      if (i < [icons count]) {
        icon = [icons objectAtIndex:i];
      } else {
        icon = [[PathIcon new] autorelease];
        [icon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
        [icon setLabelString:@"-"];
        [icon setDoubleClickPassesClick:NO];
        [self setSlotsWide:i + 1];
        [self putIcon:icon intoSlot:NXTMakeIconSlot(i, 0)];
      }
      [icon deselect:nil];
      [icon setEditable:NO];
      [icon setIconImage:[self imageForPath:path]];
      [icon setPaths:[_owner absolutePathsForPaths:@[ path ]]];
    }
  }

  // files == nil also make sense later
  ASSIGN(_files, filenames);

  // Set icon for file or files
  if (_files != nil && [_files count] > 0) {
    i = componentsCount;

    if ([_files count] == 1) {
      path = [path stringByAppendingPathComponent:[_files objectAtIndex:0]];
      if (componentsCount < [icons count]) {
        icon = [icons objectAtIndex:componentsCount];
      } else {
        // NSDebugLLog(@"PathView", @"[PathView] creating new icon with path: %@", path);
        icon = [[PathIcon new] autorelease];
        [icon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
        [icon setLabelString:@"-"];
        [icon setDoubleClickPassesClick:NO];
        [self setSlotsWide:i + 1];
        [self putIcon:icon intoSlot:NXTMakeIconSlot(i, 0)];
      }
      [icon deselect:nil];
      [icon setEditable:NO];
      [icon setIconImage:[self imageForPath:path]];
      [icon setPaths:[_owner absolutePathsForPaths:@[ path ]]];
    } else {
      NSMutableArray *relPaths = [[NSMutableArray new] autorelease];

      for (NSString *file in _files) {
        [relPaths addObject:[path stringByAppendingPathComponent:file]];
      }

      if ([icons indexOfObjectIdenticalTo:_multiIcon] == NSNotFound) {
        [self setSlotsWide:i + 1];
        [self putIcon:_multiIcon intoSlot:NXTMakeIconSlot(i, 0)];
      }
      [_multiIcon setPaths:[_owner absolutePathsForPaths:relPaths]];
    }
  }
  [self selectIcons:[NSSet setWithObject:[icons lastObject]]];

  [self scrollPoint:NSMakePoint([self frame].size.width, 0)];

  // First icon
  [[icons objectAtIndex:0] setEditable:NO];

  // Last icon
  pathIcon = [icons lastObject];
  [pathIcon setEditable:YES];
  [pathIcon setNextKeyView:[theViewer keyView]];

  // Last icon label
  pathIconLabel = [pathIcon label];
  [pathIconLabel setNextKeyView:[theViewer keyView]];
  [pathIconLabel setIconLabelDelegate:_owner];

  [icons makeObjectsPerform:@selector(setDelegate:) withObject:self];
}

- (NSImage *)imageForPath:(NSString *)aPath
{
  NSString *fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  // NSDebugLLog(@"PathView", @"[FileViewer] imageForIconAtPath: %@", aPath);
  fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  return [[NSApp delegate] iconForFile:fullPath];
}

- (NSString *)path
{
  return _path;
}

- (NSArray *)files
{
  return _files;
}

- (NSUInteger)visibleColumnCount
{
  return [[self superview] bounds].size.width / slotSize.width;
}

// Called by dispatcher (FileViewer-displayPath:...) according to
// the viewer (Browser) columns position
- (void)setNumberOfEmptyColumns:(NSInteger)num
{
  NSInteger iconsNum = [icons count];
  NSInteger width = [self slotsWide];
  NSInteger emptiesNum = width - iconsNum;

  // NSDebugLLog(@"PathView",
  //             @"[Pathview setNumberOfEmptyColumns] icons count: %i slots wide: %i # of empty: %i",
  //             iconsNum, width, num);
  if (emptiesNum != num) {
    [self setSlotsWide:iconsNum + num];
  }
}

- (NSInteger)numberOfEmptyColumns
{
  return [self slotsWide] - [icons count];
}

- (void)syncEmptyColumns
{
  NSUInteger numEmptyCols = 0;
  id<Viewer> viewer = [_owner viewer];
  NSArray *selection = [_owner selection];

  // Set empty columns to PathView
  numEmptyCols = [viewer numberOfEmptyColumns];

  NSDebugLLog(@"FilViewer", @"pathViewSyncEmptyColumns: selection: %@", selection);

  // Browser has empty columns and file(s) selected
  if (selection && [selection count] >= 1 && numEmptyCols > 0) {
    numEmptyCols--;
  }
  [self setNumberOfEmptyColumns:numEmptyCols];
}

- (void)iconClicked:sender
{
  NSArray *pathList;

  NSDebugLLog(@"PathView", @"[PathView] icon clicked, sender: %@ %@", [sender className],
              [self pathsForIcon:sender]);
  if ([sender isKindOfClass:[PathView class]]) {
    [super iconClicked:sender];
    return;
  }
  // do not unselect the last icon
  if ([icons lastObject] == sender) {
    return;
  }
  pathList = [self pathsForIcon:sender];
  if ([pathList count] > 1) {
    return;
  }
  [_owner displayPath:[pathList lastObject] selection:nil sender:self];
}

- (void)iconDoubleClicked:sender
{
  // only allow the last icon to be double-clicked
  NSDebugLLog(@"PathView", @"[PathView] iconDoubleClicked: %@ (%@)", [sender className],
              [[sender paths] lastObject]);

  [_owner open:sender];

  // double-click can be received by not last icon if PathView content
  // was scrolled between first and second click.
  if ([icons lastObject] != sender) {
    [self selectIcons:[NSSet setWithObject:[icons lastObject]]];
  }
}

- (NSArray *)pathsForIcon:(NXTIcon *)icon
{
  NSUInteger idx = [icons indexOfObjectIdenticalTo:icon];

  if (idx == NSNotFound) {
    return nil;
  }

  if ([_files count] > 0 && icon == [icons lastObject]) {
    NSMutableArray *array = [NSMutableArray array];

    for (NSString *filename in _files) {
      [array addObject:[_path stringByAppendingPathComponent:filename]];
    }
    return [[array copy] autorelease];
  } else {
    NSString *newPath = @"";
    NSEnumerator *pathEnum = [[_path pathComponents] objectEnumerator];
    NSEnumerator *iconEnum = [icons objectEnumerator];

    do {
      newPath = [newPath stringByAppendingPathComponent:[pathEnum nextObject]];
    } while ([iconEnum nextObject] != icon);

    return [NSArray arrayWithObject:newPath];
  }
}

- (void)mouseDown:(NSEvent *)ev
{
  // Do nothing. It prevents icons deselection.
}

- (BOOL)acceptsFirstResponder
{
  // It prevents first responder stealing.
  return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
}

//=============================================================================
// NXTIconView delegate
//=============================================================================
- (void)iconDragged:sender event:(NSEvent *)ev
{
  NSArray *paths;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect iconFrame = [sender frame];
  NSPoint iconLocation = iconFrame.origin;

  _dragSource = self;
  _dragIcon = [sender retain];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if ([icons lastObject] != sender) {
    [sender setSelected:NO];
    [[icons lastObject] setSelected:YES];
  }

  paths = [_dragIcon paths];
  _dragMask = [_owner draggingSourceOperationMaskForPaths:paths];

  [pb declareTypes:@[ NSFilenamesPboardType ] owner:nil];
  [pb setPropertyList:paths forType:NSFilenamesPboardType];

  [self dragImage:[_dragIcon iconImage]
               at:iconLocation  //[ev locationInWindow]
           offset:NSZeroSize
            event:ev
       pasteboard:pb
           source:_dragSource
        slideBack:YES];
}

//=============================================================================
// Drag and drop
//=============================================================================
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return _dragMask;
}

//=============================================================================
// Scroller delegate
//=============================================================================

// Called when user drag scroller's knob
- (void)constrainScroller:(NSScroller *)aScroller
{
  NSUInteger num = slotsWide - [[_owner viewer] columnCount];
  CGFloat v;
  NSRect visibleRect, superRect;

  NSDebugLLog(@"FileViewer", @"PathView # of icons: %lu", [icons count]);

  if (num == 0) {
    v = 0.0;
    [aScroller setFloatValue:0.0 knobProportion:1.0];
  } else {
    v = rintf(num * [aScroller floatValue]) / num;
    [aScroller setFloatValue:v];
  }

  superRect = [[self superview] frame];
  visibleRect =
      NSMakeRect(([self frame].size.width - superRect.size.width) * v, 0, superRect.size.width, 0);
  [self scrollRectToVisible:visibleRect];
}

// Called whenver user click on PathView's scrollbar
- (void)trackScroller:(NSScroller *)aScroller
{
  id<Viewer> viewer = [_owner viewer];
  CGFloat scrollerValue = [aScroller floatValue];
  CGFloat rangeStart;

  // NSDebugLLog(@"PathView", @"0. [FileViewer] document visible rect: %@",
  //             NSStringFromRect([scrollView documentVisibleRect]));
  // NSDebugLLog(@"PathView", @"0. [FileViewer] document rect: %@",
  //             NSStringFromRect([pathView frame]));
  // NSDebugLLog(@"PathView", @"0. [FileViewer] scroll view rect: %@",
  //             NSStringFromRect([scrollView frame]));

  rangeStart = rintf((slotsWide - [viewer columnCount]) * scrollerValue);

  // NSDebugLLog(@"PathView",
  //             @"1. [FileViewer] trackScroller: value %f proportion: %f,"
  //             @"scrolled to range: %0.f - %lu",
  //             sValue, [aScroller knobProportion], rangeStart, viewerColumnCount);

  // Update viewer display
  [viewer scrollToRange:NSMakeRange(rangeStart, [viewer columnCount])];

  // Synchronize positions of icons in PathView and columns
  // in BrowserViewer
  if (_files != nil && [_files count] > 0) {  // file selected
    if (slotsWide - (slotsWide * scrollerValue) <= 1.0) {
      // scrolled maximum to the right
      // scroller value close to 1.0 (e.g. 0.98)
      [viewer setNumberOfEmptyColumns:1];
    } else {
      [self syncEmptyColumns];
    }
  } else {
    [self syncEmptyColumns];
  }

  // Set keyboard focus to last visible column
  [viewer becomeFirstResponder];

  // NSDebugLLog(@"PathView",
  //             @"2. [FileViewer] trackScroller: value %f proportion: %f,"
  //             @"scrolled to range: %0.f - %i",
  //             [aScroller floatValue], [aScroller knobProportion], rangeStart, viewerColumnCount);

  // NSDebugLLog(@"PathView", @"3. [FileViewer] PathView slotsWide = %i, viewerColumnCount = %i",
  //             [pathView slotsWide], viewerColumnCount);
}

@end
