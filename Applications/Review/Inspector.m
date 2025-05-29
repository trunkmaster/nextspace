/*
 * 
 */

#import "ImageWindow.h"
#import "Inspector.h"

@implementation Inspector

static Inspector *_inspector = nil;

+ (Inspector *)sharedInspector
{
  if (_inspector == nil) {
    _inspector = [[Inspector alloc] init];
  }

  return _inspector;
}

- (id)init
{
  if (self = [super init]) {
    if ([NSBundle loadNibNamed:@"Inspector" owner:self] != NO) {
      [panel setFrameUsingName:@"Inspector"];
    }
  }
  return self;
}

- (void)dealloc
{
  [panel release];
  [super dealloc];
}

- (void)show
{
//   if (![panel isVisible]) {
//     [panel setFrameUsingName:@"Inspector"];
//   }

  [panel makeKeyAndOrderFront:self];
}

- (void)imageWindowDidBecomeActive:(ImageWindow *)window
{
  [widthField setStringValue:window.imageWidth];
  [heightField setStringValue:window.imageHeight];
  [bitsPerPixelField setStringValue:window.imageBitsPerPixel];
  [samplesPerPixelField setStringValue:window.imageBitsPerSample];

  [formatField setStringValue:window.imageType];
  [fileSizeField setStringValue:window.imageFileSize];
  [fileModificationField setStringValue:window.imageFileModificationDate];

  [numberOfPlanesField setStringValue:window.imageNumberOfPlanes];
  [bytesPerPlaneField setStringValue:window.imageBytesPerPlane];
  [bytesPerRowField setStringValue:window.imageBytesPerRow];

  [compressionField setStringValue:window.compressionType];
  [compressionFactorField setStringValue:window.compressionFactor];
}

@end
