//
//
//

#include <stdio.h>
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <SoundKit/SKSoundServer.h>
#import <SoundKit/SKSoundOut.h>

@interface SoundKitClient : NSObject
{
  SKSoundServer *server;
  BOOL          isRunning;
}
@end

@implementation SoundKitClient

- (void)dealloc
{
  NSLog(@"SoundKitClient: dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  [server release];
  [super dealloc];
}

- init
{
  self = [super init];

  // 1. Connect to PulseAudio on locahost
  server = [SKSoundServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SKServerStateDidChangeNotification
         object:server];
  
  return self;
}

- (void)runLoopRun
{
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  
  isRunning = YES;
  while (isRunning) {
    // NSLog(@"RunLoop is running");
    [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }
}

- (void)runLoopStop
{
  isRunning = NO;
}

- (void)describeSoundSystem
{
  // Server
  fprintf(stderr, "=== Sound Server ===\n");
  fprintf(stderr, "\t        Name: %s\n", [server.name cString]);
  fprintf(stderr, "\t     Version: %s\n", [server.version cString]);
  fprintf(stderr, "\t    Username: %s\n", [server.userName cString]);
  fprintf(stderr, "\t    Hostname: %s\n", [server.hostName cString]);
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  
  // // Sound Out
  // fprintf(stderr, "=== SoundOut ===\n");
  // for (SKSoundOut *sout in server.outputList) {
  //   [sout printDescription];
  // }
}

- (SKSoundOut *)defaultSoundOut
{
  SKSoundOut *sOut;
  // SKSoundStream *sStream;
  // sStream = [[SKSoundStream alloc] initWithDevice:sOut];

  for (SKSoundOut *sout in [server outputList]) {
    [sout printDescription];
  }

  sOut = [server defaultOutput];
  fprintf(stderr, "========= Default SoundOut =========\n");
  [sOut printDescription];

  return sOut;
}

- (void)serverStateChanged:(NSNotification *)notif
{
  if (server.status == SKServerReadyState) {
    [self describeSoundSystem];
    [self defaultSoundOut];
  }
}

@end

static SoundKitClient *client;

static void handle_signal(int sig)
{
  // fprintf(stderr, "got signal %i\n", sig);
  [client runLoopStop];
}

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSConnection      *conn;

  client = [SoundKitClient new];
  conn = [NSConnection defaultConnection];
  [conn registerName:@"soundtool"];

  signal(SIGHUP, handle_signal);
  signal(SIGINT, handle_signal);
  signal(SIGQUIT, handle_signal);
  signal(SIGTERM, handle_signal);
  
  [client runLoopRun];

  fprintf(stderr, "Runloop exited.\n");

  [conn invalidate];
  [client release];
  [pool release];

  return 0;
}
