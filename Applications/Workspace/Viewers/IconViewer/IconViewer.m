/*
   Icon Viewer for Workspace Manager (menu item: View > Icon).

   Copyright (C) 2018 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXAppKit/NXAppKit.h>

#import <NXFoundation/NXDefaults.h>
#import <NXFoundation/NXFileManager.h>

#import <Viewers/PathIcon.h>
#import <Viewers/PathView.h>
#include "IconViewer.h"

@implementation ViewerItemsLoader

- (id)initWithIconView:(NXIconView *)view
                  path:(NSString *)dirPath
              contents:(NSArray *)dirContents
             selection:(NSArray *)filenames
{
  [super init];
  
  if (self != nil) {
    iconView = view;
    directoryPath = [[NSString alloc] initWithString:dirPath];
    directoryContents = [dirContents mutableCopy];
    selectedFiles = [[NSArray alloc] initWithArray:filenames];
  }

  return self;
}

- (void)_optimizeItems:(NSMutableArray *)items
              fileView:(NXIconView *)view
{
  NXIcon         *icon;
  NSMutableArray *itemsCopy = [items mutableCopy];
  NSArray        *iconsCopy = [[view icons] copy];

  // Remove non-existing items
  for (NXIcon *icon in iconsCopy) {
    if ([items indexOfObject:[[icon label] text]] == NSNotFound) {
      [view removeIcon:icon];
    }
  }

  // Leave in `items` array items to add.
  for (NSString *filename in itemsCopy) {
    icon = [view iconWithLabelString:filename];
    if (icon) {
      [items removeObject:filename];
    }
  }
  [itemsCopy release];
  [iconsCopy release];
}

- (void)main
{
  NSString     *path;
  PathIcon     *anIcon;
  NSUInteger   slotsWide, x;
  NSMutableSet *selected = [NSMutableSet new];

  NSLog(@"IconView: Begin path loading... %@ [%@]", directoryPath, selectedFiles);

  x = 0;
  slotsWide = [iconView slotsWide];
  // [self _optimizeItems:directoryContents fileView:iconView];
  
  for (NSString *filename in directoryContents) {
    path = [directoryPath stringByAppendingPathComponent:filename];

    // NSLog(@"IconViewer: add icon for: %@", path);

    anIcon = [[PathIcon alloc] init];
    [anIcon setLabelString:filename];
    [anIcon setIconImage:[[NSApp delegate] iconForFile:path]];
    [anIcon setPaths:[NSArray arrayWithObject:path]];

    [iconView performSelectorOnMainThread:@selector(addIcon:)
                               withObject:anIcon
                            waitUntilDone:YES];
    if ([selectedFiles containsObject:filename]) {
      [selected addObject:anIcon];
      [iconView performSelectorOnMainThread:@selector(selectIcons:)
                                 withObject:selected
                              waitUntilDone:YES];
    }
    [anIcon release];

    // x++;
    // if (x >= slotsWide) {
    //   [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
    //                              withObject:nil
    //                           waitUntilDone:YES];
    //   x = 0;
    // }
  }

  NSLog(@"IconView: End path loading...");
  [directoryPath release];
  [directoryContents release];
  [selectedFiles release];
}

- (BOOL)isReady
{
  return YES;
}

@end

@implementation IconViewer

- (void)dealloc
{
  NSLog(@"[IconViewer](%@) -dealloc", rootPath);
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if (itemsLoader != nil) {
    [itemsLoader cancel];
    [itemsLoader release];
  }
  
  TEST_RELEASE(_owner);
  TEST_RELEASE(rootPath);
  TEST_RELEASE(currentPath);
  TEST_RELEASE(selection);

  TEST_RELEASE(view);

  [super dealloc];
}

- init
{
  NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
  NSSize         iconSize;

  [super init];

  // NXIconView
  iconView = [[NXIconView alloc] initSlotsWide:3];
  [iconView setDelegate:self];
  [iconView setTarget:self];
  [iconView setDragAction:@selector(iconDragged:withEvent:)];
  [iconView setAllowsAlphanumericSelection:YES];
  [iconView setSendsDoubleActionOnReturn:YES];
  [iconView setDoubleAction:@selector(open:)];
  [iconView setAutoAdjustsToFitIcons:YES];
  iconSize = [NXIconView defaultSlotSize];
  if ([[NXDefaults userDefaults] objectForKey:@"IconSlotWidth"]) {
    iconSize.width = [[NXDefaults userDefaults] floatForKey:@"IconSlotWidth"]; 
    [iconView setSlotSize:iconSize];
  }
  [iconView registerForDraggedTypes:@[NSFilenamesPboardType]];

  // NSScrollView
  view = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
  [view setBorderType:NSBezelBorder];
  [view setHasVerticalScroller:YES];
  [view setHasHorizontalScroller:NO];

  [view setDocumentView:iconView];
  [iconView setFrame:NSMakeRect(0, 0, [[view contentView] frame].size.width, 0)];
  [iconView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  
  // NSOperation
  operationQ = [[NSOperationQueue alloc] init];
  itemsLoader = nil;
  
  [[NSNotificationCenter defaultCenter]
          addObserver:self
             selector:@selector(iconWidthDidChange:)
                 name:@"IconSlotWidthDidChangeNotification"
               object:nil];
  
  currentPath = nil;
  selection = nil;
  rootPath = @"/";
  
  [iconView release];
  
  return self;
}

//=============================================================================
// <Viewer> protocol methods
//=============================================================================
+ (NSString *)viewerType
{
  return _(@"Icon");
}

+ (NSString *)viewerShortcut
{
  return _(@"I");
}

- (NSView *)view
{
  return view;
}

- (NSView *)keyView
{
  return iconView;
}

- (void)setOwner:(id <FileViewer,NSObject>)owner
{
  ASSIGN(_owner, owner);
}

- (void)setRootPath:(NSString *)path
{
  ASSIGN(rootPath, path);
}
- (NSString *)fullPath
{
  return [rootPath stringByAppendingPathComponent:currentPath];
}

- (CGFloat)columnWidth
{
  return [[NXDefaults userDefaults] floatForKey:@"IconSlotWidth"];
}
- (void)setColumnWidth:(CGFloat)width
{
  // Implement
}
- (NSUInteger)columnCount
{
  return 3;
}
- (void)setColumnCount:(NSUInteger)num
{
  // 
}
- (NSInteger)numberOfEmptyColumns
{
  return 0;
}
- (void)setNumberOfEmptyColumns:(NSInteger)num
{
  // Do nothing: Viewer protocol method
}

// --- Actions
- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames
{
  NSArray  *dirContents;
  NSString *path;

  if (!dirPath || [dirPath isEqualToString:@""])
    return;
  
  ASSIGN(currentPath, dirPath);
  ASSIGN(selection, filenames);

  if (itemsLoader != nil) {
    [itemsLoader cancel];
    [itemsLoader release];
  }

  path = [rootPath stringByAppendingPathComponent:dirPath];
  NSLog(@"IconViewer(%@): display path: %@", rootPath, dirPath);

  [iconView removeAllIcons];
  dirContents = [_owner directoryContentsAtPath:dirPath forPath:nil];
  itemsLoader = [[ViewerItemsLoader alloc] initWithIconView:iconView
                                                       path:path
                                                   contents:dirContents
                                                  selection:filenames];
  [itemsLoader addObserver:self
                forKeyPath:@"isFinished"
                   options:0
                   context:self];
  [operationQ addOperation:itemsLoader];
}
- (void)reloadPathWithSelection:(NSString *)relativePath
{
  NSRect r = [iconView visibleRect];

  [self displayPath:relativePath selection:selection];
  [iconView scrollRectToVisible:r];
}
- (void)reloadPath:(NSString *)reloadPath
{
  NSRect r;

  if ([reloadPath isEqualToString:currentPath] == NO)
    return;
  
  r = [iconView visibleRect];
  [self displayPath:reloadPath selection:selection];
  [iconView scrollRectToVisible:r];
}

- (void)scrollToRange:(NSRange)range
{
  // Do nothing
}
- (BOOL)becomeFirstResponder
{
  return YES;
}

// --- Events
- (void)currentSelectionRenamedTo:(NSString *)newName
{
  PathIcon *icon = [[iconView selectedIcons] anyObject];
  NSString *path;

  [icon setLabelString:[newName lastPathComponent]];
  path = [rootPath stringByAppendingPathComponent:newName];
  [icon setIconImage:[[NSApp delegate] iconForFile:path]];
}

// -- Notifications
- (void)iconWidthDidChange:(NSNotification *)notification
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     slotSize = [iconView slotSize];

  slotSize.width = [df floatForKey:@"IconSlotWidth"];
  [iconView setSlotSize:slotSize];
}

// -- NSOperation
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  NXIconLabel *iconLabel;
  
  NSLog(@"IconView: Observer `%@` of '%@' was called.", [self className], keyPath);
  for (NXIcon *icon in [iconView icons]) {
    [icon setEditable:YES];
    [icon setDelegate:self];
    [icon setTarget:self];
    [icon setDoubleAction:@selector(open:)];
    [icon setDragAction:@selector(iconDragged:withEvent:)];
    [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
    iconLabel = [icon label];
    [iconLabel setNextKeyView:iconView];
    [iconLabel setIconLabelDelegate:_owner];
  }

  [iconView scrollPoint:NSZeroPoint];
  [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
                             withObject:nil
                          waitUntilDone:YES];
  [[view window] makeFirstResponder:iconView];
}

//=============================================================================
// Local
//=============================================================================
// TODO
- (void)open:sender
{
  NSSet    *selected = [iconView selectedIcons];
  NSString *path, *fullPath;
  NSString *appName, *fileType;

  NSLog(@"[IconViewer] open path:%@ selection:%@", currentPath, selection);

  if ([selected count] == 0) {
    [_owner displayPath:currentPath selection:nil sender:self];
  }
  else if ([selected count] == 1) {
    path = [currentPath stringByAppendingPathComponent:[selection objectAtIndex:0]];
    fullPath = [rootPath stringByAppendingPathComponent:path];
    [(NSWorkspace *)[NSApp delegate] getInfoForFile:fullPath
                                        application:&appName
                                               type:&fileType];

    if ([fileType isEqualToString:NSDirectoryFileType] ||
        [fileType isEqualToString:NSFilesystemFileType]) {
      [self displayPath:path selection:nil];
      [_owner displayPath:path selection:nil sender:self];
    }
    else {
      [_owner open:sender];
    }
  }
}

//=============================================================================
// NXIconView delegate
//=============================================================================
- (void)     iconView:(NXIconView*)anIconView
 didChangeSelectionTo:(NSSet *)selectedIcons
{
  NSMutableArray *selected = [NSMutableArray array];
  BOOL           showsExpanded = ([selectedIcons count] == 1) ? YES : NO;

  if (anIconView != iconView)
    return;

  NSLog(@"IconViewer(%@): selection did change.", rootPath);

  for (NXIcon *icon in selectedIcons) {
    [icon setShowsExpandedLabelWhenSelected:showsExpanded];
    [selected addObject:[icon labelString]];
  }

  ASSIGN(selection, [[selected copy] autorelease]);

  [_owner displayPath:currentPath selection:selection sender:self];
}

- (void)keyDown:(NSEvent *)ev
{
  NSString   *characters = [ev characters];
  NSUInteger charsLength = [characters length];
  unichar    ch = 0;
  NSUInteger modifierFlags = [ev modifierFlags];

  if (charsLength > 0) {
    ch = [characters characterAtIndex:0];
  }
  
  NSLog(@"[IconViewer] keyDown: %c", ch);

  if ((ch == NSUpArrowFunctionKey) && (modifierFlags & NSCommandKeyMask)) {
    [self displayPath:[currentPath stringByDeletingLastPathComponent]
            selection:@[[currentPath lastPathComponent]]];
    return;
  }
  else if ((ch == NSDownArrowFunctionKey) && modifierFlags & NSCommandKeyMask) {
    [self open:nil];
    return;
  }

  /*
  if (allowsAlphanumericSelection && (ch < 0xF700) && (charsLength > 0))
    {
      NSMatrix *matrix;
      NSString *sv;
      NSInteger i, n, s;
      NSInteger match;
      NSInteger selectedColumn;
      SEL lcarcSel = @selector(loadedCellAtRow:column:);
      IMP lcarc = [self methodForSelector:lcarcSel];

      // NSLog(@"selectedColumn: %i", selectedColumn);
      
      matrix = [self matrixInColumn:selectedColumn];
      n = [matrix numberOfRows];
      s = [matrix selectedRow];
          
      if (clickTimer && [clickTimer isValid]) {
        [clickTimer invalidate];
      }
      clickTimer =
        [NSTimer
              scheduledTimerWithTimeInterval:0.8
                                      target:self
                                    selector:@selector(_performClick:)
                                    userInfo:matrix
                                     repeats:NO];
      if (!_charBuffer)
        {
          _charBuffer = [characters substringToIndex:1];
          RETAIN(_charBuffer);
        }
      else
        {
          if (([ev timestamp] - _lastKeyPressed < 2.0)
              && (_alphaNumericalLastColumn == selectedColumn)
              && s >= 0)
            {
              NSString *transition;
              transition = [_charBuffer 
                                 stringByAppendingString:
                               [characters substringToIndex:1]];
              RELEASE(_charBuffer);
              _charBuffer = transition;
              RETAIN(_charBuffer);
            }
          else
            {
              RELEASE(_charBuffer);
              _charBuffer = [characters substringToIndex:1];
              RETAIN(_charBuffer);
            }
        }

      // NSLog(@"_charBuffer: %@ _lastKeyPressed:%f(%f) selected:%i",
      //       _charBuffer, _lastKeyPressed, [ev timestamp], s);

      _alphaNumericalLastColumn = selectedColumn;
      _lastKeyPressed = [ev timestamp];

      //[[self loadedCellAtRow:column:] stringValue]
      sv = [((*lcarc)(self, lcarcSel, s, selectedColumn)) stringValue];

      // selected cell aleady contains typed string - _charBuffer
      if (([sv length] > 0) && ([sv hasPrefix:_charBuffer]))
        {
          return;
        }

      // search row from selected to the bottom
      match = -1;
      for (i = s + 1; i < n; i++)
        {
          sv = [((*lcarc)(self, lcarcSel, i, selectedColumn)) stringValue];
          if (([sv length] > 0) && ([sv hasPrefix: _charBuffer]))
            {
              match = i;
              break;
            }
        }
      // previous search found nothing, start from top
      if (i == n)
        {
          for (i = 0; i < s; i++)
            {
              sv = [((*lcarc)(self, lcarcSel, i, selectedColumn))
                     stringValue];
              if (([sv length] > 0)
                  && ([sv hasPrefix: _charBuffer]))
                {
                  match = i;
                  break;
                }
            }
        }
      if (match != -1)
        {
          [matrix deselectAllCells];
          [matrix selectCellAtRow:match column:0];
          [matrix scrollCellToVisibleAtRow:match column:0];
          // click performed with timer
          // [matrix performClick:self];
          return;
        }
        
      _lastKeyPressed = 0.;
      return;
    }
  */
}

