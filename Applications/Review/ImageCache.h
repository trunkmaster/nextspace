/* 
 * ImageCache.h created by probert on 2001-11-11 12:53:18 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageCache.h,v 1.5 2001/11/18 14:34:46 probert Exp $
 */

#ifndef _IMAGECACHE_H_
#define _IMAGECACHE_H_

#import <Foundation/Foundation.h>

@class ImageHolder;

@interface ImageCache : NSObject
{
    NSMutableDictionary *cache;
    NSMutableArray *accessList;
    unsigned int maxImages;
}

+ (ImageCache *)sharedCache;

- (ImageHolder *)imageHolderForKey:(id)key;
- (void)cacheImageHolder:(ImageHolder *)object forKey:(id)key;

- (void)setMaxImages:(unsigned int)cnt;
- (unsigned int)maxImages;

- (void)removeOldestElementsFromCache:(int)num;

@end

#endif // _IMAGECACHE_H_

