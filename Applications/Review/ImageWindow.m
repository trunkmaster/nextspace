/*
 * ImageWindow.m
 */

#import "ImageWindow.h"
#import "ImageCache.h"
#import "Inspector.h"
#import <AppKit/PSOperators.h>

#pragma mark - Custom ScrollView

@interface ImageScrollView : NSScrollView
{
}
@property (readwrite, assign) NSView *scaleView;
@property (readwrite, assign) NSView *multipageView;

@end

@implementation ImageScrollView

- (void)tile
{
  [super tile];

  if (_multipageView) {
    NSScroller *vScroller = [self verticalScroller];
    NSRect vsFrame = [vScroller frame];
    // NSPoint vsOrigin = vsFrame.origin;

    vsFrame.size.height -= _multipageView.frame.size.height;

    [vScroller setFrame:vsFrame];
  }

  if (_scaleView) {
    NSScroller *hScroller = [self horizontalScroller];
    NSRect hsFrame = [hScroller frame];

    hsFrame.size.width -= _scaleView.frame.size.width + 3;
    [hScroller setFrame:hsFrame];
  }
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

#pragma mark - Multipage controls

@interface ImageMultipageView : NSView
@end

@implementation ImageMultipageView

- (instancetype)initWithFrame:(NSRect)rect
                       target:(id)targetObject
                   nextAction:(SEL)nextSelector
                   prevAction:(SEL)prevSelector
{
  [super initWithFrame:rect];

  NSButton *pageUpButton, *pageDownButton;
  pageUpButton = [[NSButton alloc] initWithFrame:NSMakeRect(1, 18, 16, 16)];
  [pageUpButton setButtonType:NSMomentaryChangeButton];
  [pageUpButton setImagePosition:NSImageOnly];
  [pageUpButton setRefusesFirstResponder:YES];
  [pageUpButton setImage:[NSImage imageNamed:@"PageUp"]];
  [pageUpButton setAlternateImage:[NSImage imageNamed:@"PageUpH"]];
  [pageUpButton setTarget:targetObject];
  [pageUpButton setAction:prevSelector];
  [self addSubview:pageUpButton];

  pageDownButton = [[NSButton alloc] initWithFrame:NSMakeRect(1, 1, 16, 16)];
  [pageDownButton setButtonType:NSMomentaryChangeButton];
  [pageDownButton setImagePosition:NSImageOnly];
  [pageDownButton setRefusesFirstResponder:YES];
  [pageDownButton setImage:[NSImage imageNamed:@"PageDown"]];
  [pageDownButton setAlternateImage:[NSImage imageNamed:@"PageDownH"]];
  [pageDownButton setTarget:targetObject];
  [pageDownButton setAction:nextSelector];
  [self addSubview:pageDownButton];

  return self;
}

- (void)drawRect:(NSRect)rect
{
  NSGraphicsContext *ctxt = GSCurrentContext();

  [super drawRect:rect];

  DPSmoveto(ctxt, 18, 0);
  DPSlineto(ctxt, 18, self.frame.size.height);
  DPSstroke(ctxt);
}
@end

#pragma mark - Image window

@implementation ImageWindow

- (BOOL)_displayRepresentationAtIndex:(NSUInteger)index
{
  visibleRepIndex = index;
  if (_visibleRep) {
    [_visibleRep release];
  }
  _visibleRep = [representations objectAtIndex:visibleRepIndex];

  if (_visibleRep == nil) {
    NSLog(@"Failed to get representation at index %lu", index);
    return NO;
  } else {
    [_visibleRep retain];
    if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
      // [_image release];
      _image = [[NSImage alloc] initWithData:[(NSBitmapImageRep *)_visibleRep TIFFRepresentation]];
      [imageView setImage:_image];
    } else {
      return NO;
    }
  }
  return YES;
}

- (void)displayNextRpresentation:(id)sender
{
  if (visibleRepIndex < [representations count] - 1) {
    [self _displayRepresentationAtIndex:visibleRepIndex + 1];
    [[Inspector sharedInspector] imageWindowDidBecomeActive:self];
  }
}
- (void)displayPrevRpresentation:(id)sender
{
  if (visibleRepIndex > 0) {
    [self _displayRepresentationAtIndex:visibleRepIndex - 1];
    [[Inspector sharedInspector] imageWindowDidBecomeActive:self];
  }
}

