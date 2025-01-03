/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018-2021 Sergii Stoian
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

#import <math.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDragView.h>

#import <SystemKit/OSEDefaults.h>
#import <SystemKit/OSEFileManager.h>

#import <Preferences/Shelf/ShelfPrefs.h>
#import <Controller.h>
#import <Viewers/PathIcon.h>
#import <Viewers/PathView.h>

#import "Recycler.h"
#import "WMShelf.h"

@implementation WMShelf

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

// --- NXTIconView overridings

- initWithFrame:(NSRect)rect
{
  [super initWithFrame:rect];

  autoAdjustsToFitIcons = NO;
  allowsMultipleSelection = NO;
  allowsEmptySelection = YES;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;

  [self setDelegate:self];
  // [self setTarget:self];
  // [self setAction:@selector(iconClicked:)];
  // [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(iconDragged:event:)];
  [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(iconSlotWidthChanged:)
                                               name:ShelfIconSlotWidthDidChangeNotification
                                             object:nil];

  return self;
}

- (void)putIcon:(NXTIcon *)anIcon intoSlot:(NXTIconSlot)aSlot
{
  [super putIcon:anIcon intoSlot:aSlot];
  [anIcon setEditable:NO];
}

- (PathIcon *)iconInSlot:(NXTIconSlot)slot
{
  return (PathIcon *)[super iconInSlot:slot];
}

// --- NSView overridings

- (BOOL)acceptsFirstResponder
{
  // Do nothing. It prevents first responder stealing.
  return NO;
}

//=============================================================================
// Shelf additions
//=============================================================================

- (void)reconstructFromRepresentation:(NSDictionary *)aDict
{
  for (NSArray *key in [aDict allKeys]) {
    NSArray *paths;
    NXTIconSlot slot;
    PathIcon *icon;

    if (![key isKindOfClass:[NSArray class]] || [key count] != 2) {
      continue;
    }
    if (![[key objectAtIndex:0] respondsToSelector:@selector(intValue)] ||
        ![[key objectAtIndex:1] respondsToSelector:@selector(intValue)]) {
      continue;
    }

    slot = NXTMakeIconSlot([[key objectAtIndex:0] intValue], [[key objectAtIndex:1] intValue]);

    paths = [aDict objectForKey:key];
    if (![paths isKindOfClass:[NSArray class]]) {
      continue;
    }

    icon = [self createIconForPaths:paths];
    if (icon) {
      [icon setDelegate:self];
      [icon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
      [self putIcon:icon intoSlot:slot];
    }
  }
}

- (NSDictionary *)storableRepresentation
{
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  Class nullClass = [NSNull class];

  for (PathIcon *icon in [self icons]) {
    NXTIconSlot slot;

    if ([icon isKindOfClass:nullClass] || [[icon paths] count] > 1) {
      continue;
    }

    slot = [self slotForIcon:icon];

    if (slot.x == -1) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"WMShelf: in `-storableRepresentation':"
                         @" Unable to deteremine the slot for an icon that"
                         @" _must_ be present"];
    }

    [dict setObject:[icon paths]
             forKey:@[ [NSNumber numberWithInt:slot.x], [NSNumber numberWithInt:slot.y] ]];
  }

  return [dict autorelease];
}

- (void)checkIfContentsExist
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path;

  NSDebugLLog(@"Shelf", @"[WMShelf] checkShelfContentsExist");

  for (PathIcon *icon in [self icons]) {
    path = [[icon paths] objectAtIndex:0];
    if (![fm fileExistsAtPath:path]) {
      NSDebugLLog(@"Shelf", @"Shelf element %@ doesn't exist.", path);
      [self removeIcon:icon];
    }
  }
}

- (PathIcon *)createIconForPaths:(NSArray *)paths
{
  PathIcon *icon;
  NSString *path;

  if ((path = [paths objectAtIndex:0]) == nil) {
    return nil;
  }

  icon = [[PathIcon new] autorelease];
  if ([paths count] == 1) {
    [icon setIconImage:[[NSApp delegate] iconForFile:path]];
  }
  [icon setPaths:paths];
  [icon setDoubleClickPassesClick:NO];
  [icon setEditable:NO];
  // [[icon label] setNextKeyView:[[_owner viewer] view]];

  return icon;
}

