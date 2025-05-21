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
  NSDictionary *attr;
  NSImageRep *rep;
  int repCount;
  NSPopUpButton *scalePopup;
  NSBox *box;
  BOOL isMultipage;
}

@property (readonly) NSWindow *window;
@property (readonly) NSImage *image;

- (id)initWithContentsOfFile:(NSString *)path;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (void)windowWillClose:(NSNotification *)notif;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;

- (NSString *)path;
- (NSString *)imagePath;
- (NSString *)imageName;
- (NSString *)imageType;
- (NSString *)imageSize;
- (NSString *)imageFileModificationDate;
- (NSString *)imageFilePermissions;
- (NSString *)imageFileOwner;
- (NSString *)imageResolution;
- (NSString *)bitsPerSample;
- (NSString *)colorSpaceName;
- (NSString *)hasAlpha;
- (NSString *)imageReps;

@end

@interface NSObject (ImageWindowDelegates)

- (void)imageWindowWillClose:(id)sender;

@end
