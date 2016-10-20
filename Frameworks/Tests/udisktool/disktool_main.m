//
//
//

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <NXSystem/NXUDisksAdaptor.h>

// - (BOOL) getFileSystemInfoForPath: (NSString*)fullPath
//                       isRemovable: (BOOL*)removableFlag
//                        isWritable: (BOOL*)writableFlag
//                     isUnmountable: (BOOL*)unmountableFlag
//                       description: (NSString **)description
//                              type: (NSString **)fileSystemType
// {
// }

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
  NSString     *type, *fstype, *label, *mount;
      
  while ((v = [e nextObject]) != nil)
    {
      if ([v objectForKey:@"PartitionTableType"] != nil)
        {
          fprintf(stderr, "%s\n", [[v objectForKey:@"UNIXDevice"] cString]);
          fprintf(stderr, "  #:\tID\tTYPE\tNAME\t\tSIZE\t\tIDENTIFIER\tMOUNT\n");
          break;
        }
    }
  e = [volumes objectEnumerator];
  while ((v = [e nextObject]) != nil)
    {
      if ([v objectForKey:@"PartitionTableType"] != nil ||
          [[v objectForKey:@"Usage"] isEqualToString:@""])
        continue;
      
      // #:
      fprintf(stderr,"  %s:",
              [[v objectForKey:@"PartitionNumber"] cString]);
      // ID
      type = [v objectForKey:@"PartitionTypeID"];
      fprintf(stderr,"\r\t%s", [type cString]);

      // TYPE
      fstype = [v objectForKey:@"FileSystemType"];
      if (!fstype || [fstype isEqualToString:@""])
        fprintf(stderr,"\r\t\t ");
      else
        fprintf(stderr,"\r\t\t%s", [fstype cString]);
      
      if ([[v objectForKey:@"Usage"] isEqualToString:@"filesystem"])
        {
          // NAME
          label = [v objectForKey:@"FileSystemLabel"];
          if (!label || [label isEqualToString:@""])
            fprintf(stderr,"\r\t\t\t ");
          else
            fprintf(stderr,"\r\t\t\t%s", [label cString]);
          // SIZE
          fprintf(stderr,"\r\t\t\t\t\t%s",
                  [[v objectForKey:@"FileSystemSize"] cString]);
        }
      else
        {
          // NAME
          fprintf(stderr,"\r\t\t\t ");
          // SIZE
          fprintf(stderr,"\r\t\t\t\t\t%s",
                  [[v objectForKey:@"PartitionSize"] cString]);
        }

      // IDENTIFIER
      fprintf(stderr,"\r\t\t\t\t\t\t\t%s", [[v objectForKey:@"UNIXDevice"] cString]);
      
      if ([[v objectForKey:@"Usage"] isEqualToString:@"filesystem"])
        {
          // MOUNT
          mount = [v objectForKey:@"FileSystemMountPoint"];
          if (!mount || [mount isEqualToString:@""])
            fprintf(stderr,"\r\t\t\t\t\t\t\t\t\t \n");
          else
            fprintf(stderr,"\r\t\t\t\t\t\t\t\t\t%s\n", [mount cString]);
        }
      else
        {
          fprintf(stderr,"\n");
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

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NXUDisksAdaptor   *uda;
  NSArray           *drives, *volumes, *mountPoints;
  NSEnumerator      *e;
  NSDictionary      *d;

  uda = [NXUDisksAdaptor new];
  drives = [uda availableDrives];

  e = [drives objectEnumerator];
  while ((d = [e nextObject]) != nil)
    {
      volumes = [uda availableVolumesForDrive:[d objectForKey:@"ObjectPath"]];
      printVolumes([volumes sortedArrayUsingFunction:sort context:NULL]);
    }

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
