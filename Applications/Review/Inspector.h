/* 
 * 
 */

#import <AppKit/AppKit.h>
#import "ImageShowing.h"

@interface Inspector : NSObject
{
  IBOutlet id panel;
  IBOutlet id widthField;
  IBOutlet id heightField;
  IBOutlet id bitsPerPixelField;
  IBOutlet id samplesPerPixelField;

  IBOutlet id formatField;
  IBOutlet id fileSizeField;
  IBOutlet id fileModificationField;

  IBOutlet id numberOfPlanesField;
  IBOutlet id bytesPerPlaneField;
  IBOutlet id bytesPerRowField;

  IBOutlet id compressionField;
  IBOutlet id compressionFactorField;

  IBOutlet id frameCountField;
  IBOutlet id currentFrameField;
  
  IBOutlet id gammaField;
  IBOutlet id progressiveField;
}

+ (Inspector *)sharedInspector;

- (void)show;

- (void)imageWindowDidBecomeActive:(id<ImageShowing>)imgWin;

@end
