/* 
   Copied from NSWorkspace.h

   Interface to Workspace Manager application.
   Workspace Manager application can by set by command

   > defaults write NSGlobalDomain GSWorkspaceApplication <name of app>

   Copyright (C) 1996-2002 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

/* Methods that are used inside Workspace:
   - openFile:
   - iconForFile:
   - getInfoForFile:
   - openIconForDirectory:
   Other areas of interest:
   - Notification center.
   - File operations.
   - Media management.
 */

/* Methods called by NSWorkspace:
   - openFile: withApplication: andDeactivate:
     - openFile:
     - openFile: fromImage: at: inView:
     - openFile: withApplication:
   - openTempFile:

   - performFileOperation: source: destination:

   - selectFile: inFileViewerRootedAtPath:

   - launchApplication: showIcon: autolaunch:
   - activeApplication
   - launchedApplications

   - extendPowerOffBy:
*/

//-----------------------------------------------------------------------------
// NSWorkspace
//
// Inherits From: NSObject
// Conforms To:	  NSObject (NSObject)
// Declared In:	  AppKit/NSWorkspace.h
//
// Class Description
//
// An NSWorkspace object responds to application requests to perform a
// variety of services:
// * opening, manipulating, and obtaining information about files and devices
// * tracking changes to the file system, devices, and the user database
// * launching applications
// * miscellaneous services such as animating an image and requesting 
//   additional time before power off
// An NSWorkspace object is made available through the sharedWorkspace
// method. For example, the following statement uses an NSWorkspace object to
// request that a file be opened in the Edit application:
//
// [[NSWorkspace sharedWorkspace] openFile:"/Myfiles/README"                
//                         withApplication:"Edit"];
//-----------------------------------------------------------------------------

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>
#import <AppKit/AppKitDefines.h>

#import "Controller.h"

@class NSString;
@class NSNumber;
@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSNotificationCenter;
@class NSImage;
@class NSView;


@interface Controller (NSWorkspace)

//-----------------------------------------------------------------------------
//--- Creating a NSWorkspace
//-----------------------------------------------------------------------------

/* Read configuration files from ~/Library/Services directory */
- (void)initPrefs;
  
/* Initialize private implementation of NSWorkspace */
- (id)initNSWorkspace;

//-----------------------------------------------------------------------------
//--- Opening Files
//-----------------------------------------------------------------------------

/** Instructs Workspace Manager to open the file specified by fullPath using
    the default application for its type; returns YES if file was successfully
    opened and NO otherwise.
    In current implementation calls openFile:withApplication:*/
// --- [NSWorkspace _workspaceApplication]
- (BOOL)openFile:(NSString *)fullPath;

/** Instructs Workspace Manager to open the file specified by fullPath using
    the default application for its type. To provide animation prior to the
    open, anImage should contain the file's icon, and its image should be
    displayed at point, using aView's coordinates. Returns YES if file was
    successfully opened and NO otherwise.*/
- (BOOL)openFile:(NSString *)fullPath
       fromImage:(NSImage *)anImage
              at:(NSPoint)point
          inView:(NSView *)aView;

/** Instructs Workspace Manager to open the file specified by fullPath using
    the appName application; returns YES if file was successfully opened and NO
    otherwise.*/
// --- [NSWorkspace _workspaceApplication]
- (BOOL)openFile:(NSString *)fullPath withApplication:(NSString *)appName;

/** Instructs Workspace Manager to open the file specified by fullPath using
    the appName application where flag indicates if sending application should
    be deactivated before the request is sent; returns YES if file was
    successfully opened and NO otherwise.*/
// [NSWorkspace _workspaceApplication]
- (BOOL)openFile:(NSString *)fullPath withApplication:(NSString *)appName andDeactivate:(BOOL)flag;

/** Instructs Workspace Manager to open the temporary file specified by
    fullPath using the default application for its type; returns YES if file
    was successfully opened and NO otherwise.*/
// [NSWorkspace _workspaceApplication]
- (BOOL)openTempFile:(NSString*)fullPath;

