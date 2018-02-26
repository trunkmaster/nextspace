//
//
//

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>
#import <NXSystem/NXPower.h>
/*
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
*/

void listDisplays(NSArray *displays)
{
  NSDictionary	*resolution;
  NSSize	size;
  NSPoint	position;
  
  fprintf(stderr, " Name \tConnected\t Lid   \tActive \t Main  \t DPI \tResolution\tPosition\n");
  fprintf(stderr, "------\t---------\t-------\t-------\t-------\t-----\t----------\t--------\n");
  for (NXDisplay *d in displays)
    {
      resolution = [d resolution];
      size = NSSizeFromString([resolution objectForKey:@"Size"]);
      position = [d position];
      fprintf(stderr, "%s\t  %s\t\t%s\t  %s\t%s\t%.0f\t%4.0fx%4.0f\t%.0f,%.0f\n",
              [[d outputName] cString],
              ([d isConnected]) ? "Yes" : "No",
              ([d isBuiltin] && [NXPower isLidClosed]) ? "Closed" : "Opened",
              ([d isActive]) ? "Yes" : "No",
              ([d isMain]) ? "Yes" : "No",
              [d dpi],
              size.width, size.height,
              position.x, position.y);
    }
}

void displayDetails(NXDisplay *display)
{
  NSSize  size;
  NSPoint point;
  
  // NSLog(@"Display details for: %@", [display outputName]);
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  fprintf(stderr, "Output name\t\t: \e[7m%s\e[27m\n", [[display outputName] cString]);
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  fprintf(stderr, "Connected\t\t: %s\n", [display isConnected] ? "Yes" : "No");
  fprintf(stderr, "Active\t\t\t: %s\n", [display isActive] ? "Yes" : "No");
  fprintf(stderr, "Main\t\t\t: %s\n", [display isMain] ? "Yes" : "No");
  fprintf(stderr, "Builtin\t\t\t: %s\n", [display isBuiltin] ? "Yes" : "No");
  size = [display physicalSize];
  fprintf(stderr, "Physical size (mm)\t: %.0f x %.0f\n", size.width, size.height);
  fprintf(stderr, "Dot per inch\t\t: %.0f\n", [display dpi]);
  size = NSSizeFromString([[display resolution] objectForKey:@"Size"]);
  fprintf(stderr, "Resolution\t\t: %.0f x %.0f\n", size.width, size.height);
  point = [display position];
  fprintf(stderr, "Position on screen\t: %.0f, %.0f\n", point.x, point.y);
  fprintf(stderr, "Frame\t\t\t: %s\n", [NSStringFromRect([display frame]) cString]);
  fprintf(stderr, "Hidden frame\t\t: %s\n", [NSStringFromRect([display hiddenFrame]) cString]);
  fprintf(stderr, "Gamma correction\t: %.2f\n", [display gamma]);
}

int main(int argc, char *argv[])
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NXScreen		*screen = [NXScreen sharedScreen];

  for (int i=1; i < argc; i++)
    {
      if (argv[i][0] == '-')
        {
          if (strcmp(argv[i], "-listAll") == 0)
            {
              fprintf(stderr, "\n------------------------\n");
              fprintf(stderr, " All registered displays\n");
              fprintf(stderr, "---------------------------------------------------------------------------------\n");
              listDisplays([screen allDisplays]);
            }
          else if (strcmp(argv[i], "-listActive") == 0)
            {
              fprintf(stderr, "\n----------------\n");
              fprintf(stderr, " Active displays\n");
              fprintf(stderr, "---------------------------------------------------------------------------------\n");
              listDisplays([screen activeDisplays]);
            }
          else if (strcmp(argv[i], "-details") == 0)
            {
              displayDetails([screen displayWithName:[NSString stringWithCString:argv[++i]]]);
            }
          else
            fprintf(stderr, "Unknown parameter specified: %s\n", argv[i]);
        }
      else
        {
          fprintf(stderr, "No parameters specified.\n");
        }
    }

  [pool release];

  return 0;
}
