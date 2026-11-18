#import <AppKit/AppKit.h>
#import <X11/Xlib.h>
#include <signal.h>
#import "BatteryView.h"
#import "BatteryStatus.h"

@interface BatteryController : NSObject
{
  BatteryView *view;
  NSTimer *timer;
  NSTask *task;
  NSPipe *output;
  NSDate *started;
  NSDate *nextUpdate;
  BOOL timedOut;
}
- (void)refresh:(id)sender;
- (void)tick:(NSTimer *)sender;
- (void)taskFinished:(NSNotification *)notification;
@end

@implementation BatteryController
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  view = [[BatteryView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
  [view setUnavailable];
  [[NSApp iconWindow] setContentView:view];
  /* Like NXTClockView: a run-loop timer, with no waitUntilExit or shell. */
  timer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self
    selector:@selector(tick:) userInfo:nil repeats:YES] retain];
  [self refresh:nil];
}

- (void)tick:(NSTimer *)sender
{
  if (task != nil) {
    NSTimeInterval elapsed = -[started timeIntervalSinceNow];
    if (elapsed > 5 && !timedOut) {
      timedOut = YES;
      [view setUnavailable];
      [task terminate];
    }
    if (elapsed > 6 && [task isRunning]) kill([task processIdentifier], SIGKILL);
  } else if (nextUpdate == nil || [nextUpdate timeIntervalSinceNow] <= 0) {
    [self refresh:nil];
  }
}

- (void)refresh:(id)sender
{
  if (task != nil) return; /* Never overlap polls, including after a timeout. */
  [nextUpdate release];
  nextUpdate = [[NSDate dateWithTimeIntervalSinceNow:30] retain];
  if (![[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/sbin/apm"]) {
    [view setUnavailable];
    return;
  }
  timedOut = NO;
  task = [NSTask new];
  output = [[NSPipe pipe] retain];
  [task setLaunchPath:@"/usr/sbin/apm"];
  [task setArguments:[NSArray arrayWithObject:@"-abl"]];
  [task setStandardOutput:output];
  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskFinished:)
    name:NSTaskDidTerminateNotification object:task];
  started = [[NSDate date] retain];
  @try {
    [task launch];
  } @catch (NSException *exception) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
      name:NSTaskDidTerminateNotification object:task];
    [task release]; task = nil;
    [output release]; output = nil;
    [started release]; started = nil;
    [view setUnavailable];
  }
}

- (void)taskFinished:(NSNotification *)notification
{
  /* apm has exited and writes only three integers: reading its closed pipe
     here cannot hold the UI waiting for the child process. */
  NSInteger percent, ac, state;
  NSData *data = [[output fileHandleForReading] readDataToEndOfFile];
  NSString *text = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
  if (!timedOut && [task terminationStatus] == 0 && BatteryParseStatus(text, &percent, &ac, &state))
    [view setPercentage:percent ac:ac state:state];
  else
    [view setUnavailable];
  [[NSNotificationCenter defaultCenter] removeObserver:self
    name:NSTaskDidTerminateNotification object:task];
  [task release]; task = nil;
  [output release]; output = nil;
  [started release]; started = nil;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
  [timer invalidate];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if ([task isRunning]) [task terminate];
}

- (void)dealloc
{
  [timer invalidate]; [timer release];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [task release]; [output release]; [started release]; [nextUpdate release];
  [view release];
  [super dealloc];
}
@end

int main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  XInitThreads();
  [NSApplication sharedApplication];
  BatteryController *controller = [BatteryController new];
  [NSApp setDelegate:controller];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Battery"];
  id<NSMenuItem> refresh = [menu addItemWithTitle:@"Refresh" action:@selector(refresh:) keyEquivalent:@"r"];
  [refresh setTarget:controller];
  [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
  [NSApp setMainMenu:menu];
  [menu release];
  [NSApp run];
  [NSApp setDelegate:nil];
  [controller release];
  [pool drain];
  return 0;
}