// --- Notifications
// Generated by WM Preferences
- (void)iconSlotWidthChanged:(NSNotification *)notif
{
  OSEDefaults *df = [OSEDefaults userDefaults];
  NSSize size = [self slotSize];
  CGFloat width = 0.0;

  if ((width = [df floatForKey:ShelfIconSlotWidth]) > 0.0) {
    size.width = width;
  } else {
    size.width = SHELF_LABEL_WIDTH;
  }
  [self setSlotSize:size];
}

//=============================================================================
// NXTIconView delegate
//=============================================================================
- (void)iconDragged:(id)sender event:(NSEvent *)ev
{
  NSDictionary *iconInfo;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect iconFrame = [sender frame];
  NSPoint iconLocation = iconFrame.origin;
  NXTIconSlot iconSlot = [self slotForIcon:sender];

  NSDebugLLog(@"Shelf", @"[WMShelf] iconDragged: %@", [sender className]);

  draggedSource = self;
  draggedIcon = [sender retain];

  [sender setSelected:NO];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if (iconSlot.x == 0 && iconSlot.y == 0) {
    draggedMask = NSDragOperationCopy;
  } else {
    draggedMask = (NSDragOperationMove | NSDragOperationCopy);
    [self removeIcon:sender];
  }

  // Pasteboard info for 'draggedIcon'
  [pb declareTypes:@[ NSFilenamesPboardType ] owner:nil];
  [pb setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];

  isRootIconDragged = (iconSlot.x == 0 && iconSlot.y == 0) ? YES : NO;

  [self dragImage:[draggedIcon iconImage]
               at:iconLocation
           offset:NSZeroSize
            event:ev
       pasteboard:pb
           source:draggedSource
        slideBack:isRootIconDragged];
}

//============================================================================
// Drag and drop
//============================================================================

// --- NSDraggingSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSDebugLLog(@"Shelf", @"[WMShelf] draggingSourceOperationMaskForLocal: %@", isLocal ? @"YES" : @"NO");
  NXTIconSlot iconSlot = [self slotForIcon:[[self selectedIcons] anyObject]];

  if ((iconSlot.x == 0 && iconSlot.y == 0) || isLocal == NO) {
    draggedMask = NSDragOperationCopy;
  } else if (isLocal == YES) {
    draggedMask = NSDragOperationMove;
  } else {
    draggedMask = NSDragOperationDelete;
  }

  return draggedMask;
}

- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)screenPoint
{
  dragPoint = screenPoint;
}

