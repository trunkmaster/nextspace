// Process of creating monitor process:
// NXFileSystem             NXFileSystemMonitor
// (owner)                  (thread)
// ----------------------------------------------
// sharedEventMonitor
// createEventMonitorThread -----> connectWithPorts:
//                                 initWithConnection:
// setEventMonitor: <------------- initWithConnection:
// addEventMonitorPath
//
// Process of deleting of monitor process:
//                          stopEventMonitor
//                          invalidateEventMonitor
//
// (EventMonitorOwner) category methods is primary way to manipulate
// process of monitoring file system events (front class for applications).

#import <Foundation/NSFileManager.h>
#import "NXFileSystemMonitor.h"

static NXFileSystemMonitor *_fileSystemMonitor = nil;
static NSConnection        *mainConnection;

NSString *NXFileSystemChangedAtPath = @"NXFileSystemChangedAtPath";

@implementation NXFileSystemMonitor

+ (NXFileSystemMonitor *)sharedMonitor
{
  if (_fileSystemMonitor == nil)
    {
      _fileSystemMonitor = [[NXFileSystemMonitor alloc] init];
      NSLog(@"[NXFSM]_fileSystemMonitor RC: %lu",
            [_fileSystemMonitor retainCount]);
    }

  return _fileSystemMonitor;
}

- (id)init
{
  NSPort  *port1;
  NSPort  *port2;
  NSArray *portArray = nil;

  self = [super init];

  port1 = [NSPort new];
  port2 = [NSPort new];
  // Create connection to OS specific monitor server
  mainConnection = [[NSConnection alloc] initWithReceivePort:port1
						    sendPort:port2];
  [mainConnection setRootObject:self];
  // [mainConnection autorelease];

  // Ports switched here.
  portArray = [NSArray arrayWithObjects:port2, port1, nil];

  monitorThreadTerminated = NO;
  monitorThreadStopped = YES;
  monitorThreadPaused = NO;
  monitorThreadShouldStart = NO;
 
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: detaching file system monitor thread...");
  [NSThread detachNewThreadSelector:@selector(connectWithPorts:)
			   toTarget:[NXFileSystemMonitorThread class]
			 withObject:portArray];
  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"NXFileSystemMonitor", @"NXFileSystemMonitor: dealloc");
 
  [super dealloc];
}

// Callback method for created worker thread
- (oneway void)_setEventMonitor:(NXFileSystemMonitorThread *)aThread
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: setEventMonitor: %@", aThread);

  monitorThread = [aThread retain];

  // Start monitor thread if 'start' message was received before thread creation
  if (monitorThreadShouldStart)
    {
      [self start];
    }
}

- (NXFileSystemMonitorThread *)monitorThread
{
  return monitorThread;
}

// Adds all components of 'absolutePath' to event monitor starting from '/'
- (void)addPath:(NSString *)absolutePath
{
  NSArray    *pathComponents = [absolutePath pathComponents];
  NSUInteger count = [pathComponents count];
  NSUInteger i;
  NSString   *path = @"";

  if (monitorThreadTerminated == YES)
    return;
  
  [self pause];

  for (i=0; i<count; i++)
    {
      path = [path
               stringByAppendingPathComponent:[pathComponents objectAtIndex:i]];
      if ([[NSFileManager defaultManager] isReadableFileAtPath:path])
        {
          [monitorThread _addPath:path];
        }
    }
  
  [self resume];
}

- (void)removePath:(NSString *)absolutePath
{
  NSArray    *pathComponents = [absolutePath pathComponents];
  NSUInteger count = [pathComponents count];
  NSUInteger i;
  NSString   *path = @"";

  if (monitorThreadTerminated == YES)
    return;

  [self pause];
  
  for (i=0; i<count; i++)
    {
      path = [path
               stringByAppendingPathComponent:[pathComponents objectAtIndex:i]];
      [monitorThread _removePath:path];
    }
  
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: path %@ removed", absolutePath);
  [self resume];
}

// --- Managing monitor
// Monitor can exist in the following states:
// 1. Paused == NO, Stopped == NO:  'start' was called
// 2. Paused == YES, Stopped == NO: 'pause' was called
// 3. Paused == NO, Stopped == YES: 'stop' was called
// Paused == YES, Stopped == YES should never be reached, it's illegal state.
// So, correct call sequences are:
// start-stop
// start-pause-resume-stop
// start-pause-stop
- (void)start
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: start (S:%i P:%i)",
              monitorThreadStopped, monitorThreadPaused);
  
  if (monitorThread)
    {
      // If monitor thread was paused 'resume' methods must be called
      if (monitorThreadPaused == NO && monitorThreadTerminated == NO)
        {
          [monitorThread _startThread];
          monitorThreadStopped = NO;
        }
    }
  else // thread has not created yet
    {
      monitorThreadShouldStart = YES;
    }
}

