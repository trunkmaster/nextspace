/* 
 * ImageHolder.h created by probert on 2001-11-18 13:49:17 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageHolder.h,v 1.2 2001/11/18 14:13:55 probert Exp $
 */

#ifndef _IMAGEHOLDER_H_
#define _IMAGEHOLDER_H_

#import <Foundation/Foundation.h>

@class NSImage;

@interface ImageHolder : NSObject
{
    NSImage *image;
    NSArray *imageReps;
    NSDictionary *attributes;
}

- (id)initWithImage:(NSImage*)img reps:(NSArray *)r attributes:(NSDictionary*)d;

- (NSImage *)image;
- (NSArray *)imageReps;
- (NSDictionary *)attributes;

@end

#endif // _IMAGEHOLDER_H_

