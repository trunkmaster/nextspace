#import "ObjectTesting.h"
#import <Foundation/NSThread.h>

#if defined(_WIN32) && (NTDDI_VERSION >= NTDDI_WIN10_RS1)
#include <processthreadsapi.h>
#else
#include <pthread.h>
#endif


int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
// SetThreadDescription() was added in Windows 10 1607 (Redstone 1)
#if defined(_WIN32) && (NTDDI_VERSION >= NTDDI_WIN10_RS1)
    PWSTR nativeThreadName = NULL;
    HANDLE current = GetCurrentThread();
    HRESULT hr = SetThreadDescription(current, L"Test");
    PASS(SUCCEEDED(hr), "SetThreadDescription was successful");

    NSThread *thread = [[NSThread alloc] init];
    NSString *name = [thread name];
    PASS(name != nil, "-[NSThread name] returns a valid string");
    NSLog(@"Name: %@", name);
    PASS([name isEqualToString: @"Test"], "Thread name is correct");
    [thread release];

    [[NSThread currentThread] setName: @"Test2"];
    name = [[NSThread currentThread] name];
    PASS(name != nil, "-[NSThread name] returns a valid string");
    PASS([name isEqualToString: @"Test2"], "-[NSThread name] returns a valid string after setName");

    
    hr = GetThreadDescription(current, &nativeThreadName);
    PASS(SUCCEEDED(hr), "SetThreadDescription was successful");

    name = [NSString stringWithCharacters: (void *)nativeThreadName length: wcslen(nativeThreadName)];
    PASS([name isEqualToString: @"Test2"], "-[NSThread setName] successfully updated thread name");
    LocalFree(nativeThreadName);
#else
#endif

  return 0;
}
