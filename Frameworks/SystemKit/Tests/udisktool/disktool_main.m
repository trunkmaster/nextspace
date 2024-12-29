//
//
//

#include <stdio.h>

#import <Foundation/Foundation.h>

#import <SystemKit/OSEUDisksAdaptor.h>
#import <SystemKit/OSEUDisksDrive.h>
#import <SystemKit/OSEUDisksVolume.h>

static NSComparisonResult sort(id dict1, id dict2, void *context)
{
  NSString *p1 = [dict1 objectForKey:@"PartitionNumber"];
  NSString *p2 = [dict2 objectForKey:@"PartitionNumber"];
  
  if (!p1)
    return NSOrderedAscending;
  else if (!p2)
    return NSOrderedDescending;
  else
    return [p1 compare:p2];
}

void printVolumes(NSArray *volumes)
{
  NSEnumerator *e = [volumes objectEnumerator];
  NSDictionary *v;
  NSString *type, *fstype, *label, *mount;

  while ((v = [e nextObject]) != nil) {
    if ([v objectForKey:@"PartitionTableType"] != nil) {
      fprintf(stderr, "%s\n", [[v objectForKey:@"UNIXDevice"] cString]);
      fprintf(stderr, "  #:\tID\tTYPE\tNAME\t\tSIZE\t\tIDENTIFIER\tMOUNT\n");
      break;
    }
  }
  e = [volumes objectEnumerator];
  while ((v = [e nextObject]) != nil) {
    if ([v objectForKey:@"PartitionTableType"] != nil ||
        [[v objectForKey:@"Usage"] isEqualToString:@""])
      continue;

    // #:
    fprintf(stderr, "  %s:", [[v objectForKey:@"PartitionNumber"] cString]);
    // ID
    type = [v objectForKey:@"PartitionTypeID"];
    fprintf(stderr, "\r\t%s", [type cString]);

    // TYPE
    fstype = [v objectForKey:@"FileSystemType"];
    if (!fstype || [fstype isEqualToString:@""])
      fprintf(stderr, "\r\t\t ");
    else
      fprintf(stderr, "\r\t\t%s", [fstype cString]);

    if ([[v objectForKey:@"Usage"] isEqualToString:@"filesystem"]) {
      // NAME
      label = [v objectForKey:@"FileSystemLabel"];
      if (!label || [label isEqualToString:@""])
        fprintf(stderr, "\r\t\t\t ");
      else
        fprintf(stderr, "\r\t\t\t%s", [label cString]);
      // SIZE
      fprintf(stderr, "\r\t\t\t\t\t%s", [[v objectForKey:@"FileSystemSize"] cString]);
    } else {
      // NAME
      fprintf(stderr, "\r\t\t\t ");
      // SIZE
      fprintf(stderr, "\r\t\t\t\t\t%s", [[v objectForKey:@"PartitionSize"] cString]);
    }

    // IDENTIFIER
    fprintf(stderr, "\r\t\t\t\t\t\t\t%s", [[v objectForKey:@"UNIXDevice"] cString]);

    if ([[v objectForKey:@"Usage"] isEqualToString:@"filesystem"]) {
      // MOUNT
      mount = [v objectForKey:@"FileSystemMountPoint"];
      if (!mount || [mount isEqualToString:@""])
        fprintf(stderr, "\r\t\t\t\t\t\t\t\t\t \n");
      else
        fprintf(stderr, "\r\t\t\t\t\t\t\t\t\t%s\n", [mount cString]);
    } else {
      fprintf(stderr, "\n");
    }
  }
}

void printMountableVolumes(NSArray *volumes)
{
  NSEnumerator *e = [volumes objectEnumerator];
  NSDictionary *v;
  NSString     *fstype, *label;
      
  NSString *device;
  fprintf(stderr, "\n============ Mountable Volumes ===========\n");
  fprintf(stderr, "Label\t\tFS type\t\tDevice\n");
  fprintf(stderr, "=====\t\t=======\t\t======\n");
  e = [volumes objectEnumerator];
  while ((v = [e nextObject]) != nil)
    {
      label = [v objectForKey:@"FileSystemLabel"];
      if (label && ![label isEqualToString:@""])
        {
          fprintf(stderr,"%s", [label cString]);
              
          fstype = [v objectForKey:@"FileSystemType"];
          if (fstype && ![fstype isEqualToString:@""])
            {
              fprintf(stderr,"\r\t\t%s", [fstype cString]);
            }

          device = [v objectForKey:@"UNIXDevice"];
          fprintf(stderr, "\r\t\t\t\t%s\n", [device cString]);
        }
    }
}

