/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
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

#import <GNUstepGUI/GSDisplayServer.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDisplay.h>
#import <Processes/ProcessManager.h>
#import <Viewers/ShelfView.h>

#import "Recycler.h"
#import "RecyclerIcon.h"

#include <core/util.h>
#include <core/string_utils.h>
#include <xrandr.h>
#include <dock.h>

static Recycler *recycler = nil;

@implementation RecyclerIconView

// Class variables
static NSCell *dragCell = nil;
static NSCell *tileCell = nil;

+ (void)initialize
{
  NSImage *tileImage;
  NSSize iconSize = NSMakeSize(64, 64);

  dragCell = [[NSCell alloc] initImageCell:nil];
  [dragCell setBordered:NO];

  tileImage = [[GSCurrentServer() iconTileImage] copy];
  [tileImage setScalesWhenResized:NO];
  [tileImage setSize:iconSize];
  tileCell = [[NSCell alloc] initImageCell:tileImage];
  RELEASE(tileImage);
  [tileCell setBordered:NO];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];
  return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)setImage:(NSImage *)anImage
{
  [dragCell setImage:anImage];
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize = NSMakeSize(64, 64);

  NSDebugLLog(@"Recycler", @"Recycler View: drawRect!");

  [tileCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height) inView:self];
  [dragCell drawWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height) inView:self];
}

// --- Drag and Drop

static int imageNumber;
static NSDate *date = nil;
static NSTimeInterval tInterval = 0;

- (void)animate
{
  NSString *imageName;

  if (([NSDate timeIntervalSinceReferenceDate] - tInterval) < 0.1) {
    return;
  }

  tInterval = [NSDate timeIntervalSinceReferenceDate];

  if (++imageNumber > 4)
    imageNumber = 1;

  imageName = [NSString stringWithFormat:@"recycler-%i", imageNumber];

  [self setImage:[NSImage imageNamed:imageName]];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Recycler", @"Recycler: dragging entered!");

  NSArray *sourcePaths;
  BOOL draggedFromRecycler = NO;

  sourcePaths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];

  for (NSString *path in sourcePaths) {
    if ([path rangeOfString:recycler.path].location != NSNotFound) {
      NSDebugLLog(@"Recycler", @"%@ is in %@", path, recycler.path);
      draggedFromRecycler = YES;
      break;
    }
  }

  if (draggedFromRecycler != NO) {
    draggingMask = NSDragOperationNone;
  } else {
    draggingMask = (NSDragOperationMove | NSDragOperationDelete);
    tInterval = [NSDate timeIntervalSinceReferenceDate];
  }

  return draggingMask;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Recycler", @"Recycler: dragging exited!");
  [recycler updateIconImage];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
  if (draggingMask != NSDragOperationNone) {
    [self animate];
  }

  return draggingMask;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Recycler", @"Recycler: prepare fo dragging");
  return ([sender draggingSourceOperationMask] == NSDragOperationNone) ? NO : YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  BOOL result = NO;
  NSPasteboard *dragPb = [sender draggingPasteboard];
  NSArray *types = [dragPb types];
  NSString *dbPath;
  NSMutableDictionary *db;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray *items;
  NSString *sourceDir;

  dbPath = [recycler.path stringByAppendingPathComponent:@".recycler.db"];
  if ([fm fileExistsAtPath:dbPath]) {
    db = [[NSMutableDictionary alloc] initWithContentsOfFile:dbPath];
  } else {
    db = [NSMutableDictionary new];
  }

  NSDebugLLog(@"Recycler", @"Recycler: perform dragging");

  [recycler setIconImage:[NSImage imageNamed:@"recycler"]];

  if ([types containsObject:NSFilenamesPboardType] == YES) {
    NSString *name, *path;

    items = [[dragPb propertyListForType:NSFilenamesPboardType] mutableCopy];
    sourceDir = [[items objectAtIndex:0] stringByDeletingLastPathComponent];

    for (NSUInteger i = 0; i < [items count]; i++) {
      path = [items objectAtIndex:i];
      name = [path lastPathComponent];
      [db setObject:[path stringByDeletingLastPathComponent] forKey:name];
      [items replaceObjectAtIndex:i withObject:name];
    }

    [[ProcessManager shared] startOperationWithType:MoveOperation
                                             source:sourceDir
                                             target:[recycler path]
                                              files:items];
    [items release];
    [db writeToFile:dbPath atomically:YES];
    result = YES;
  }

  [db release];
  [recycler updateIconImage];

  return result;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"Recycler", @"Recycler: conclude dragging");
}

@end

