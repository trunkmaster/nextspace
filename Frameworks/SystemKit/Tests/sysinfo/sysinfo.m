//
//
//

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <SystemKit/OSESystemInfo.h>

int main(int argc, char *argv[])
{
  @autoreleasepool {
    NSLog(@"\nRunning on system:\n"
          @"\tOS Release: \t%@\n"
          @"\tName: \t\t%@\n"
          @"\tRelease: \t%@\n"
          @"\tMachine type: \t%@\n"
          @"\tHostname: \t%@\n"
          @"\tDomain: \t%@",
          [OSESystemInfo operatingSystemRelease],
          [OSESystemInfo operatingSystem],
          [OSESystemInfo operatingSystemVersion],
          [OSESystemInfo machineType],
          [OSESystemInfo hostName],
          [OSESystemInfo domainName]);
  }

  return 0;
}
