/* 
 * ImageCache.m created by probert on 2001-11-11 12:53:16 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: ImageCache.m,v 1.5 2001/11/18 14:34:46 probert Exp $
 */

#import "ImageCache.h"
#import "ImageHolder.h"

@implementation ImageCache

static ImageCache *_imgCache = nil;

+ (ImageCache *)sharedCache;
{
  if( _imgCache == nil )
	{
	  _imgCache = [[ImageCache alloc] init];
	}

  return _imgCache;
}

- (id)init
{
  if( self = [super init])
	{
	  maxImages = 50;

	  cache = [[NSMutableDictionary alloc] init];
	  accessList = [[NSMutableArray alloc] initWithCapacity:maxImages];
    }

  return self;
}

- (void)dealloc
{
  RELEASE(cache);
  RELEASE(accessList);

  [super dealloc];
}

- (ImageHolder *)imageHolderForKey:(id)key
{
  ImageHolder *obj = [cache objectForKey:key];

  if([accessList containsObject:key])
	{
	  [accessList removeObject:key];
	}
  [accessList addObject:key];

  return obj;
}

- (void)cacheImageHolder:(ImageHolder *)object forKey:(id)key
{
  [cache setObject:object forKey:key];

  if( [cache count] > maxImages )
	{
	  [self removeOldestElementsFromCache:1];
	}
}

- (void)setMaxImages:(unsigned int)cnt
{
  if( cnt < maxImages )
	{
	  [self removeOldestElementsFromCache:(maxImages - cnt)];
    }

  maxImages = cnt;
}

- (unsigned int)maxImages
{
  return maxImages;
}

- (void)removeOldestElementsFromCache:(int)num
{
  int i;
  int n = [accessList count];

  if( n < num )
	{
	  num = n;
    }

  for( i=0; i<num; i++ )
	{
	  id key = [accessList objectAtIndex:0];

	  [cache removeObjectForKey:key];
	  [accessList removeObjectAtIndex:0];
    }
}

@end