- (id)initWithContentsOfFile:(NSString *)path
{
  NSAssert(path, @"No path specified!");

  if ((self = [super init])) {
    NSRect frame = NSMakeRect(0, 0, 0, 0);
    ImageScrollView *scrollView = nil;

    int wMask = (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask |
                 NSResizableWindowMask);

    attr = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
    RETAIN(attr);

    // Image loading
    imagePath = [path copy];
    if (!(_image = [[NSImage alloc] initWithContentsOfFile:path])) {
      NSRunAlertPanel(@"Open file", @"File %@ doesn't contain image.", @"Dismiss", nil, nil, path);
      return nil;
    }

    imageSize = [_image size];
    frame.size = imageSize;
    // ImageView
    if (imageSize.width < 200 || imageSize.height < 200) {
      frame.size = NSMakeSize(200,200);
    }
    imageView = [[NSImageView alloc] initWithFrame:frame];
    [imageView setEditable:NO];
    [imageView setImageAlignment:NSImageAlignCenter];
    // Image
    [_image setBackgroundColor:[NSColor lightGrayColor]];
    representations = [_image representations];
    [representations retain];
    if ([self _displayRepresentationAtIndex:0] == NO) {
      return nil;
    }

    // ScrollView
    frame.size = [NSScrollView frameSizeForContentSize:[imageView frame].size
                                 hasHorizontalScroller:YES
                                   hasVerticalScroller:YES
                                            borderType:NSNoBorder];
    scrollView = [[ImageScrollView alloc] initWithFrame:frame];
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
        [[NSPopUpButton alloc] initWithFrame:NSMakeRect([box frame].size.width - 58, 1, 57, 16)];
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
    scrollView.scaleView = scalePopup;

    [box addSubview:scrollView];
    RELEASE(scrollView);
    [box addSubview:scalePopup];
    RELEASE(scalePopup);

    // Multipage controls
    if ([representations count] > 1) {
      ImageMultipageView *multipageView;

      multipageView =
          [[ImageMultipageView alloc] initWithFrame:NSMakeRect(0, 0, 19, 34)
                                             target:self
                                         nextAction:@selector(displayNextRpresentation:)
                                         prevAction:@selector(displayPrevRpresentation:)];
      scrollView.multipageView = multipageView;
      [box addSubview:multipageView];
      RELEASE(multipageView);
    }

    [scrollView tile];

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

    _window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:wMask
                                           backing:NSBackingStoreRetained
                                             defer:YES];
    [_window setReleasedWhenClosed:YES];
    [_window setDelegate:self];
    [_window setFrame:frame display:YES];
    [_window setMaxSize:frame.size];
    [_window setMinSize:NSMakeSize(200, 200)];
    [_window setContentView:box];
    RELEASE(box);
    [_window setTitleWithRepresentedFilename:path];
    [_window setReleasedWhenClosed:YES];

    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [_window display];
  }

  return self;
}

- (void)dealloc
{
  RELEASE(_window);
  RELEASE(_image);
  RELEASE(imagePath);
  RELEASE(attr);

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
  if ([[notif object] isEqual:_window]) {
    if (delegate && [delegate respondsToSelector:@selector(imageWindowWillClose:)]) {
      [delegate imageWindowWillClose:self];
      [_window setDelegate:nil];
      _window = nil;
    }
  }
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  if ([[aNotification object] isEqual:_window]) {
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
  NSString *ext = [imagePath pathExtension];
  if (ext) {
    return ext;
  }

  return @"";
}

- (NSString *)imageFileSize
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

- (NSString *)imageWidth
{
  return [NSString stringWithFormat:@"%ld", _visibleRep.pixelsWide];
}

- (NSString *)imageHeight
{
  return [NSString stringWithFormat:@"%ld", _visibleRep.pixelsHigh];
}

- (NSString *)imageBitsPerPixel
{
  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    return [NSString stringWithFormat:@"%ld", rep.bitsPerPixel];
  }
  return @"-";
}

- (NSString *)imageBitsPerSample
{
  return [NSString stringWithFormat:@"%ld", _visibleRep.bitsPerSample];
}
- (NSString *)imageNumberOfPlanes
{
  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    return [NSString stringWithFormat:@"%ld", rep.numberOfPlanes];
  }
  return @"-";
}

- (NSString *)imageBytesPerPlane
{
  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    return [NSString stringWithFormat:@"%ld", rep.bytesPerPlane];
  }
  return @"-";
}

- (NSString *)imageBytesPerRow
{
  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    return [NSString stringWithFormat:@"%ld", rep.bytesPerRow];
  }
  return @"-";
}

- (NSString *)colorSpaceName
{
  return [_visibleRep colorSpaceName];
}

- (NSString *)hasAlpha
{
  return [NSString stringWithFormat:@"%@", [_visibleRep hasAlpha] ? @"Yes" : @"No"];
}

- (NSString *)compressionType
{
  NSString *type = @"None";

  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    NSNumber *compression = [rep valueForProperty:NSImageCompressionMethod];

    switch (compression.integerValue) {
      case NSTIFFCompressionCCITTFAX3:
        type = @"CCITT Groups 3";
        break;
      case NSTIFFCompressionCCITTFAX4:
        type = @"CCITT Groups 4";
        break;
      case NSTIFFCompressionLZW:
        type = @"LZW";
        break;
      case NSTIFFCompressionJPEG:
        type = @"JPEG";
        break;
      case NSTIFFCompressionNEXT:
        type = @"NeXT";
        break;
      case NSTIFFCompressionPackBits:
        type = @"Pack Bits";
        break;
      case NSTIFFCompressionOldJPEG:
        type = @"Old JPEG";
        break;
      }
  }
  return type;
}

- (NSString *)compressionFactor
{
  if ([_visibleRep isKindOfClass:[NSBitmapImageRep class]]) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)_visibleRep;
    NSNumber *compression = [rep valueForProperty:NSImageCompressionFactor];
    return [NSString stringWithFormat:@"%.1f", compression.floatValue];
  }
  return @"0";
}

@end
