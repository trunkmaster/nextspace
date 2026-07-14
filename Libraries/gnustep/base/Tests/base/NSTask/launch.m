#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSError.h>
#import <Foundation/FoundationErrors.h>

#import "ObjectTesting.h" 

#if !defined(_WIN32)
#include <unistd.h>
#endif

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSError *error;
  NSTask *task;
  NSPipe *outPipe;
  NSFileManager *mgr;
  NSString      *helpers;
  NSString *testecho;
  NSString *testcat;
  NSString *processgroup;
  NSFileHandle  *outHandle;
  NSData *data = nil;

#if defined(_WIN32)
  testecho = @"testecho.exe";
  testcat = @"testcat.exe";
  processgroup = @"processgroup.exe";
#else
  testecho = @"testecho";
  testcat = @"testcat";
  processgroup = @"processgroup";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testcat]];
  [task setArguments: [NSArray arrayWithObjects: nil]];
  [task setStandardOutput: outPipe]; 
  outHandle = [outPipe fileHandleForReading];

  [task launch];
  PASS([task standardOutput] == outPipe, "standardOutput returns pipe");
  data = [outHandle readDataToEndOfFile];
  PASS([data length] > 0, "was able to read data from subtask");
  NSLog(@"Data was %*.*s",
    (int)[data length], (int)[data length], (const char*)[data bytes]);
  [task terminate];
  DESTROY(task);

  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testecho]];
  [task setArguments: [NSArray arrayWithObjects: @"Hello", @"there", nil]];
  [task setStandardOutput: outPipe]; 
  outHandle = [outPipe fileHandleForReading];

  [task launch];
  data = [outHandle readDataToEndOfFile];
  PASS([data length] > 0, "was able to read data from subtask");
  NSLog(@"Data was %*.*s",
    (int)[data length], (int)[data length], (const char*)[data bytes]);
  [task terminate];


  PASS_EXCEPTION([task launch];, @"NSInvalidArgumentException",
    "raised exception on failed launch") 
  DESTROY(task);

  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testcat]];
  [task setArguments: [NSArray arrayWithObjects: nil]];
  [task setCurrentDirectoryPath: @"not-a-directory"]; 
  PASS([task launchAndReturnError: &error] == NO, "bad directory fails launch")
  PASS(error != nil, "error is returned")
  PASS([error domain] == NSCocoaErrorDomain, "error has expected domain")
  PASS([error code] == NSFileNoSuchFileError, "error has expected code")
  DESTROY(task);
 
#if	!defined(_WIN32)
  task = [[NSTask alloc] init];
  [task setLaunchPath:
    [helpers stringByAppendingPathComponent: processgroup]];
  [task setArguments: [NSArray arrayWithObjects:
    [NSString stringWithFormat: @"%d", getpgrp()],
    nil]];
  [task launch];
  [task waitUntilExit];
  PASS([task terminationStatus] == 0, "subtask changes process group");
  DESTROY(task);
#endif

  [arp release];

  return 0;
}
