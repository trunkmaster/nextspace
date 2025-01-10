/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2005 Saso Kiselkov
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

#import <math.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDragView.h>
#import <SystemKit/OSEDefaults.h>
#import <SystemKit/OSEFileManager.h>

#import <Preferences/Shelf/ShelfPrefs.h>
#import <Viewers/FileViewer.h>
#import <Controller.h>

#import "Recycler.h"
#import "PathIcon.h"
#import "ShelfView.h"

@implementation ShelfView

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer
{
  [super initWithFrame:r];

  _owner = fileViewer;

  autoAdjustsToFitIcons = NO;
  allowsMultipleSelection = NO;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;

  [self setTarget:self];
  [self setDelegate:self];
  [self setAction:@selector(iconClicked:)];
  [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(iconDragged:event:)];
  [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(iconSlotWidthChanged:)
                                               name:ShelfIconSlotWidthDidChangeNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:_owner
                                           selector:@selector(shelfResizableStateChanged:)
                                               name:ShelfResizableStateDidChangeNotification
                                             object:nil];

  return self;
}

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
                  format:@"ShelfView: in `-storableRepresentation':"
                         @" Unable to deteremine the slot for an icon that"
                         @" _must_ be present"];
    }

    [dict setObject:[icon paths]
             forKey:@[ [NSNumber numberWithInt:slot.x], [NSNumber numberWithInt:slot.y] ]];
  }

  return [dict autorelease];
}

- (void)addIcon:(NXTIcon *)anIcon
{
  [super addIcon:anIcon];
  [anIcon setEditable:NO];
}

- (void)putIcon:(NXTIcon *)anIcon intoSlot:(NXTIconSlot)aSlot
{
  [super putIcon:anIcon intoSlot:aSlot];
  [anIcon setEditable:NO];
}

//=============================================================================
// Shelf (moved from FileViewer)
//=============================================================================

- (void)checkIfContentsExist
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path;

  NSDebugLLog(@"FileViewer", @">>>>>>>>> checkShelfContentsExist");

  for (PathIcon *icon in [self icons]) {
    path = [[icon paths] objectAtIndex:0];
    if (![fm fileExistsAtPath:path]) {
      NSDebugLLog(@"Shelf", @"Shelf element %@ doesn't exist.", path);
      [self removeIcon:icon];
    }
  }
}

- (void)shelfAddMountedRemovableMedia
{
  id<MediaManager> mediaManager = [[NSApp delegate] mediaManager];
  NSArray *mountPoints = [mediaManager mountedRemovableMedia];
  NSDictionary *info;
  NSNotification *notif;

  for (NSString *mountPath in mountPoints) {
    info = [NSDictionary dictionaryWithObject:mountPath forKey:@"MountPoint"];
    notif = [NSNotification notificationWithName:OSEMediaVolumeDidMountNotification object:mediaManager userInfo:info];
    [_owner volumeDidMount:notif];
  }
}

- (void)iconClicked:(id)sender
{
  NSString *path = [[sender paths] lastObject];

  [_owner slideToPathFromShelfIcon:sender];

  // Convert 'path' variable contents as relative path
  if ([_owner isRootViewer] == NO) {
    if ([path isEqualToString:[_owner rootPath]]) {
      path = @"/";
    } else {
      path = [path substringFromIndex:[[_owner rootPath] length]];
    }
  }

  [_owner displayPath:path selection:nil sender:self];
  [self selectIcons:nil];
}

- (void)iconDoubleClicked:(id)sender
{
  [sender setDimmed:YES];
  [_owner open:sender];
  [sender setDimmed:NO];
  [self selectIcons:nil];
}

