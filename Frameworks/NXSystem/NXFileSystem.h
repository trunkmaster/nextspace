/*
 *  NSFileSystem - abstract class for making OS specific operations with file 
 *  system: FS info (sizes, state, mount options, mount point).
 */

#import <Foundation/Foundation.h>
#import <NXSystem/NXMediaManager.h>

NSString *NXDescriptionForSize(unsigned long long size);

@interface NXFileSystem : NSObject
{
}

+ (NSString *)fileSystemSizeAtPath:(NSString *)path;
+ (NSString *)fileSystemFreeSizeAtPath:(NSString *)path;
+ (NXFSType)fileSystemTypeAtPath:(NSString *)path;
+ (NSString *)fileSystemMountPointAtPath:(NSString *)path;

@end
