/*
 * ImageShowing.h created by probert on 2001-11-17 14:50:02 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageShowing.h,v 1.2 2001/11/18 13:51:09 probert Exp $
 */

#import <Foundation/NSString.h>

@protocol ImageShowing <NSObject>

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

- (NSString *)hasAlpha;

@end