//-----------------------------------------------------------------------------
//--- Manipulating Files
//-----------------------------------------------------------------------------

//--- Possible values for operation in performFileOperation:...
APPKIT_EXPORT NSString *NSWorkspaceMoveOperation;
APPKIT_EXPORT NSString *NSWorkspaceCopyOperation;
APPKIT_EXPORT NSString *NSWorkspaceLinkOperation;
APPKIT_EXPORT NSString *NSWorkspaceCompressOperation;
APPKIT_EXPORT NSString *NSWorkspaceDecompressOperation;
APPKIT_EXPORT NSString *NSWorkspaceEncryptOperation;
APPKIT_EXPORT NSString *NSWorkspaceDecryptOperation;
APPKIT_EXPORT NSString *NSWorkspaceDestroyOperation;
APPKIT_EXPORT NSString *NSWorkspaceRecycleOperation;
APPKIT_EXPORT NSString *NSWorkspaceDuplicateOperation;

/** Requests the Workspace Manager to perform a file operation on a set of
    files in the source directory specifying the destination directory if
    needed using tag as an identifier for asynchronous operations; returns YES
    if operation succeeded and NO otherwise.*/
// TODO
// [NSWorkspace _workspaceApplication]
// - (BOOL)performFileOperation:(NSString*)operation
//                       source:(NSString*)source
//                  destination:(NSString*)destination
//                        files:(NSArray*)files
//                          tag:(int*)tag;

/** Instructs Workspace Manager to select the file specified by fullPath
    opening a new file viewer if a path is specified by rootFullpath; returns
    YES if file was successfully selected and NO otherwise.*/
// TODO
// [NSWorkspace _workspaceApplication]
// - (BOOL)       selectFile:(NSString*)fullPath
//  inFileViewerRootedAtPath:(NSString*)rootFullpath;

//-----------------------------------------------------------------------------
//--- Requesting Information about Files
//-----------------------------------------------------------------------------

/** Returns the full path for the application appName.*/
/* GNUstep:
   Given an application name, return the full path for that application.
   This method looks for the application in standard locations, and if not
   found there, according to MacOS-X documentation, returns nil.
   If the supplied application name is an absolute path, returns that path
   irrespective of whether such an application exists or not.  This is
   *not* the docmented debavior in the MacOS-X documentation, but is
   the MacOS-X implemented behavior.
   If the appName has an extension, it is used, otherwise in GNUstep
   the standard app, debug, and profile extensions are tried.*/
// CHECK
// - (NSString*)fullPathForApplication:(NSString*)appName;

// TODO (use libmagic)
/** Describes the file system at fullPath in description and fileSystemType,
    sets the Flags appropriately, and returns YES if fullPath is a file system
    mount point, or NO if it isn't.*/
/* Uses statfs call. 
   Not all systems with getmntinfo do have a statfs calls. In particular,
   NetBSD offers only a statvfs calls for compatibility with POSIX. Other BSDs
   and Linuxes have statvfs as well, but this returns less information than
   the 4.4BSD statfs call. The NetBSD statvfs, on the other hand, is just a
   statfs in disguise, i.e., it provides all information available in the
   4.4BSD statfs call. Therefore, we go ahead an just #define statfs as
   statvfs on NetBSD.  Note that the POSIX statvfs is not really helpful for
   us here. The only information that could be extracted from the data
   returned by that syscall is the ST_RDONLY flag. There is no owner field nor
   a typename.  The statvfs call on Solaris returns a structure that includes
   a non-standard f_basetype field, which provides the name of the underlying
   file system type.*/
// TODO
// - (BOOL) getFileSystemInfoForPath: (NSString*)fullPath
// 		      isRemovable: (BOOL*)removableFlag
// 		       isWritable: (BOOL*)writableFlag
// 		    isUnmountable: (BOOL*)unmountableFlag
// 		      description: (NSString**)description
// 			     type: (NSString**)fileSystemType;