- (NSArray *)pathsForDrag:(id<NSDraggingInfo>)draggingInfo
{
  NSArray *paths;

  paths = [[draggingInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];

  if (![paths isKindOfClass:[NSArray class]] || [paths count] != 1) {
    return nil;
  }

  return paths;
}

- (PathIcon *)createIconForPaths:(NSArray *)paths
{
  PathIcon *icon;
  NSString *path;
  NSString *rootPath = [_owner rootPath];

  if ((path = [paths objectAtIndex:0]) == nil) {
    return nil;
  }

  // make sure its a subpath of our current root path
  if ([path rangeOfString:rootPath].location != 0) {
    return nil;
  }

  icon = [[PathIcon new] autorelease];
  if ([paths count] == 1) {
    [icon setIconImage:[[NSApp delegate] iconForFile:path]];
  }
  [icon setPaths:paths];
  [icon setDoubleClickPassesClick:NO];
  [icon setEditable:NO];
  [[icon label] setNextKeyView:[[_owner viewer] view]];

  return icon;
}

// --- Notifications

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

  NSDebugLLog(@"Shelf", @"Shelf: iconDragged: %@", [sender className]);

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
  // FIXME: setting the propery list below renders icon undraggable (no dragged icon)
  // [pb declareTypes:@[NSFilenamesPboardType,NSGeneralPboardType] owner:nil];
  // if ((iconInfo = [draggedIcon info]) != nil) {
  //   [pb setPropertyList:iconInfo forType:NSGeneralPboardType];
  // }

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
  NSDebugLLog(@"Shelf", @"[ShelfView] draggingSourceOperationMaskForLocal: %@", isLocal ? @"YES" : @"NO");
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
  NSDebugLLog(@"Shelf", @"[ShelfView] draggedImage:endedAt:operation:%lu mask:%lu", operation, draggedMask);

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

- (BOOL)_isAcceptDragFromSource:(id)dSource withPaths:(NSArray *)dPaths
{
  if (![dPaths isKindOfClass:[NSArray class]] || [dPaths count] == 0) {
    return NO;
  } else if ([dSource isKindOfClass:[Recycler class]]) {
    return NO;
  } else {
    NSString *p1 = [_owner rootPath];
    NSString *p2 = [dPaths lastObject];
    if ([NXTIntersectionPath(p1, p2) isEqualToString:p1] == NO) {
      return NO;
    }
  }

  return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)dragInfo
{
  NSPasteboard *pasteBoard = [dragInfo draggingPasteboard];
  NXTIconSlot iconSlot;

  draggedPaths = [pasteBoard propertyListForType:NSFilenamesPboardType];
  draggedSource = [dragInfo draggingSource];

  NSDebugLLog(@"Shelf", @"[ShelfView] -draggingEntered (source:%@)", [draggedSource className]);
  NSDebugLLog(@"Shelf", @"[ShelfView] -draggingEntered with paths: %@)", draggedPaths);

  if ([self _isAcceptDragFromSource:draggedSource withPaths:draggedPaths] == NO) {
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

  NSDebugLLog(@"Shelf", @"[ShelfView] -draggingUpdated (source:%@)",
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
    if ([self _isAcceptDragFromSource:draggedSource withPaths:draggedPaths] == NO) {
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

  NSDebugLLog(@"Shelf", @"[Shelf] draggingUpdated draggedMask=%lu slot: {%i,%i}", draggedMask,
        lastSlotDragEntered.x, lastSlotDragEntered.y);

  return draggedMask;
}

- (void)draggingExited:(id<NSDraggingInfo>)dragInfo
{
  NSDebugLLog(@"Shelf", @"[ShelfView] -dragginExited (source:%@)", [[dragInfo draggingSource] className]);

  // if (lastSlotDragExited.x == 0 && lastSlotDragExited.y == 0) {
  //   return;
  // }

  if (draggedIcon && [draggedIcon superview]) {
    [self removeIcon:draggedIcon];
  }
  lastSlotDragExited.x = lastSlotDragEntered.x;
  lastSlotDragExited.y = lastSlotDragEntered.y;
  // lastSlotDragEntered.x = -1;
  // lastSlotDragEntered.y = -1;
}

// - After the Image is Released

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[Shelf] prepare for drag operation = %lu", draggedMask);
  if (draggedMask == NSDragOperationMove) {
    if ([sender draggingSource] == self) {
      NSDebugLLog(@"Shelf", @"[Shelf] prepare to Move icon inside Shelf");
    } else {
      NSPasteboard *pasteBoard = [sender draggingPasteboard];
      NSArray *paths = [pasteBoard propertyListForType:NSFilenamesPboardType];
      NSDebugLLog(@"Shelf", @"[Shelf] prepare to Move %@ from %@", paths, [[sender draggingSource] className]);
    }
  }
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[ShelfView] performDragOperation");
  [draggedIcon registerForDraggedTypes:@[ NSFilenamesPboardType ]];
  [draggedIcon setDelegate:self];

  return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Shelf", @"[ShelfView] concludeDragOperation");

  if (draggedIcon && [draggedIcon superview]) {
    [draggedIcon setDimmed:NO];
    // [draggedIcon release];
    // draggedIcon = nil;
  }

  // lastSlotDragEntered.x = -1;
  // lastSlotDragEntered.y = -1;
}

// --- NSView overridings

- (void)mouseDown:(NSEvent *)ev
{
  // Do nothing. It prevents bogus icons deselection.
}

- (BOOL)acceptsFirstResponder
{
  // Do nothing. It prevents first responder stealing.
  return NO;
}

@end
