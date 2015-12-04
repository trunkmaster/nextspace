//
// Monitor file system events (delete, create, rename, change attributes)
//

#import <Foundation/Foundation.h>

extern NSString *NXFileSystemChangedAtPath;

@class NXFileSystemMonitorThread;

@interface NXFileSystemMonitor : NSObject
{
  // Event monitor vars
  NXFileSystemMonitorThread *monitorThread; // event monitor OS-specific worker
  NSTimer                   *checkTimer;

  // Monitor thread state
  BOOL monitorThreadShouldStart;
  BOOL monitorThreadPaused;
  BOOL monitorThreadStopped;
  BOOL monitorThreadTerminated;
}

// --- Monitor creation
+ (NXFileSystemMonitor *)sharedMonitor;

- (NXFileSystemMonitorThread *)monitorThread;
// callback on thread creation
- (oneway void)_setEventMonitor:(NXFileSystemMonitorThread *)aMonitor;

// --- Properties
// returns file descriptor
- (void)addPath:(NSString *)absolutePath;
- (void)removePath:(NSString *)absolutePath;

// --- Monitor managing
- (void)start;
- (void)stop;
- (void)pause;
- (void)resume;
- (void)terminate;
- (void)handleEvent:(NSDictionary *)event;

@end

@interface NXFileSystemMonitorThread : NSObject
{
  NSMutableDictionary *threadDict;
  NXFileSystemMonitor *monitorOwner;  // event monitor initiator
}

// --- General part of thread
+ (void)connectWithPorts:(NSArray *)portArray;

// --- OS-specific
- (id)initWithConnection:(NSConnection *)conn;
- (void)_addPath:(NSString *)absolutePath;
- (void)_removePath:(NSString *)absolutePath;

- (oneway void)_startThread;
- (oneway void)_stopThread;
- (oneway void)_terminateThread;

- (void)checkForEvents;

@end

