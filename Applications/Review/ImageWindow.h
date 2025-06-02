/* 
 * ImageWindow.h created by phr on 2000-10-17 17:08:05 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageWindow.h,v 1.3 2001/11/18 13:51:09 probert Exp $
 */

#import <AppKit/AppKit.h>
#import "ImageShowing.h"

@interface ImageWindow : NSObject <ImageShowing>
{
  id delegate;
  NSString *imagePath;
  NSSize imageSize;
  NSArray *representations;
  NSUInteger visibleRepIndex;
  NSImageView *imageView;
  NSDictionary *attr;
  NSPopUpButton *scalePopup;
  NSBox *box;
}

@property (readonly) NSWindow *window;
@property (readonly) NSImage *image;
@property (readonly) NSImageRep *visibleRep;

- (id)initWithContentsOfFile:(NSString *)path;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (void)windowWillClose:(NSNotification *)notif;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;

- (NSString *)path;
- (NSString *)imagePath;
- (NSString *)imageName;

- (NSString *)imageType;
- (NSString *)imageFileSize;
- (NSString *)imageFileModificationDate;
- (NSString *)imageFilePermissions;
- (NSString *)imageFileOwner;

- (NSString *)imageWidth;
- (NSString *)imageHeight;
- (NSString *)imageBitsPerPixel;
- (NSString *)imageBitsPerSample;
- (NSString *)imageNumberOfPlanes;
- (NSString *)imageBytesPerPlane;
- (NSString *)imageBytesPerRow;

- (NSString *)colorSpaceName;
- (NSString *)hasAlpha;

// TIFF and JPEG
- (NSString *)compressionType;
- (NSString *)compressionFactor;
// GIF
- (NSString *)imageFrameCount;
- (NSString *)imageCurrentFrame;
//
- (NSString *)imageGamma;
- (NSString *)imageProgressive;

@end

@interface NSObject (ImageWindowDelegates)

- (void)imageWindowWillClose:(id)sender;

@end
