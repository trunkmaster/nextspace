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

static NSMutableArray *fileList = nil;

- (id)initWithIconView:(NXIconView *)view
                  path:(NSString *)dirPath
              contents:(NSArray *)dirContents
             selection:(NSArray *)filenames
{
  if (self != nil) {
    iconView = view;
    directoryPath = [dirPath copy];
    directoryContents = [dirContents mutableCopy];
    selectedFiles = filenames;
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
  NSString   *path;
  PathIcon   *anIcon;
  NSUInteger slotsWide, x;

  NSLog(@"IconView: Begin path loading... %@ [%@]", directoryPath, selectedFiles);

  x = 0;
  slotsWide = [iconView slotsWide];
  [self _optimizeItems:directoryContents fileView:iconView];
  
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
  [directoryContents release];
  [directoryPath release];
}

- (BOOL)isReady
{
  return YES;
}

@end

@implementation IconViewer

- (void)dealloc
{
  NSLog(@"[IconViewer] -dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];

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
  iconView = [[[NXIconView alloc] initSlotsWide:3] autorelease];
  [iconView setDelegate:self];
  [iconView setTarget:self];
  [iconView setDragAction: @selector(iconDragged:withEvent:)];
  [iconView setDoubleAction: @selector(open:)];
  [iconView setSendsDoubleActionOnReturn:YES];
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

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(selectionDidChange:)
           name:NXIconViewDidChangeSelectionNotification
         object:iconView];
  
  currentPath = nil;
  selection = nil;
  rootPath = @"/";
  
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
  _owner = owner;
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

  path = [[_owner rootPath] stringByAppendingPathComponent:dirPath];
  NSLog(@"IconViewer: display path: %@", dirPath);
  
  dirContents = [_owner directoryContentsAtPath:dirPath forPath:nil];
  itemsLoader = [[ViewerItemsLoader alloc] initWithIconView:iconView
                                                       path:path
                                                   contents:dirContents
                                                  selection:filenames];
  [itemsLoader addObserver:self
                forKeyPath:@"isFinished"
                   options:0
                   context:NULL];
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
  NSRect r = [iconView visibleRect];
  
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
  PathIcon *icon;
  NSString *path;
  
  icon = [[iconView selectedIcons] anyObject];
  [icon setLabelString:newName];
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
  NSLog(@"IconView: Observer of '%@' was called.", keyPath);
  for (NXIcon *icon in [iconView icons]) {
    [icon setEditable:NO];
    [icon setDelegate:self];
    [icon setTarget:self];
    [icon setAction:@selector(doClick:)];
    [icon setDragAction:@selector(iconDragged:withEvent:)];
    [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
  }

  if ([selection count] > 0) {
    NSMutableSet *selected = [NSMutableSet new];
    NXIcon       *icon;
    for (NSString *label in selection) {
      icon = [iconView iconWithLabelString:label];
      if (icon) {
        [selected addObject:icon];
      }
    }
    [iconView performSelectorOnMainThread:@selector(selectIcons:)
                               withObject:selected
                            waitUntilDone:YES];
    [selected release];
  }
  else {
    [iconView performSelectorOnMainThread:@selector(selectIcons:)
                               withObject:nil
                            waitUntilDone:YES];
    [iconView scrollPoint:NSZeroPoint];
  }

  [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
                             withObject:nil
                          waitUntilDone:YES];
  [[view window] makeFirstResponder:iconView];
}

//=============================================================================
// Local
//=============================================================================
// - (void)     iconView:(NXIconView*)anIconView
//  didChangeSelectionTo:(NSSet *)selectedIcons
- (void)selectionDidChange:(NSNotification *)notif
{
  NSSet          *icons = [[notif userInfo] objectForKey:@"Selection"];
  NSMutableArray *selected = [NSMutableArray array];
  BOOL           showsExpanded = ([icons count] == 1) ? YES : NO;

  if ([notif object] != iconView)
    return;

  NSLog(@"IconViewer: selection did change.");

  for (NXIcon *icon in icons) {
    [icon setShowsExpandedLabelWhenSelected:showsExpanded];
    [selected addObject:[icon labelString]];
  }

  ASSIGN(selection, [[selected copy] autorelease]);

  [_owner displayPath:currentPath selection:selection sender:self];
}

// TODO
- (void)open:sender
{
  NSSet    *selected = [iconView selectedIcons];
  NSString *path;
  NSString *appName, *fileType;

  if ([selected count] == 0) {
    [_owner displayPath:currentPath selection:nil sender:self];
  }
  else if ([selected count] == 1) {
    path = [currentPath stringByAppendingPathComponent:[selection objectAtIndex:0]];
    // [(NSWorkspace *)[NSApp delegate] getInfoForFile:path
    //                                     application:&appName
    //                                            type:&fileType];

    // if ([fileType isEqualToString:NSDirectoryFileType] ||
    //     [fileType isEqualToString:NSFilesystemFileType]) {
      [_owner displayPath:currentPath
                selection:@[[[selected anyObject] labelString]]
                   sender:self];
    // }
  }

  // ASSIGN(currentPath, path);
  // ASSIGN(selection, nil);
  // [_owner open:view];
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
