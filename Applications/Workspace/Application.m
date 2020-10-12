/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2020 Sergii Stoian
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
#import "Application.h"
#import "Workspace+WM.h"

@interface WSApplication (Private)
- (void)_openDocument:(NSString*)filePath;
@end

//-----------------------------------------------------------------------------
// Application icon window
//-----------------------------------------------------------------------------
@interface WSIconWindow : NSWindow
@property (readonly) BOOL canBecomeMainWindow;
@property (readonly) BOOL canBecomeKeyWindow;
@property (readonly) BOOL becomesKeyOnlyIfNeeded;
@property (readonly) BOOL worksWhenModal;
@end
@implementation WSIconWindow

- (id)init
{
  self = [super init];
  _canBecomeMainWindow = NO;
  _canBecomeKeyWindow = NO;
  _becomesKeyOnlyIfNeeded = YES;
  _worksWhenModal = YES;

  return self;
}

- (void)_initDefaults
{
  [super _initDefaults];
  [self setTitle:[[NSProcessInfo processInfo] processName]];
  [self setExcludedFromWindowsMenu:YES];
  [self setReleasedWhenClosed:NO];
}

@end

//-----------------------------------------------------------------------------
// Application icon view
//-----------------------------------------------------------------------------
@interface WSAppIconView : NSView
@end
@implementation WSAppIconView

// Class variables
static NSCell* dragCell = nil;
static NSCell* tileCell = nil;

static NSSize scaledIconSizeForSize(NSSize imageSize)
{
  NSSize iconSize, retSize;
  
  iconSize = [GSCurrentServer() iconSize];
  retSize.width = imageSize.width * iconSize.width / 64;
  retSize.height = imageSize.height * iconSize.height / 64;
  return retSize;
}

+ (void) initialize
{
  NSImage *tileImage;
  NSSize  iconSize;

  iconSize = [GSCurrentServer() iconSize];
  /* _appIconInit will set our image */
  dragCell = [[NSCell alloc] initImageCell: nil];
  [dragCell setBordered: NO];
  
  tileImage = [[GSCurrentServer() iconTileImage] copy];
  [tileImage setScalesWhenResized: YES];
  [tileImage setSize: iconSize];
  tileCell = [[NSCell alloc] initImageCell: tileImage];
  RELEASE(tileImage);
  [tileCell setBordered: NO];
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent
{
  return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  return NSDragOperationGeneric;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
  return NSDragOperationGeneric;
}

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize = [GSCurrentServer() iconSize];
  
  [tileCell drawWithFrame: NSMakeRect(0, 0, iconSize.width, iconSize.height)
  		   inView: self];
  [dragCell drawWithFrame: NSMakeRect(0, 0, iconSize.width, iconSize.height)
		   inView: self];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame: frame];
  [self registerForDraggedTypes: [NSArray arrayWithObjects:
    NSFilenamesPboardType, nil]];
  return self;
}

- (void)mouseDown:(NSEvent*)theEvent
{
  if ([theEvent clickCount] >= 2) {
    [NSApp unhide:self];
  }
  else {
    NSPoint	lastLocation;
    NSPoint	location;
    NSUInteger eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                            | NSPeriodicMask | NSOtherMouseUpMask
                            | NSRightMouseUpMask);
    NSDate	*theDistantFuture = [NSDate distantFuture];
    BOOL	done = NO;

    lastLocation = [theEvent locationInWindow];
    [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];

    while (!done) {
      theEvent = [NSApp nextEventMatchingMask: eventMask
                                    untilDate: theDistantFuture
                                       inMode: NSEventTrackingRunLoopMode
                                      dequeue: YES];
	
      switch ([theEvent type]) {
      case NSRightMouseUp:
      case NSOtherMouseUp:
      case NSLeftMouseUp:
        /* any mouse up means we're done */
        done = YES;
        break;
      case NSPeriodic:
        location = [_window mouseLocationOutsideOfEventStream];
        if (NSEqualPoints(location, lastLocation) == NO)
          {
            NSPoint	origin = [_window frame].origin;

            origin.x += (location.x - lastLocation.x);
            origin.y += (location.y - lastLocation.y);
            [_window setFrameOrigin: origin];
          }
        break;

      default:
        break;
      }
    }
    [NSEvent stopPeriodicEvents];
  }
}                                                        

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  NSArray	*types;
  NSPasteboard	*dragPb;

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: NSFilenamesPboardType] == YES)
    {
      NSArray	*names = [dragPb propertyListForType: NSFilenamesPboardType];
      NSUInteger index;

      [NSApp activateIgnoringOtherApps: YES];
      for (index = 0; index < [names count]; index++)
	{
	  [(WSApplication *)NSApp _openDocument: [names objectAtIndex: index]];
	}
      return YES;
    }
  return NO;
}