//--- Return values for type in getInfoForFile:
// A plain file or a directory that some application claims to be able to open
// like a file.
APPKIT_EXPORT NSString *NSPlainFileType;
// An untyped directory
APPKIT_EXPORT NSString *NSDirectoryFileType;
// A GNUstep application
APPKIT_EXPORT NSString *NSApplicationFileType;
// A file system mount point
APPKIT_EXPORT NSString *NSFilesystemFileType;
 // Executable shell command
APPKIT_EXPORT NSString *NSShellCommandFileType;

/** Retrieves information about the file specified by fullPath, sets appName to
    the application the Workspace Manager would use to open fullPath, sets
    type to a value or file name extension indicating the file's type, and
    returns YES upon success and NO otherwise.*/
// TODO (use libmagic)
- (BOOL)getInfoForFile:(NSString*)fullPath
           application:(NSString**)appName
                  type:(NSString**)type;

/** Returns an NSImage with the icon for the single file specified by 
    fullPath.*/
- (NSImage*)iconForFile:(NSString*)fullPath;

/** Returns an NSImage with the icon for the files specified in pathArray, an
    array of NSStrings. If pathArray specifies one file, its icon is returned.
    If pathArray specifies more than one file, an icon representing the
    multiple selection is returned.*/
- (NSImage*)iconForFiles:(NSArray*)pathArray;

/** Returns an NSImage the icon for the file type specified by fileType.*/
- (NSImage*)iconForFileType:(NSString*)fileType;

// ADDON
/** Returns an icon of directory in opened state.*/
- (NSImage *)openIconForDirectory:(NSString *)fullPath;

//-----------------------------------------------------------------------------
//--- Tracking Changes to the File System
//-----------------------------------------------------------------------------

/** Returns whether a change to the file system has been registered with a
    noteFileSystemChanged message since the last fileSystemChanged message.*/
// CHECK
// - (BOOL)fileSystemChanged;

/** Informs Workspace Manager that the file system has changed.*/
// CHECK
// - (void)noteFileSystemChanged;

//-----------------------------------------------------------------------------
//--- Updating Registered Services and File Types
//-----------------------------------------------------------------------------

/** Instructs Workspace Manager to examine all applications in the normal
    places and update its records of registered services and file types.
    Updates Registered Services, File Types, and other information about any
    applications installed in the standard locations.*/
// CHECK
- (void)findApplications;


//-----------------------------------------------------------------------------
//--- Launching and Manipulating Applications
//-----------------------------------------------------------------------------

/** Hides all applications other than the sender.
    GNUstep:
    Instructs all the other running applications to hide themselves.
    <em>not yet implemented</em>*/
// TODO
// - (void)hideOtherApplications;

/** Instructs Workspace Manager to launch the application appName and returns
    YES if application was successfully launched and NO otherwise.*/
// TODO
// --- [NSWorkspace _workspaceApplication]
- (BOOL)launchApplication:(NSString *)appName;

/** Instructs Workspace Manager to launch the application appName displaying
    the application's icon if showIcon is YES and using the dock autolaunching
    defaults if autolaunch is YES; returns YES if application was successfully
    launched and NO otherwise.*/
/*
 * <p>Launches the specified application (unless it is already running).<br />
 * If the autolaunch flag is yes, sets the autolaunch user default for the
 * newly launched application, so that applications which understand the
 * concept of being autolaunched at system startup time can modify their
 * behavior appropriately.
 * </p>
 * <p>Sends an NSWorkspaceWillLaunchApplicationNotification before it
 * actually attempts to launch the application (this is not sent if the
 * application is already running).
 * </p>
 * <p>The application sends an NSWorkspaceDidlLaunchApplicationNotification
 * on completion of launching.  This is not sent if the application is already
 * running, or if it fails to complete its startup.
 * </p>
 * <p>Returns NO if the application cannot be launched (eg. it does not exist
 * or the binary is not executable).
 * </p>
 * <p>Returns YES if the application was already running or of it was launched
 * (this does not necessarily mean that the application succeeded in starting
 * up fully).
 * </p>
 * <p>Once an application has fully started up, you should be able to connect
 * to it using [NSConnection+rootProxyForConnectionWithRegisteredName:host:]
 * passing the application name (normally the filesystem name excluding path
 * and file extension) and an empty host name.  This will let you communicate
 * with the the [NSApplication-delegate] of the launched application, and you
 * can generally use this as a test of whether an application is running
 * correctly.
 * </p>
 */
