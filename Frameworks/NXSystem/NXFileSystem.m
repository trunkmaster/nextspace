/*
 *  NSFileSystem - abstract class for making OS specific operations with file 
 *  system: event monitor (file/dir deletion, creation, linking), 
 *  FS info (sizes, state, mount options, mount point).
 */

#import "NXFileSystem.h"

#define ONE_KB 1024
#define ONE_MB (ONE_KB * ONE_KB)
#define ONE_GB (ONE_KB * ONE_MB)
NSString *NXDescriptionForSize(unsigned long long size)
{
  NSString *sizeStr;

  if (size == 1)
    {
      sizeStr = @"1 byte";
    }

  if (size == 0)
    {
      sizeStr = @"0 bytes";
    }
  else if (size < (10 * ONE_KB))
    {
      sizeStr = [NSString stringWithFormat:@"%llu bytes", size];
    }
  else if (size < (100 * ONE_KB))
    {
      sizeStr = [NSString stringWithFormat:@"%3.2fKB",
	      ((double)size / (double)(ONE_KB))];
    }
  else if (size < (100 * ONE_MB))
    {
      sizeStr = [NSString stringWithFormat:@"%3.2fMB",
	      ((double)size / (double)(ONE_MB))];
    }
  else
    {
      sizeStr = [NSString stringWithFormat:@"%3.2fGB",
	      ((double)size / (double)(ONE_GB))];
    }

  return sizeStr;
}

@implementation NXFileSystem

+ (NSString *)fileSystemSizeAtPath:(NSString *)path
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary  *attrs = [fm fileSystemAttributesAtPath:path];
  NSNumber      *fsSize = [attrs objectForKey:NSFileSystemSize];

  if (fsSize == nil)
    {
      return NXDescriptionForSize(0L);
    }
      
  return NXDescriptionForSize([fsSize unsignedLongLongValue]);
}

+ (NSString *)fileSystemFreeSizeAtPath:(NSString *)path
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary  *attrs = [fm fileSystemAttributesAtPath:path];
  NSNumber      *fsFreeSize = [attrs objectForKey:NSFileSystemFreeSize];

  if (fsFreeSize == nil)
    {
      return NXDescriptionForSize(0L);
    }
      
  return NXDescriptionForSize([fsFreeSize unsignedLongLongValue]);
}

// TODO
+ (NXFSType)fileSystemTypeAtPath:(NSString *)path
{
  return [[NXMediaManager defaultManager] filesystemTypeAtPath:path];
}

// TODO
+ (NSString *)fileSystemMountPointAtPath:(NSString *)path
{
  return [[NXMediaManager defaultManager] mountPointForPath:path];
}
  
@end
