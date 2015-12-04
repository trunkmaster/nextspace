/*
   The icons viewer.

   Copyright (C) 2005 Saso Kiselkov

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

#include <AppKit/AppKit.h>
#include "IconsViewer.h"

#import <XSAppKit/XSAppKit.h>
#import <XSFoundation/XSPreferences.h>

@implementation IconsViewer

+ (NSString *) viewerType
{
        return _(@"Icons");
}

+ (NSString *) viewerShortcut
{
        return _(@"I");
}

- (void) dealloc
{
        [[NSNotificationCenter defaultCenter] removeObserver: self];

        TEST_RELEASE(currentPath);
        TEST_RELEASE(selection);
        TEST_RELEASE(iface);

        TEST_RELEASE(view);

        [super dealloc];
}

- init
{
        NSUserDefaults * df = [NSUserDefaults standardUserDefaults];

        [super init];

        iconView = [[[XSIconView alloc] initSlotsWide: 3] autorelease];
        [self iconSlotWidthChanged: nil];

        [iconView setTarget: self];
        [iconView setDoubleAction: @selector(open:)];
        [iconView setDragAction: @selector(iconDragged:event:)];
        [iconView setSendsDoubleActionOnReturn: YES];

        [iconView setDelegate: self];
        [iconView registerForDraggedTypes: [NSArray arrayWithObject:
          NSFilenamesPboardType]];

        view = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 300, 300)];
        [view setDocumentView: iconView];
        [iconView setFrame: NSMakeRect(0, 0,
                                       [[view contentView] frame].size.width,
                                       0)];
        [iconView setAutoresizingMask: NSViewWidthSizable];
        [view setBorderType: NSBezelBorder];
        [view setHasVerticalScroller: YES];

        [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector(iconSlotWidthChanged:)
                 name: @"IconSlotWidthDidChangeNotification"
               object: nil];

        return self;
}

- (void) setOwner: (id <FileViewer>) _owner
{
        owner = _owner;
}

- (void) setFileSystemInterface: (id <FileSystemInterface,NSObject>) fsInterface
{
  if (iface)
    [(NSObject *)iface release];

  iface = [fsInterface retain];
}

- (void) reloadPathWithSelection:(NSString *)newSelection
{
  NSRect r = [iconView visibleRect];

  [self displayPath: currentPath selection: selection];
  [iconView scrollRectToVisible: r];
}

- (void) reloadPath:(NSString *)path
      withSelection:(NSString *)newSelection
{
  NSRect r = [iconView visibleRect];

  [self displayPath: currentPath selection: selection];
  [iconView scrollRectToVisible: r];
}

- (void) displayPath: (NSString *) dirPath
           selection: (NSArray *) filenames
{
  NSEnumerator * e;
  NSString * filename;
  NSMutableArray * icons;
  NSMutableSet * selected = [[NSMutableSet new] autorelease];
  NSFileManager *fm = [NSFileManager defaultManager];

  ASSIGN(currentPath, dirPath);
  ASSIGN(selection, filenames);

  icons = [NSMutableArray array];

  e = [[iface directoryContentsAtPath: dirPath]  objectEnumerator];
  while ((filename = [e nextObject]) != nil)
    {
      NSString * path = [dirPath stringByAppendingPathComponent:filename];
      XSIcon * anIcon;

      anIcon = [[XSIcon new] autorelease];
      [anIcon setLabelString:filename];
      [anIcon setIconImage:[iface iconForFile:path]];
      [anIcon setDelegate:self];
      [anIcon registerForDraggedTypes:[NSArray arrayWithObject:
	NSFilenamesPboardType]];
      [[anIcon label] setIconLabelDelegate:self];

      [icons addObject:anIcon];
      if (![fm isReadableFileAtPath: path])
	{
	  [anIcon setDimmed: YES];
  	}
      if ([selection containsObject:filename])
	{
  	  [selected addObject: anIcon];
	}
    }

  [iconView fillWithIcons:icons];
  if ([selected count] != 0)
    [iconView selectIcons: selected];
  else
    [iconView scrollPoint: NSZeroPoint];
}

- (NSView *) view
{
        return view;
}

- (NSView *)keyView
{
    return view;
}

- (void) setVerticalSize: (float) aSize
{
}

- (void) setNumberOfVerticals: (unsigned) num
{
}

- (void) scrollToRange: (NSRange) range
{
}

// Actually it's read by XSIconView object
- (CGFloat)columnWidth
{
  return [[XSDefaults userDefaults] floatForKey:@"IconSlotWidth"];
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
}

- (NSInteger)numberOfEmptyColumns
{
  return 0;
}

- (void)setNumberOfEmptyColumns:(NSInteger)num
{
  // Do nothing: Viewer protocol method
}

- (void)reloadPath:(NSString *)reloadPath
{
  // TODO: add implementation
}

- (void)    iconView: (XSIconView*) anIconView
didChangeSelectionTo: (NSSet *) selectedIcons
{
  NSMutableArray * sel = [NSMutableArray array];
  NSEnumerator * e = [selectedIcons objectEnumerator];
  XSIcon * icon;
  BOOL showsExpanded = ([selectedIcons count] == 1);

  while ((icon = [e nextObject]) != nil) {
      [icon setShowsExpandedLabelWhenSelected: showsExpanded];
      [sel addObject: [icon labelString]];
  }

  ASSIGN(selection, [[sel copy] autorelease]);

//  [owner displayPath: currentPath selection: selection sender:self];
}

- (void) open: sender
{
  NSSet * sel = [iconView selectedIcons];

  if ([sel count] == 1) {
      NSString * path = [currentPath stringByAppendingPathComponent:
					   [selection objectAtIndex: 0]];
      NSString * fileType = [iface fileTypeAtPath: path];

      if ([fileType isEqualToString: NSDirectoryFileType] ||
	  [fileType isEqualToString: NSFilesystemFileType]) {
	  ASSIGN(currentPath, path);
	  ASSIGN(selection, nil);
	  [owner displayPath: currentPath selection: selection sender:self];
	  [self displayPath: currentPath selection: selection];

	  return;
      }
  }

  [owner open: view];
}

- (void) iconDragged: sender event: (NSEvent *) ev
{
        NSString * path = [currentPath stringByAppendingPathComponent:
          [sender labelString]];
        NSString * fullPath = [[iface rootPath]
          stringByAppendingPathComponent: path];
        NSArray * filenames = [NSArray arrayWithObject: fullPath];
        NSPasteboard * pb = [NSPasteboard pasteboardWithName: NSDragPboard];

        draggingSourceMask = [iface draggingSourceOperationMaskForPaths: filenames];

        [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType]
                   owner: nil];
        [pb setPropertyList: filenames
                    forType: NSFilenamesPboardType];

        [iconView dragImage: [sender iconImage]
                         at: [ev locationInWindow]
                     offset: NSZeroSize
                      event: ev
                 pasteboard: pb
                     source: sender
                  slideBack: YES];
}

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) isLocal
                                                icon: (XSIcon *) sender
{
        return draggingSourceMask;
}

- (unsigned int) draggingEntered: (id <NSDraggingInfo>) sender
                            icon: (XSIcon *) icon
{
        NSString * destPath;
        NSArray * paths;
        unsigned int draggingDestMask;

        paths = [[sender draggingPasteboard]
          propertyListForType: NSFilenamesPboardType];
        destPath = [[[iface rootPath] stringByAppendingPathComponent:
          currentPath] stringByAppendingPathComponent: [icon labelString]];

        if (![paths isKindOfClass: [NSArray class]] ||
            [paths count] == 0) {
                draggingDestMask = NSDragOperationNone;
        } else {
                draggingDestMask = [iface
                  draggingDestinationMaskForPaths: paths
                                         intoPath: destPath];
        }
        if (draggingDestMask != NSDragOperationNone)
                [icon setIconImage: [iface openDirIconForDirectory:
                  [currentPath stringByAppendingPathComponent: [icon
                  labelString]]]];

        return draggingDestMask;
}

- (void) draggingExited: (id <NSDraggingInfo>) sender
                   icon: (XSIcon *) icon
{
        [icon setIconImage: [iface iconForFile: [currentPath
          stringByAppendingPathComponent: [icon labelString]]]];
}

- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>) sender
                            icon: (XSIcon *) icon
{
        [self draggingExited: sender icon: icon];
        return YES;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>) sender
                         icon: (XSIcon *) anIcon
{
        NSMutableArray * filenames = [NSMutableArray array];
        NSArray * filePaths = [[sender draggingPasteboard]
          propertyListForType: NSFilenamesPboardType];
        NSEnumerator * e = [filePaths objectEnumerator];
        NSString * sourceDir, * path;
        unsigned int mask;
        unsigned int opType = NSDragOperationNone;

        sourceDir = [[filePaths objectAtIndex: 0]
          stringByDeletingLastPathComponent];

        while ((path = [e nextObject]) != nil)
                [filenames addObject: [path lastPathComponent]];

        mask = [sender draggingSourceOperationMask];

        if (mask & NSDragOperationMove)
                opType = NSDragOperationMove;
        else if (mask & NSDragOperationCopy)
                opType = NSDragOperationCopy;
        else if (mask & NSDragOperationLink)
                opType = NSDragOperationLink;
        else
                return NO;

        [iface startFileOperationFrom: sourceDir
                                   to: [[iface rootPath]
          stringByAppendingPathComponent: [currentPath
          stringByAppendingPathComponent: [anIcon labelString]]]
                            withFiles: filenames
                        operationType: opType];

        return YES;
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
                       iconView: (XSIconView *) iv
{
        NSString * destPath;
        NSArray * paths;
        unsigned int draggingDestMask;

        paths = [[sender draggingPasteboard]
          propertyListForType: NSFilenamesPboardType];
        destPath = [[iface rootPath] stringByAppendingPathComponent:
          currentPath];

        if (![paths isKindOfClass: [NSArray class]] ||
            [paths count] == 0) {
                draggingDestMask = NSDragOperationNone;
        } else {
                draggingDestMask = [iface
                  draggingDestinationMaskForPaths: paths
                                         intoPath: destPath];
        }

        return draggingDestMask;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
                       iconView: (XSIconView *) iconView
{
        return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
                    iconView: (XSIconView *) iconView
{
        NSMutableArray * filenames = [NSMutableArray array];
        NSArray * filePaths = [[sender draggingPasteboard]
          propertyListForType: NSFilenamesPboardType];
        NSEnumerator * e = [filePaths objectEnumerator];
        NSString * sourceDir, * path;
        unsigned int mask;
        unsigned int opType = NSDragOperationNone;

        sourceDir = [[filePaths objectAtIndex: 0]
          stringByDeletingLastPathComponent];

        while ((path = [e nextObject]) != nil)
                [filenames addObject: [path lastPathComponent]];

        mask = [sender draggingSourceOperationMask];

        if (mask & NSDragOperationMove)
                opType = NSDragOperationMove;
        else if (mask & NSDragOperationCopy)
                opType = NSDragOperationCopy;
        else if (mask & NSDragOperationLink)
                opType = NSDragOperationLink;
        else
                return NO;

        [iface startFileOperationFrom: sourceDir
                                   to: [[iface rootPath]
          stringByAppendingPathComponent: currentPath]
                            withFiles: filenames
                        operationType: opType];

        return YES;
}

- (void) iconSlotWidthChanged: (NSNotification *) notif
{
  NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
  NSSize slotSize = [iconView slotSize];

  if ([df objectForKey: @"IconSlotWidth"])
    slotSize.width = [df floatForKey: @"IconSlotWidth"];
  else
    slotSize.width = 150;
  [iconView setSlotSize: slotSize];
}

- (void)   iconLabel: (XSIconLabel *) iconLabel
 didChangeStringFrom: (NSString *) oldName
                  to: (NSString *) newName
{
        if (![owner viewerRenamedCurrentFileTo: newName]) {
                [[iconLabel icon] setLabelString: oldName];
        } else {
                ASSIGN(selection, [NSArray arrayWithObject: newName]);

                [[iconLabel icon] setIconImage: [iface
                  iconForFile: [currentPath
                  stringByAppendingPathComponent: newName]]];
        }
}
- (void)currentSelectionRenamedTo:(NSString *)newName
{
}

@end