BOOL getFileSystemInfoForPath(NSString *fullPath, BOOL *removableFlag, BOOL *writableFlag,
                              BOOL *unmountableFlag, NSString **description,
                              NSString **fileSystemType)
{
  OSEUDisksAdaptor *uda = [OSEUDisksAdaptor new];
  OSEUDisksVolume *volume = [uda mountedVolumeForPath:fullPath];
  OSEUDisksDrive *drive = [volume drive];

  if (volume == nil) {
    return NO;
  }

  if (drive == nil) {
    return NO;
  }

  *removableFlag = drive.isRemovable;
  *writableFlag = volume.isWritable;
  *unmountableFlag = !volume.isSystem;

  switch (volume.type) {
    case NXTFSTypeEXT:
      *fileSystemType = @"EXT";
      break;
    case NXTFSTypeXFS:
      *fileSystemType = @"XFS";
      break;
    case NXTFSTypeFAT:
      *fileSystemType = @"FAT";
      break;
    case NXTFSTypeISO:
      *fileSystemType = @"ISO";
      break;
    case NXTFSTypeNTFS:
      *fileSystemType = @"NTFS";
      break;
    case NXTFSTypeSwap:
      *fileSystemType = @"SWAP";
      break;
    case NXTFSTypeUDF:
      *fileSystemType = @"UDF";
      break;
    case NXTFSTypeUFS:
      *fileSystemType = @"UFS";
      break;
    default:
      *fileSystemType = @"UNKNOWN";
  }

  *description = [NSString stringWithFormat:@"%@ %@ filesystem at %@ drive",
                                            (volume.isWritable ? @"Writable" : @"Readonly"),
                                            *fileSystemType, drive.humanReadableName];

  return YES;
}

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  OSEUDisksAdaptor *uda;
  NSArray *mountPoints;
  NSDictionary *drives;
  NSDictionary *volumes;

  BOOL removableFlag;
  BOOL writableFlag;
  BOOL unmountableFlag;
  NSString *description;
  NSString *fileSystemType;

  uda = [OSEUDisksAdaptor new];
  drives = [uda availableDrives];

  for (OSEUDisksDrive *d in [drives allValues]) {
    volumes = [uda availableVolumesForDrive:[d objectPath]];
    NSLog(@"Drive: %@", [d humanReadableName]);
    NSLog(@"\tRemovable: %@", [d isRemovable] ? @"YES" : @"NO");
    for (OSEUDisksVolume *v in [volumes allValues]) {
      NSLog(@"\tVolume: %@", [v UNIXDevice]);
      NSLog(@"\t\tMount point: %@", [v mountPoints]);
      NSLog(@"\t\tWritable: %@", [v isWritable] ? @"YES" : @"NO");
      NSLog(@"\t\tUnmountable: %@", [v isSystem] ? @"NO" : @"YES");
      NSLog(@"\t\tFile System: %i", [v type]);
    }
    // printVolumes([[volumes allValues] sortedArrayUsingFunction:sort context:NULL]);
  }

  NSString *fullPath = @"/Users/me/Downloads";
  getFileSystemInfoForPath(@"/Users/me/Downloads", &removableFlag, &writableFlag, &unmountableFlag,
                           &description, &fileSystemType);
  NSLog(@"File system info for path: %@", fullPath);
  NSLog(@"\tRemovable: %@", removableFlag ? @"YES" : @"NO");
  NSLog(@"\tWritable: %@", writableFlag ? @"YES" : @"NO");
  NSLog(@"\tUnmountable: %@", unmountableFlag ? @"YES" : @"NO");
  NSLog(@"\tFile System: %@", fileSystemType);
  NSLog(@"\tDescription: %@", description);

  // e = [drives objectEnumerator];
  // while ((d = [e nextObject]) != nil) {
  //   volumes = [uda availableVolumesForDrive:[d objectForKey:@"ObjectPath"]];
  //   NSLog(@"Volumes: %@", volumes);
  //   // printVolumes([volumes sortedArrayUsingFunction:sort context:NULL]);
  // }

  mountPoints = [uda mountedRemovableMedia];
  if ([mountPoints count] > 0)
    NSLog(@"mountedRemovableMedia: %@", mountPoints);
  else
    NSLog(@"No removable media mounted.");

  // e = [drives objectEnumerator];
  // while ((d = [e nextObject]) != nil)
  //   {
  //     fprintf(stderr, "\n=== Drive: %s (%s)\n",
  //             [[d objectForKey:@"ModelName"] cString],
  //             [[d objectForKey:@"Size"] cString]);
  //     printMountableVolumes([uda availableVolumesForDrive:[d objectForKey:@"ObjectPath"]]);
  //   }

  [uda release];

  [pool release];

  return 0;
}