- (void)draggedImage:(NSImage *)image
             endedAt:(NSPoint)screenPoint
           operation:(NSDragOperation)operation
{
  NSDebugLLog(@"Shelf", @"[WMShelf] draggedImage:endedAt:operation:%lu mask:%lu", operation,
              draggedMask);

  if ((draggedMask == NSDragOperationCopy) && ![self iconInSlot:lastSlotDragEntered] &&
      isRootIconDragged == NO) {
    NSDebugLLog(@"Shelf", @"Operation is Copy and no icon in slot [%i,%i]", lastSlotDragEntered.x,
                lastSlotDragEntered.y);
    [self putIcon:draggedIcon intoSlot:lastSlotDragEntered];
    [draggedIcon setDimmed:NO];
    [draggedIcon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
    [draggedIcon setDelegate:self];
  }

  [draggedIcon release];
  draggedIcon = nil;
  draggedSource = nil;

  lastSlotDragEntered.x = -1;
  lastSlotDragEntered.y = -1;
  lastSlotDragExited.x = -1;
  lastSlotDragExited.y = -1;

  draggedMask = NSDragOperationNone;
}

// --- NSDraggingDestination

// - Before the Image is Released

- (BOOL)acceptsDragFromSource:(id)dSource withPaths:(NSArray *)dPaths
{
  if (![dPaths isKindOfClass:[NSArray class]] || [dPaths count] == 0) {
    return NO;
  } else if ([dSource isKindOfClass:[Recycler class]]) {
    return NO;
  }

  return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)dragInfo
{
  NSPasteboard *pasteBoard = [dragInfo draggingPasteboard];
  NXTIconSlot iconSlot;

  draggedPaths = [pasteBoard propertyListForType:NSFilenamesPboardType];
  draggedSource = [dragInfo draggingSource];

  NSDebugLLog(@"Shelf", @"[WMShelf] -draggingEntered (source:%@)", [draggedSource className]);
  NSDebugLLog(@"Shelf", @"[WMShelf] -draggingEntered with paths: %@)", draggedPaths);

  if ([self acceptsDragFromSource:draggedSource withPaths:draggedPaths] == NO) {
    draggedMask = NSDragOperationNone;
  } else {
    ASSIGN(draggedIcon, [self createIconForPaths:draggedPaths]);
    if (draggedIcon == nil) {
      draggedMask = NSDragOperationNone;
    } else {
      draggedMask = [self draggingUpdated:dragInfo];
      [draggedIcon setIconImage:[dragInfo draggedImage]];
      [draggedIcon setDimmed:YES];
    }
  }

  return draggedMask;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)dragInfo
{
  NSPoint mouseLocation;
  NXTIconSlot slotUnderMouse;
  NXTIcon *icon = nil;

  NSDebugLLog(@"Shelf", @"[WMShelf] -draggingUpdated (source:%@)",
              [[dragInfo draggingSource] className]);

  mouseLocation = [self convertPoint:[dragInfo draggingLocation] fromView:nil];
  slotUnderMouse = NXTMakeIconSlot(floorf(mouseLocation.x / slotSize.width),
                                   floorf(mouseLocation.y / slotSize.height));

  // Draging hasn't leave shelf yet and no slot for drop
  if (slotUnderMouse.x >= slotsWide) {
    slotUnderMouse.x = slotsWide - 1;
  }
  if (slotUnderMouse.y >= slotsTall) {
    slotUnderMouse.y = slotsTall - 1;
  }

  icon = [self iconInSlot:slotUnderMouse];
  if (lastSlotDragEntered.x == slotUnderMouse.x && lastSlotDragEntered.y == slotUnderMouse.y &&
      icon != nil) {
    return draggedMask;
  }

  NSDebugLLog(@"Shelf", @"DRAG: slot.x,y: %i,%i last slot.x,y: %i,%i slotsWide: %i icon:%@",
              slotUnderMouse.x, slotUnderMouse.y, lastSlotDragEntered.x, lastSlotDragEntered.y,
              slotsWide, icon);

  lastSlotDragEntered.x = slotUnderMouse.x;
  lastSlotDragEntered.y = slotUnderMouse.y;

  draggedMask = NSDragOperationMove;

  if (icon == nil) {
    if ([self acceptsDragFromSource:draggedSource withPaths:draggedPaths] == NO) {
      draggedMask = NSDragOperationNone;
    } else if ([draggedSource isKindOfClass:[PathView class]]) {
      draggedMask = NSDragOperationCopy;
    } else {
      draggedMask = [dragInfo draggingSourceOperationMask];
    }

    if (draggedIcon && [draggedIcon superview]) {
      [self removeIcon:draggedIcon];
    }

    if (draggedIcon && draggedMask != NSDragOperationNone) {
      [self putIcon:draggedIcon intoSlot:slotUnderMouse];
    }
  }

  NSDebugLLog(@"Shelf", @"[WMShelf] draggingUpdated draggedMask=%lu slot: {%i,%i}", draggedMask,
              lastSlotDragEntered.x, lastSlotDragEntered.y);

  return draggedMask;
}

- (void)draggingExited:(id<NSDraggingInfo>)dragInfo
{
  NSDebugLLog(@"Shelf", @"[WMShelf] -dragginExited (source:%@)",
              [[dragInfo draggingSource] className]);

  if (draggedIcon && [draggedIcon superview]) {
    [self removeIcon:draggedIcon];
  }
  lastSlotDragExited.x = lastSlotDragEntered.x;
  lastSlotDragExited.y = lastSlotDragEntered.y;
}

// - After the Image is Released

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[WMShelf] prepare for drag operation = %lu", draggedMask);
  if (draggedMask == NSDragOperationMove) {
    if ([sender draggingSource] == self) {
      NSDebugLLog(@"Shelf", @"[WMShelf] prepare to Move icon inside Shelf");
    } else {
      NSPasteboard *pasteBoard = [sender draggingPasteboard];
      NSArray *paths = [pasteBoard propertyListForType:NSFilenamesPboardType];
      NSDebugLLog(@"Shelf", @"[WMShelf] prepare to Move %@ from %@", paths,
                  [[sender draggingSource] className]);
    }
  }
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[WMShelf] performDragOperation");
  [draggedIcon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
  if (delegate) {
    [draggedIcon setDelegate:delegate];
  } else {
    [draggedIcon setDelegate:self];
  }

  return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[WMShelf] concludeDragOperation");
  if (draggedIcon && [draggedIcon superview]) {
    [draggedIcon setDimmed:NO];
  }
}

@end
