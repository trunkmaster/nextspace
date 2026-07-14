#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSBundle.h>
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testecho;
  NSString *testcat;
  NSArray *args;
  id task;
  id info;
  id env;
  id pth1;
  id pth2;
  BOOL yes;

  /* Windows Compiler add the '.exe' suffix to executables
   */
#if defined(_WIN32)
  testecho = @"testecho.exe";
  testcat = @"testcat.exe";
#else
  testecho = @"testecho";
  testcat = @"testcat";
#endif
  
  info = [NSProcessInfo processInfo];
  env = [info environment];
  yes = YES;
  
  PASS(info != nil && [info isKindOfClass: [NSProcessInfo class]]
       && env != nil && [env isKindOfClass: [NSDictionary class]]
       && yes == YES,
       "We can build some objects for task tests");

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  pth1 = [helpers stringByAppendingPathComponent: testcat];
  pth2 = [helpers stringByAppendingPathComponent: testecho];

  /* Try some tasks.  Make sure the program we use is common between Unix
     and Windows (and others?) */
  task = [NSTask launchedTaskWithLaunchPath: pth1
		 arguments: [NSArray array]];
  [task waitUntilExit];
  PASS(YES, "launchedTaskWithLaunchPath:arguments: works")

  task = [NSTask new];
  args = [NSArray arrayWithObjects: @"xxx", @"yyy", nil];
  [task setEnvironment: env];
  [task setLaunchPath: pth2];
  [task setArguments: args];
  [task launch];
  [task waitUntilExit];
  PASS([task terminationReason] == NSTaskTerminationReasonExit,
    "termination reason for normal exit works")
  DESTROY(task);
  
  [arp release]; arp = nil;
  return 0;
}
