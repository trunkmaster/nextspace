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
    if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO) {
      return nil;
    }
  }
  return self;
}

- (void)dealloc
{
  [panel release];
  [super dealloc];
}

- (void)awakeFromNib {
  [panel setFrameAutosaveName:@"Inspector"];
}

- (void)show
{
  if (![panel isVisible]) {
    [panel setFrameUsingName:@"Inspector"];
  }

  [panel makeKeyAndOrderFront:self];
}

- (void)imageWindowDidBecomeActive:(ImageWindow *)window
{
  [widthField setStringValue:window ? window.imageWidth : @""];
  [heightField setStringValue:window ? window.imageHeight : @""];
  [bitsPerPixelField setStringValue:window ? window.imageBitsPerPixel : @""];
  [samplesPerPixelField setStringValue:window ? window.imageBitsPerSample: @""];

  [formatField setStringValue:window ? window.imageType : @""];
  [fileSizeField setStringValue:window ? window.imageFileSize : @""];
  [fileModificationField setStringValue:window ? window.imageFileModificationDate : @""];

  [numberOfPlanesField setStringValue:window ? window.imageNumberOfPlanes : @""];
  [bytesPerPlaneField setStringValue:window ? window.imageBytesPerPlane : @""];
  [bytesPerRowField setStringValue:window ? window.imageBytesPerRow : @""];

  [compressionField setStringValue:window ? window.compressionType : @""];
  [compressionFactorField setStringValue:window ? window.compressionFactor : @""];

  [frameCountField setStringValue:window ? window.imageFrameCount : @""];
  [currentFrameField setStringValue:window ? window.imageCurrentFrame : @""];

  [gammaField setStringValue:window ? window.imageGamma : @""];
  [progressiveField setStringValue:window ? window.imageProgressive : @""];
}

@end
