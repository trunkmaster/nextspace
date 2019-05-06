/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "OSEFileSystem.h"

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

@implementation OSEFileSystem

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
+ (NXTFSType)fileSystemTypeAtPath:(NSString *)path
{
  return [[OSEMediaManager defaultManager] filesystemTypeAtPath:path];
}

// TODO
+ (NSString *)fileSystemMountPointAtPath:(NSString *)path
{
  return [[OSEMediaManager defaultManager] mountPointForPath:path];
}
  
@end