//=============================================================================
// Drag and Drop
//=============================================================================
// IconView actions
- (void)iconDragged:(PathIcon *)theIcon
          withEvent:(NSEvent *)theEvent
{
  NSRect       iconFrame = [theIcon frame];
  NSPoint      iconLocation = iconFrame.origin;
  NSPasteboard *pasteBoard = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSDictionary *iconInfo;
  
  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  draggedSource = self;
  draggedIcon = theIcon;
  draggingSourceMask = NSDragOperationMove;

  [draggedIcon setSelected:NO];
  [draggedIcon setDimmed:YES];
  
  // Pasteboard info for 'draggedIcon'
  [pasteBoard declareTypes:@[NSFilenamesPboardType] owner:nil];
  [pasteBoard setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];

  [iconView dragImage:[draggedIcon iconImage]
                   at:iconLocation
               offset:NSZeroSize
                event:theEvent
           pasteboard:pasteBoard
               source:draggedSource
            slideBack:YES];
}

// NSDraggingSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSLog(@"[IconView] draggingSourceOperationMaskForLocal:");
  return NSDragOperationMove;
}
- (BOOL)ignoreModifierKeysWhileDragging
{
  return YES;
}
- (void)draggedImage:(NSImage*)image
             endedAt:(NSPoint)screenPoint
           deposited:(BOOL)didDeposit
{
  NSLog(@"draggedImage:endedAt:operation:");
  if (didDeposit == NO) {
    [draggedIcon setSelected:YES];
    [draggedIcon setDimmed:NO];
  }
}

// NXIcon delegate methods (NSDraggingDestination)
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingEntered:icon:");
  return draggingSourceMask;
}
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
                              icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingUpdated:icon:");
  return draggingSourceMask;
}
- (void)draggingExited:(id <NSDraggingInfo>)sender
                  icon:(NXIcon *)icon
{
  // NSLog(@"[Recycler] draggingOperationExited:icon:");
}

@end
