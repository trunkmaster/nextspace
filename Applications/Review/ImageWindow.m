/*
 * ImageWindow.m
 */

#import "ImageWindow.h"
#import "ImageCache.h"
#import "Inspector.h"
#import <AppKit/PSOperators.h>

@interface RScrollView : NSScrollView
{
  NSView *scaleBtn;
}
- (void)setScaleView:(NSView *)scale;

@end

@implementation RScrollView

- (void)setScaleView:(NSView *)scale
{
  scaleBtn = scale;
}

- (void)tile
{
  NSScroller *hScroller = [self horizontalScroller];
  NSRect hsFrame;

  [super tile];

  hsFrame = [hScroller frame];
  hsFrame.size.width -= [scaleBtn frame].size.width + 2;
  [hScroller setFrame:hsFrame];
}

- (void)drawRect:(NSRect)rect
{
  NSRect hsFrame = [[self horizontalScroller] frame];
  NSPoint lineStart, lineEnd;
  NSGraphicsContext *ctxt = GSCurrentContext();

  [super drawRect:rect];

  if ([self isFlipped] != NO) {
    lineStart.x = hsFrame.origin.x + hsFrame.size.width;
    lineStart.y = hsFrame.origin.y - 1;
    lineEnd.y = lineStart.y + hsFrame.size.height + 1;
  }

  DPSsetgray(ctxt, 0.0);
  DPSsetlinewidth(ctxt, 1.0);

  DPSmoveto(ctxt, lineStart.x, lineStart.y);
  DPSlineto(ctxt, lineStart.x, lineEnd.y);
  DPSstroke(ctxt);

  lineEnd.y = lineStart.y;
  lineEnd.x = lineStart.x + 80;
  DPSmoveto(ctxt, lineStart.x, lineStart.y);
  DPSlineto(ctxt, lineEnd.x, lineEnd.y);
  DPSstroke(ctxt);
}

@end

//------------------------------------------------------------------------
@implementation ImageWindow

- (id)initWithContentsOfFile:(NSString *)path
{
  NSAssert(path, @"No path specified!");

  if ((self = [super init])) {
    NSRect frame = NSMakeRect(0, 0, 0, 0);
    RScrollView *scrollView = nil;
    NSImageView *imageView = nil;
    NSImage *image;
    NSArray *array;
    int wMask = (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask |
                 NSResizableWindowMask);

    attr = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
    RETAIN(attr);

    // Image loading
    imagePath = [path copy];
    if (!(image = [[NSImage alloc] initWithContentsOfFile:path])) {
      NSRunAlertPanel(@"Open file", @"File %@ doesn't contain image %@", @"Dismiss", nil, nil, path,
                      image);
      return nil;
    }

    // Image
    [image setBackgroundColor:[NSColor lightGrayColor]];
    array = [image representations];
    reps = [array count];
    rep = [array objectAtIndex:0];

    if (rep == nil) {
      return nil;
    }
    [rep retain];

    imageSize = [image size];
    frame.size = imageSize;

    // ImageView and ScrollView
    imageView = [[NSImageView alloc] initWithFrame:frame];
    [imageView setEditable:NO];
    [imageView setImage:image];
    RELEASE(image);

    frame.size = [NSScrollView frameSizeForContentSize:[imageView frame].size
                                 hasHorizontalScroller:YES
                                   hasVerticalScroller:YES
                                            borderType:NSNoBorder];
    scrollView = [[RScrollView alloc] initWithFrame:frame];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDocumentView:imageView];
    RELEASE(imageView);
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    // Content view
    box = [[NSBox alloc] init];
    [box setTitlePosition:NSNoTitle];
    [box setBorderType:NSNoBorder];
    [box setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [box setContentViewMargins:NSMakeSize(0.0, 0.0)];
    [box setFrameFromContentFrame:frame];

    // Popup
    scalePopup =
        [[NSPopUpButton alloc] initWithFrame:NSMakeRect([box frame].size.width - 57, 0, 57, 17)];
    [scalePopup setRefusesFirstResponder:YES];
    [scalePopup addItemWithTitle:@"10%"];
    [scalePopup addItemWithTitle:@"20%"];
    [scalePopup addItemWithTitle:@"30%"];
    [scalePopup addItemWithTitle:@"40%"];
    [scalePopup addItemWithTitle:@"50%"];
    [scalePopup addItemWithTitle:@"60%"];
    [scalePopup addItemWithTitle:@"70%"];
    [scalePopup addItemWithTitle:@"80%"];
    [scalePopup addItemWithTitle:@"90%"];
    [scalePopup addItemWithTitle:@"100%"];
    [scalePopup addItemWithTitle:@"200%"];
    [scalePopup addItemWithTitle:@"300%"];
    [scalePopup addItemWithTitle:@"400%"];
    [scalePopup addItemWithTitle:@"500%"];
    [scalePopup addItemWithTitle:@"600%"];
    [scalePopup addItemWithTitle:@"700%"];
    [scalePopup setAutoresizingMask:(NSViewMaxYMargin | NSViewMinXMargin)];
    [scalePopup selectItemWithTitle:@"100%"];
    [scrollView setScaleView:scalePopup];
    [scrollView tile];

    [box addSubview:scrollView];
    RELEASE(scrollView);
    [box addSubview:scalePopup];
    RELEASE(scalePopup);

    // Window
    frame = [NSWindow frameRectForContentRect:frame styleMask:wMask];
    if (imageSize.width > ([[NSScreen mainScreen] frame].size.width - 64)) {
      frame.size.width = [[NSScreen mainScreen] frame].size.width - 164;
    }
    if (imageSize.height > ([[NSScreen mainScreen] frame].size.height - 64)) {
      frame.size.height = [[NSScreen mainScreen] frame].size.height - 64;
    }
    if (frame.size.width < 100)
      frame.size.width = 100;
    if (frame.size.height < 100)
      frame.size.height = 100;

    window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:wMask
                                           backing:NSBackingStoreRetained
                                             defer:YES];
    [window setReleasedWhenClosed:YES];
    [window setDelegate:self];
    [window setFrame:frame display:YES];
    [window setMaxSize:frame.size];
    [window setMinSize:NSMakeSize(100, 100)];
    [window setContentView:box];
    RELEASE(box);
    [window setTitleWithRepresentedFilename:path];
    [window setReleasedWhenClosed:YES];

    [window center];
    [window makeKeyAndOrderFront:nil];
    [window display];
  }

  return self;
}