// WindowMaker's callback funtion on mouse click.
// LMB click goes to dock app core window.
// RMB click goes to root window (handles by event.c in WindowMaker).
void _recyclerMouseDown(WObjDescriptor *desc, XEvent *event)
{
  NSEvent *theEvent;
  WAppIcon *aicon = desc->parent;
  NSInteger clickCount = 1;

  XUngrabPointer(dpy, CurrentTime);

  if (event->xbutton.button == Button1) {
    if (IsDoubleClick(wDefaultScreen(), event)) {
      clickCount = 2;
    }

    // Handle move of icon
    if (aicon->dock) {
      wHandleAppIconMove(aicon, event);
    }

    theEvent = [NSEvent mouseEventWithType:NSLeftMouseDown
                                  location:NSMakePoint(event->xbutton.x, event->xbutton.y)
                             modifierFlags:0
                                 timestamp:(NSTimeInterval)event->xbutton.time / 1000.0
                              windowNumber:[[recycler appIcon] windowNumber]
                                   context:[[recycler appIcon] graphicsContext]
                               eventNumber:event->xbutton.serial
                                clickCount:clickCount
                                  pressure:1.0];

    [recycler performSelectorOnMainThread:@selector(mouseDown:)
                               withObject:theEvent
                            waitUntilDone:NO];

  } else if (event->xbutton.button == Button3) {
    // This will bring menu of active application on screen at mouse pointer
    event->xbutton.window = event->xbutton.root;
    // XSendEvent(dpy, event->xbutton.root, False, ButtonPressMask, event);
    XSendEvent(dpy, aicon->dock->icon_array[0]->icon->icon_win, False, ButtonPressMask, event);
  }
}

@implementation RecyclerIcon

// Search for position in Dock for new Recycler
+ (int)newPositionInDock:(WDock *)dock
{
  WAppIcon *btn;
  int position = 0;

  for (position = dock->max_icons - 1; position > 0; position--) {
    if ((btn = dock->icon_array[position]) == NULL) {
      break;
    }
  }

  return position;
}

+ (WAppIcon *)createAppIconForDock:(WDock *)dock
{
  WAppIcon *btn;
  int rec_pos = [RecyclerIcon newPositionInDock:dock];

  btn = wAppIconCreateForDock(dock->screen_ptr, "-", "Recycler", "GNUstep", TILE_NORMAL);
  btn->yindex = rec_pos;
  btn->flags.running = 1;
  btn->flags.launching = 0;
  btn->flags.lock = 1;
  btn->command = wstrdup("-");
  btn->dnd_command = NULL;
  btn->paste_command = NULL;
  btn->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;

  return btn;
}

+ (void)rebuildDock:(WDock *)dock
{
  WScreen *scr = dock->screen_ptr;
  int new_max_icons = wDockMaxIcons(dock->screen_ptr);
  WAppIcon **new_icon_array;

  new_icon_array = wmalloc(sizeof(WAppIcon *) * new_max_icons);

  dock->icon_count = 0;
  for (int i = 0; i < new_max_icons; i++) {
    if (dock->icon_array[i] == NULL || i >= dock->max_icons) {
      new_icon_array[i] = NULL;
    } else {
      new_icon_array[i] = dock->icon_array[i];
      dock->icon_count++;
    }
  }

  wfree(dock->icon_array);
  dock->icon_array = new_icon_array;
  dock->max_icons = new_max_icons;
}

+ (WAppIcon *)recyclerAppIconForDock:(WDock *)dock
{
  WAppIcon *btn = NULL;
  WAppIcon *rec_btn = NULL;

  btn = dock->screen_ptr->app_icon_list;
  while (btn->next) {
    if (!strcmp(btn->wm_instance, "Recycler")) {
      rec_btn = btn;
      break;
    }
    btn = btn->next;
  }

  if (!rec_btn) {
    rec_btn = [RecyclerIcon createAppIconForDock:dock];
  } else {
    // Recycler icon can be restored from state file
    btn->icon->core->descriptor.handle_mousedown = _recyclerMouseDown;
  }

  return rec_btn;
}

+ (void)updatePositionInDock:(WDock *)dock
{
  WAppIcon *rec_icon = [RecyclerIcon recyclerAppIconForDock:dock];
  int yindex, new_yindex, max_position;

  yindex = rec_icon->yindex;
  // 1. Screen dimensions may have changed - rebuild Dock.
  //    If main display height reduced - Recycler will be removed from Dock.
  [RecyclerIcon rebuildDock:dock];

  // 2. Get new position for Recycler.
  new_yindex = [RecyclerIcon newPositionInDock:dock];

  // 3. Place Recycler to the new position if Dock has room.
  if (rec_icon->flags.docked) {
    if (new_yindex == 0) {
      // Dock has no room
      NSDebugLLog(@"Recycler", @"Recycler detach");
      wDockDetach(dock, rec_icon);
    } else {
      if (yindex != new_yindex) {
        NSDebugLLog(@"Recycler", @"Recycler: reattach");
        wDockReattachIcon(dock, rec_icon, 0, new_yindex);
      }
    }
  } else if (new_yindex > 0) {
    NSDebugLLog(@"Recycler", @"Recycler: attach at %i", new_yindex);
    wDockAttachIcon(dock, rec_icon, 0, new_yindex, NO);
  }
}

- (void)_initDefaults
{
  [super _initDefaults];

  [self setTitle:@"Recycler"];
  [self setExcludedFromWindowsMenu:YES];
  [self setReleasedWhenClosed:NO];

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GSAllowWindowsOverIcons"] == YES) {
    _windowLevel = NSDockWindowLevel;
  }
}

- (id)initWithWindowRef:(void *)xWindow recycler:(Recycler *)theRecycler
{
  self = [super initWithWindowRef:xWindow];
  recycler = theRecycler;

  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSApplicationDidChangeScreenParametersNotification
              object:NSApp];

  return self;
}

- (BOOL)canBecomeMainWindow
{
  return NO;
}

- (BOOL)canBecomeKeyWindow
{
  return NO;
}

- (BOOL)worksWhenModal
{
  return YES;
}

@end
