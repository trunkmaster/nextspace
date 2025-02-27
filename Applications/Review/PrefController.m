/*
 * PrefController.m created by probert on 2001-11-15 20:24:08 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: PrefController.m,v 1.4 2002/01/26 17:08:43 probert Exp $
 */

#import "PrefController.h"
#import "ImageCache.h"

@implementation PrefController

- (id)init
{
  if (self = [super init]) {
    unsigned int style = NSTitledWindowMask | NSClosableWindowMask;
    NSRect winFrame = NSMakeRect(200, 300, 260, 280);
    NSRect rect;
    NSTextField *textField;
    NSBox *box;
    NSMatrix *matrix;
    NSButton *button;
    NSButtonCell *buttonCell = [[NSButtonCell alloc] init];
    NSDictionary *prefs;

    prefs = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    prefDict = [[NSMutableDictionary alloc] initWithDictionary:prefs];

    preferences = [[NSWindow alloc] initWithContentRect:winFrame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:YES];
    [preferences setMinSize:NSMakeSize(260, 280)];
    [preferences setTitle:@"Preferences"];
    [preferences setDelegate:self];
    [preferences setReleasedWhenClosed:NO];
    [preferences center];
    [preferences setFrameAutosaveName:@"Preferences"];

    box = [[NSBox alloc] init];
    [box setTitle:@"Image Cache"];
    [box setFrameFromContentFrame:NSMakeRect(16, 180, 228, 64)];
    [[preferences contentView] addSubview:box];
    RELEASE(box);

    textField = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 16, 80, 21)];
    [textField setAlignment:NSRightTextAlignment];
    [textField setBordered:NO];
    [textField setEditable:NO];
    [textField setBezeled:NO];
    [textField setDrawsBackground:NO];
    [textField setStringValue:@"Cache size:"];
    [box addSubview:textField];
    RELEASE(textField);

    rect = NSMakeRect(92, 16, 124, 21);
    cacheSizeField = [[NSTextField alloc] initWithFrame:rect];
    [cacheSizeField setAlignment:NSRightTextAlignment];
    [cacheSizeField setBordered:NO];
    [cacheSizeField setEditable:YES];
    [cacheSizeField setBezeled:YES];
    [cacheSizeField setDrawsBackground:YES];
    [cacheSizeField setTarget:self];
    [cacheSizeField setAction:@selector(setCacheSize:)];
    [box addSubview:cacheSizeField];
    RELEASE(cacheSizeField);

    rect = NSMakeRect(32, 144, 220, 15);
    openRecursive = [[NSButton alloc] initWithFrame:rect];
    [openRecursive setTitle:@"Open path recursively"];
    [openRecursive setButtonType:NSSwitchButton];
    [openRecursive setBordered:NO];
    [openRecursive setTarget:self];
    [openRecursive setAction:@selector(setOpenRecursive:)];
    [openRecursive setContinuous:NO];
    [[preferences contentView] addSubview:openRecursive];
    [openRecursive sizeToFit];
    RELEASE(openRecursive);

    rect = NSMakeRect(132, 8, 116, 24);
    matrix = [[NSMatrix alloc] initWithFrame:rect
                                        mode:NSHighlightModeMatrix
                                   prototype:buttonCell
                                numberOfRows:1
                             numberOfColumns:2];
    [matrix setSelectionByRect:YES];
    [matrix setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [matrix setTarget:self];
    [matrix setAction:@selector(buttonsPressed:)];
    [matrix setIntercellSpacing:NSMakeSize(2, 2)];
    [[preferences contentView] addSubview:matrix];
    RELEASE(matrix);
    RELEASE(buttonCell);

    button = [matrix cellAtRow:0 column:0];
    [button setTag:0];
    [button setStringValue:@"Reset"];
    [button setBordered:YES];
    [button setButtonType:NSMomentaryPushButton];

    button = [matrix cellAtRow:0 column:1];
    [button setTag:1];
    [button setStringValue:@"Set"];
    [button setBordered:YES];
    [button setButtonType:NSMomentaryPushButton];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(preferences);
  RELEASE(prefDict);

  [super dealloc];
}

- (void)show
{
  NSString *string = nil;

  if (![preferences isVisible]) {
    [preferences setFrameUsingName:@"Preferences"];
  }

  string = [prefDict objectForKey:@"CacheSize"];
  [cacheSizeField setStringValue:(string) ? string : @"50"];

  string = [prefDict objectForKey:@"OpenRec"];
  [openRecursive setState:([string isEqualToString:@"YES"]) ? NSOnState : NSOffState];

  [preferences makeKeyAndOrderFront:self];
}

- (void)setCacheSize:(id)sender
{
  NSString *val = [cacheSizeField stringValue];

  [prefDict setObject:val forKey:@"CacheSize"];
  [preferences setDocumentEdited:YES];
}

- (void)setOpenRecursive:(id)sender
{
  switch ([[sender selectedCell] state]) {
    case 0:
      [prefDict setObject:@"NO" forKey:@"OpenRec"];
      break;
    case 1:
      [prefDict setObject:@"YES" forKey:@"OpenRec"];
      break;
    default:
      break;
  }

  [preferences setDocumentEdited:YES];
}

- (void)buttonsPressed:(id)sender
{
  switch ([[sender selectedCell] tag]) {
    case 0:
      [self resetPreferences];
      break;
    case 1:
      [self setPreferences];
      break;
  }

  [preferences setDocumentEdited:NO];
  //[preferences orderOut:self];
}

- (void)resetPreferences
{
  NSString *string;

  string = [[NSUserDefaults standardUserDefaults] objectForKey:@"CacheSize"];
  [cacheSizeField setStringValue:(string) ? string : @"50"];

  [openRecursive setState:([[[NSUserDefaults standardUserDefaults] objectForKey:@"OpenRec"]
                              isEqualToString:@"YES"])
                              ? NSOnState
                              : NSOffState];
}

- (void)setPreferences
{
  NSString *string = [prefDict objectForKey:@"CacheSize"];

  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"CacheSize"];
  [[ImageCache sharedCache] setMaxImages:[string intValue]];

  string = [prefDict objectForKey:@"OpenRec"];
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"OpenRec"];
}

@end