- (void)stop
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: stop (S:%i P:%i)",
              monitorThreadStopped, monitorThreadPaused);
  
  if (monitorThreadStopped == NO)
    {
      [monitorThread _stopThread];
      monitorThreadStopped = YES;
      monitorThreadPaused = NO;
    }
}

- (void)pause
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: pause (S:%i P:%i)",
              monitorThreadStopped, monitorThreadPaused);
  if (monitorThreadStopped == NO && monitorThreadPaused == NO)
    {
      [monitorThread _stopThread];
      monitorThreadPaused = YES;
    }
}

- (void)resume
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: resume (S:%i P:%i)",
              monitorThreadStopped, monitorThreadPaused);
  if (monitorThreadPaused == YES)
    {
      [monitorThread _startThread];
      monitorThreadPaused = NO;
    }
}

- (void)terminate
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: terminate (S:%i P:%i)",
              monitorThreadStopped, monitorThreadPaused);
  
  [monitorThread _terminateThread];
  
  monitorThreadStopped = NO;
  monitorThreadTerminated = YES;

  // Release connection to self
  [mainConnection setRootObject:nil];
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor RC: %lu", [self retainCount]);
  
  NSDebugLLog(@"NXFileSystemMonitor",
              @"monitorThread RC: %lu", [monitorThread retainCount]);
  [monitorThread release];
}

// It's called from NFileSystemMonitor thread and should be fast.
// Otherwise NSRunLoop blocked until all events will be handled.
- (void)handleEvent:(NSDictionary *)event
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitor: FS events %@ occured at path %@",
              [event objectForKey:@"Operations"],
              [event objectForKey:@"ChangedPath"]);
      
  [[NSNotificationCenter defaultCenter] 
        postNotificationName:@"NXFileSystemChangedAtPath"
                      object:self
                    userInfo:event];
}

@end

@implementation NXFileSystemMonitorThread

+ (void)connectWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];

  NXFileSystemMonitorThread *threadObject;
  NSConnection              *ownerConnection;
  NSRunLoop                 *runLoop;
  NSMutableDictionary       *threadDict;
  BOOL                      exitNow = NO;
  
  // Create connection to EventMonitor owner (client)
  ownerConnection = [NSConnection
                      connectionWithReceivePort:[portArray objectAtIndex:0]
                                       sendPort:[portArray objectAtIndex:1]];

  // Create ourself as 'threadObject'
  threadObject = [[NXFileSystemMonitorThread alloc] initWithConnection:ownerConnection];

  // Send created instance to owner via setEventMonitor owner's method
  [(NXFileSystemMonitor *)[ownerConnection rootProxy] _setEventMonitor:threadObject];
  [threadObject release];

  NSDebugLLog(@"NXFileSystemMonitor", @"%@: waiting for messages", self);

  // ---- Main loop ----
  runLoop = [NSRunLoop currentRunLoop];
  threadDict = [[NSThread currentThread] threadDictionary];
  while (!exitNow)
    {
      // Process AppKit and Foundation events
      [runLoop runMode:NSDefaultRunLoopMode 
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

      // Process kernel events
      if ([[threadDict valueForKey:@"ThreadShouldCheckForEvents"] boolValue])
	{
          [threadObject checkForEvents];
	}

      // Check to see if an input source handler changed the exitNow value.
      exitNow = [[threadDict valueForKey:@"ThreadShouldExitNow"] boolValue];
    }

  NSDebugLLog(@"NXFileSystemMonitor", @"NXFileSystemMonitorThread: thread exiting...");

  [pool release];
}

// --- OS-specific code --- Must be overriden ---
- (id)initWithConnection:(NSConnection *)conn
{
  NSDictionary *stst = [conn statistics];

  self = [super init];

  // Made OS-sepecific to allow initialization of OS-specific subsystem
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: initWithConnection: "
              "No OS-specific code found!");

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"NXFileSystemMonitor", @"NXFileSystemMonitor: dealloc");
  [super dealloc];
}

- (void)_addPath:(NSString *)absolutePath
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: addEventMonitorPath:%@: "
              "No OS-specific code found!", absolutePath);
  // OS specific part
}

- (void)_removePath:(NSString *)absolutePath
{
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: removeEventMonitorPath:%@ " 
              "No OS-specific code found!", absolutePath);
  // OS specific part
}

- (oneway void)_startThread
{
  // OS specific part
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: startEventMonitorThread: "
              "No OS-specific code found!");
}

- (oneway void)_stopThread
{
  // OS specific part
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: stopEventMonitorThread: "
              "No OS-specific code found!");
}

- (oneway void)_terminateThread
{
  // OS specific part
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: invalidateEventMonitorThread: "
              "No OS-specific code found!");
}

// Overriden method must call handleEvents:atPath: if events available
- (void)checkForEvents
{
  // OS specific part
  NSDebugLLog(@"NXFileSystemMonitor",
              @"NXFileSystemMonitorThread: checkForEvents: "
              "No OS-specific code found!");
}

@end