- (void)setImage:(NSImage *)anImage
{
  NSImage *imgCopy = [anImage copy];

  if (imgCopy)
    {
      NSSize imageSize = [imgCopy size];

      [imgCopy setScalesWhenResized: YES];
      [imgCopy setSize: scaledIconSizeForSize(imageSize)];
    }
  [dragCell setImage: imgCopy];
  RELEASE(imgCopy);
  [self setNeedsDisplay: YES];
}

@end
//-----------------------------------------------------------------------------
// Application
//-----------------------------------------------------------------------------
@implementation WSApplication

- (void)_appIconInit
{
  WSAppIconView *iv;
  NSRect        iconContentRect;
  NSRect        iconFrame;
  NSRect        iconViewFrame;

  _app_icon_window = [[WSIconWindow alloc] initWithContentRect:NSZeroRect
                                                     styleMask:NSIconWindowMask
                                                       backing:NSBackingStoreRetained
                                                         defer:NO
                                                        screen:nil];
    
  iconContentRect = [_app_icon_window frame];
  iconContentRect.size = [GSCurrentServer() iconSize];
  iconFrame = [_app_icon_window frameRectForContentRect:iconContentRect];
  iconFrame.origin = [[NSScreen mainScreen] frame].origin;
  iconViewFrame = NSMakeRect(0, 0,
                             iconContentRect.size.width,
                             iconContentRect.size.height);
  [_app_icon_window setFrame:iconFrame display:YES];

  iv = [[WSAppIconView alloc] initWithFrame:iconViewFrame];
  [iv setImage: [self applicationIconImage]];
  [_app_icon_window setContentView:iv];
  RELEASE(iv);

  [_app_icon_window orderFrontRegardless];
}

- (void)_openDocument:(NSString*)filePath
{
  [_listener application:self openFile:filePath];
}

- (void)hide:(id)sender
{
  if ([sender isKindOfClass:[NSMenuItem class]] == NO) {
    sender = [[NSApp mainMenu] itemWithTitle:@"Hide"];
    if (sender == nil) {
      sender = [[NSApp mainMenu] itemWithTitle:@"Show"];
    }
  }
  
  if ([[sender title] isEqualToString:@"Hide"]) {
    [super hide:sender];
    [sender setTitle:@"Show"];
    _app_is_hidden = YES;
  }
  else {
    [self unhide:sender];
  }
}

- (void)unhide:(id)sender
{
  if ([sender isKindOfClass:[GSDisplayServer class]]) {
    NSWindow *menuWindow= [[self mainMenu] window];
    _app_is_active = YES;
    [menuWindow orderFront:self];
    [GSServerForWindow(menuWindow) setinputfocus:[menuWindow windowNumber]];
    return;
  }
  
  if (_app_is_hidden) {
    wUnhideApplication(wApplicationWithName(NULL, "Workspace"), NO, NO);
    [super unhide:sender];
  
    if ([sender isKindOfClass:[NSMenuItem class]] == NO) {
      sender = [[NSApp mainMenu] itemWithTitle:@"Show"];
    }
    if (sender) {
      [sender setTitle:@"Hide"];
    }
  }

  if (_app_is_active == NO) {
    [NSApp activateIgnoringOtherApps:YES];
  }
}

@end
