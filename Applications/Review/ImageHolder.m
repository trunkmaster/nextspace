/* 
 * ImageHolder.m created by probert on 2001-11-18 13:49:15 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageHolder.m,v 1.2 2001/11/18 14:13:55 probert Exp $
 */

#import "ImageHolder.h"
#import <AppKit/NSImage.h>

@implementation ImageHolder

- (id)initWithImage:(NSImage*)img reps:(NSArray *)r attributes:(NSDictionary*)d
{
    if( self = [super init] ) {
        image = RETAIN(img);
        imageReps = RETAIN(r);
        attributes = RETAIN(d);
    }
    return self;
}

- (void)dealloc
{
    RELEASE(image);
    RELEASE(imageReps);
    RELEASE(attributes);

    [super dealloc];
}

- (NSImage *)image;
{
    return image;
}

- (NSArray *)imageReps;
{
    return imageReps;
}

- (NSDictionary *)attributes;
{
    return attributes;
}

@end