// CHECK
// [NSWorkspace _workspaceApplication]
- (BOOL)launchApplication:(NSString *)appName
                 showIcon:(BOOL)showIcon
               autolaunch:(BOOL)autolaunch;


//-----------------------------------------------------------------------------
//--- Unmounting a Device
//-----------------------------------------------------------------------------

/** Unmounts and ejects the device at path and returns YES if unmount 
    succeeded and NO otherwise.*/
- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path;

//-----------------------------------------------------------------------------
//--- Tracking Status Changes for Devices
//-----------------------------------------------------------------------------

/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted. Asks the Workspace Manager to
    mount the disk asynchronously and returns immediately.*/
- (void)checkForRemovableMedia;

/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted, waits until the new disks
    have been mounted, and returns a list of full pathnames to all newly
    mounted disks.*/
- (NSArray *)mountNewRemovableMedia;

/** Returns a list of the pathnames of all currently mounted removable disks.*/
// TODO
- (NSArray *)mountedRemovableMedia;

//-----------------------------------------------------------------------------
// Notification Center
//-----------------------------------------------------------------------------

/** Returns the notification center for WorkSpace notifications.*/
- (NSNotificationCenter *)notificationCenter;


//-----------------------------------------------------------------------------
// Tracking Changes to the User Defaults Database
//-----------------------------------------------------------------------------

/** Informs Workspace Manager that the defaults database has changed.*/
// TODO
- (void)noteUserDefaultsChanged;

/** Returns whether a change to the defaults database has been registered with
    a noteUserDefaultsChanged message since the last userDefaultsChanged
    message.*/
// TODO
- (BOOL)userDefaultsChanged;


//-----------------------------------------------------------------------------
// Animating an Image
//-----------------------------------------------------------------------------

/** Instructs Workspace Manager to animate a sliding image of image from
    fromPoint to toPoint, specified in screen coordinates.*/
- (void)slideImage:(NSImage *)image
              from:(NSPoint)fromPoint
                to:(NSPoint)toPoint;

//-----------------------------------------------------------------------------
// Requesting Additional Time before Power Off or Logout
//-----------------------------------------------------------------------------

/** Requests more time before the power goes off or the user logs out; returns
    the granted number of additional milliseconds.*/
// TODO
// [NSWorkspace _workspaceApplication]
// - (int)extendPowerOffBy:(int)requested;

@end

//-----------------------------------------------------------------------------
// Notifications (sent through the special notification center).
//
// userInfo keys (depends on type of notification):
// @"NSApplicationName"
//   The name of the launched application (string).
// @NSApplicationPath"
//   The full path to the launched application (string).
// @"NSApplicationProcessIdentifier"
//   The process identifier (pid) of the launched application.
// @"NSDevicePath"
//   The full path to operated device (string).
// @"NSOperationNumber"
//   The tag of file operation in Workspace Manager (string).
//-----------------------------------------------------------------------------
APPKIT_EXPORT NSString *NSWorkspaceWillLaunchApplicationNotification;   // @"NSApplicationName"
APPKIT_EXPORT NSString *NSWorkspaceDidLaunchApplicationNotification;    // @"NSApplicationName"
APPKIT_EXPORT NSString *NSWorkspaceDidTerminateApplicationNotification; // @"NSApplicationName"
APPKIT_EXPORT NSString *NSWorkspaceDidMountNotification;                // @"NSDevicePath"
APPKIT_EXPORT NSString *NSWorkspaceDidPerformFileOperationNotification; // @"NSOperationNumber"
APPKIT_EXPORT NSString *NSWorkspaceDidUnmountNotification;              // @"NSDevicePath"
APPKIT_EXPORT NSString *NSWorkspaceWillPowerOffNotification;
APPKIT_EXPORT NSString *NSWorkspaceWillUnmountNotification;             // @"NSDevicePath"