- (void)dealloc
{
  RELEASE(window);
  RELEASE(imagePath);
  RELEASE(attr);
  RELEASE(rep);

  [super dealloc];
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
  delegate = aDelegate;
}

- (void)windowWillClose:(NSNotification *)notif
{
  if ([[notif object] isEqual:window]) {
    if (delegate && [delegate respondsToSelector:@selector(imageWindowWillClose:)]) {
      [delegate imageWindowWillClose:self];
      [window setDelegate:nil];
      window = nil;
    }
  }
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  if ([[aNotification object] isEqual:window]) {
    [[Inspector sharedInspector] imageWindowDidBecomeActive:self];
  }
}

- (NSString *)path
{
  return imagePath;
}

- (NSString *)imagePath
{
  return [imagePath stringByDeletingLastPathComponent];
}

- (NSString *)imageName
{
  return [imagePath lastPathComponent];
}

- (NSString *)imageType
{
  return [imagePath pathExtension];
}

- (NSString *)imageSize
{
  int bytes = [[attr objectForKey:@"NSFileSize"] intValue];

  return [NSString stringWithFormat:@"%d Bytes", bytes];
}

- (NSString *)imageFileModificationDate
{
  NSDate *date = [attr objectForKey:@"NSFileModificationDate"];

  return [date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil];
}

- (NSString *)imageFilePermissions
{
  NSNumber *permissions = [attr objectForKey:@"NSFilePosixPermissions"];

  return [permissions description];
}

- (NSString *)imageFileOwner
{
  NSString *owner = [attr objectForKey:@"NSFileOwnerAccountName"];

  return owner;
}

- (NSString *)imageResolution
{
  return [NSString stringWithFormat:@"%.1f x %.1f", imageSize.width, imageSize.height];
}

- (NSString *)bitsPerSample
{
  return [NSString stringWithFormat:@"%ld", [rep bitsPerSample]];
}

- (NSString *)colorSpaceName
{
  return [rep colorSpaceName];
}

- (NSString *)hasAlpha
{
  return [NSString stringWithFormat:@"%@", [rep hasAlpha] ? @"Yes" : @"No"];
}

- (NSString *)imageReps
{
  return [NSString stringWithFormat:@"%d", reps];
}

@end
