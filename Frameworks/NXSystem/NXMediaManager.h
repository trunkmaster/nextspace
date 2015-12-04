/*
 * This class is aimed to provide:
 * - access to OS-dependent adaptor via MediaManager protocol;
 * - definition of notifications sent by adaptor;
 * - definition of base types inside MediaManager network of classes.
 */

#import <Foundation/Foundation.h>

// Events
extern NSString *NXDiskAppeared;
extern NSString *NXDiskDisappeared;
extern NSString *NXVolumeAppeared;
extern NSString *NXVolumeDisappeared;
extern NSString *NXVolumeMounted;
extern NSString *NXVolumeUnmounted;

extern NSString *NXMediaOperationDidStart;
extern NSString *NXMediaOperationDidUpdate;
extern NSString *NXMediaOperationDidEnd;

// Filesystem types
typedef enum
{
  NXFSTypeNTFS = 0,
  NXFSTypeFAT  = 1,
  NXFSTypeUDF  = 2,
  NXFSTypeUFS  = 3,
  NXFSTypeISO  = 4,
  NXFSTypeSwap = 5
} NXFSType;

// Class which adopts <MediaManager> protocol aimed to implement
// interaction with OS's method of getting information about disks, volumes,
// partitions and its events (add, remove, mount, unmount, eject).
@protocol MediaManager <NSObject>

/** Returns a list of the pathnames of currently mounted removable and fixed 
    disks.*/
- (NSArray *)mountedVolumes;

/** Returns name of filesystem type mounted at subpath of 'path'.*/
- (NXFSType)filesystemTypeAtPath:(NSString *)path;
- (NSString *)mountPointForPath:(NSString *)path;

// Disks -> Unmount.
// Async - OK.
- (void)unmountRemovableVolumeAtPath:(NSString *)path;

//--- NSWorkspace methods
  
/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted. Asks the Workspace Manager to
    mount the disk asynchronously and returns immediately.
    'Workspace -> Disk -> Check For Disks'*/
- (void)checkForRemovableMedia;

/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted, waits until the new disks
    have been mounted, and returns a list of full pathnames to all newly
    mounted disks.*/
// Sync - OK.
- (NSArray *)mountNewRemovableMedia;

/** Returns a list of the pathnames of all currently mounted removable disks.*/
- (NSArray *)mountedRemovableMedia;

/** Unmounts and ejects the device at path and returns YES if unmount 
    succeeded and NO otherwise.
    'Disk -> Eject' */
// Async - OK.
- (void)unmountAndEjectDeviceAtPath:(NSString *)path;

// Async - OK.
- (void)ejectAllRemovables;

- (BOOL)mountImageMediaFileAtPath:(NSString *)imageFile;

@end

// Initiates and hold 'adaptor' object instance.
@interface NXMediaManager : NSObject
{
}

+ (id<MediaManager>)defaultManager;
  
// Returned object must not be released directrly.
// It will be released by releasing NXMediaManager object.
- (id<MediaManager>)adaptor;

@end
