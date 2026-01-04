/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: File system event monitor (Linux inotify).
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#ifdef LINUX

// Supress clang message: 
// "warning: category is implementing a method which will also be implemented 
// by its primary class [-Wobjc-protocol-method-implementation]"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#import <OSEFileSystemMonitor.h>

#include <sys/inotify.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>

int in_fd = -1;

NSMutableDictionary *_pathFDList = nil;
NSLock              *monitorLock = nil;

@implementation OSEFileSystemMonitorThread (Linux)

// So all kqueue related ivars must be shared:
//   in_fd - initify descriptor
//   _pathFDList - list of file descriptors to monitor. It's a dictionary 
//                 which conatins pairs of "path = file descriptor'
- (id)initWithConnection:(NSConnection *)conn
{
  self = [super init];

  // Initialize OS-specific part
  _pathFDList = [[NSMutableDictionary alloc] init];

  // inotify
  if (in_fd < 0)
    {
      // Creates a new kernel event queue and returns a descriptor.
      if ((in_fd = inotify_init()) < 0)
	{
	  NSLog(@"OSEFileSystemMonitorThread(Linux): Could not open inotify(7)"
                " descriptor. Error: %s.\n", strerror(errno));
	}
    }

  monitorOwner = (OSEFileSystemMonitor *)[conn rootProxy];

  threadDict = [[NSThread currentThread] threadDictionary];
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldExitNow"];
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldCheckForEvents"];

  monitorLock = [[NSLock alloc] init];

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"OSEFileSystemMonitor", @"OSEFileSystemMonitorThread(Linux): dealloc");

  [monitorLock release];
  
  [super dealloc];
}

// _pathFDList:
// {
//   "/Users/me/Temporary"= {
//     Descriptor = 28;
//     LinkCount = 2;
//   }
// }
- (NSString *)_pathForDescriptor:(int)wd
{
  NSNumber *aDescriptor = [NSNumber numberWithInt:wd];
  NSArray  *pathList = [_pathFDList allKeys];

  for (NSString *path in pathList)
    {
      NSDictionary *element = [_pathFDList objectForKey:path];
      if ([[element objectForKey:@"Descriptor"] isEqualToValue:aDescriptor])
        return path;
    }

  return nil;
}

- (void)_addPath:(NSString *)absolutePath
{
  NSString     *pathString;
  char         *path;
  int          path_fd = -1;
  int          i, count, link_count;
  NSNumber     *pathFD;

  NSDictionary *pathDict;

  // Sanity checks
  if (in_fd < 0)
    {
      NSLog(@"OSEFileSystemMonitorThread(Linux): ERROR trying to add path "
            "without inotify instance!");
      return;
    }

  if (absolutePath == nil || [absolutePath isEqualToString:@""])
    {
      NSLog(@"OSEFileSystemMonitorThread(Linux): ERROR trying to add empty path!");
      return;
    }

  // Main code
  pathString = [NSString stringWithString:absolutePath];

  if ((pathDict = [_pathFDList objectForKey:pathString]) == nil)
    {
      link_count = 0;
      //IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MODIFY|IN_MOVED_FROM|IN_MOVED_TO|IN_ATTRIB);
      path_fd = inotify_add_watch(in_fd, [pathString cString],
                                  IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVED_FROM|IN_MOVED_TO|IN_ATTRIB);
    }
  else
    {
      link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
      path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];
    }

  // Increment LinkCount
  link_count++;
  pathDict = [NSDictionary
               dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithInt:path_fd], @"Descriptor",
                    [NSNumber numberWithInt:link_count], @"LinkCount", nil];

  [_pathFDList setObject:pathDict forKey:pathString];

  NSDebugLLog(@"OSEFileSystemMonitor",
              @"OSEFileSystemMonitorThread(Linux): addEventMonitorPath: %@ -- %@", 
              pathString, _pathFDList);
}

- (void)_removePath:(NSString *)absolutePath
{
  NSDictionary *pathDict;
  unsigned int path_fd;
  int          i, count = [_pathFDList count], link_count;

  // Validate conditions
  if (in_fd < 0)
    {
      NSLog(@"OSEFileSystemMonitorThread(Linux): ERROR trying to remove path without opened kernel queue!");
      return;
    }

  if (absolutePath == nil || [absolutePath isEqualToString:@""])
    {
      NSLog(@"OSEFileSystemMonitorThread(Linux): ERROR trying to remove empty path!");
      return;
    }

  // Get path descriptor
  if ((pathDict = [_pathFDList objectForKey:absolutePath]) == nil)
    {
      NSLog(@"OSEFileSystemMonitorThread(Linux): ERROR no info for monitor at path %@ found!", absolutePath);
      return;
    }
  path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];

  // Decrement LinkCount
  link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
  if (link_count == 1)
    {
      // Last link: remove path from dictionary and watch list
      inotify_rm_watch(in_fd, path_fd);
      [self checkForEvents];
      [_pathFDList removeObjectForKey:absolutePath];
    }
  else
    {
      link_count--;
      pathDict = [NSDictionary
                   dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:path_fd], @"Descriptor",
                        [NSNumber numberWithInt:link_count], @"LinkCount", nil];
      [_pathFDList setObject:pathDict forKey:absolutePath];
    }
}

- (oneway void)_startThread
{
  NSDebugLLog(@"OSEFileSystemMonitor",
              @"OSEFileSystemMonitorThread(Linux): startEventMonitorThread: "
              "inotify descriptor %i", in_fd);

  if ([[threadDict objectForKey:@"ThreadShouldExitNow"] boolValue])
    {
      NSDebugLLog(@"OSEFileSystemMonitor",
                  @"OSEFileSystemMonitorThread(Linux): startEventMonitorThread: "
                  "ThreadShouldExitNow");
      return;
    }
  
  // Start checking for events
  [threadDict setValue:[NSNumber numberWithBool:YES] 
		forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_stopThread
{
  NSDebugLLog(@"OSEFileSystemMonitor",
              @"OSEFileSystemMonitorThread(Linux): stopEventMonitorThread: "
              "inotify descriptor %i", in_fd);

  // Stop checking for events
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_terminateThread
{
  NSEnumerator *e;
  NSString     *pathString;

  [self _stopThread];

  //Close all opened descriptors
  e = [[_pathFDList allKeys] objectEnumerator];
  while ((pathString = [e nextObject]) != nil)
    {
      [self _removePath:pathString];
    }

  // Close kernel queue descriptor
  close(in_fd);
  in_fd = -1;

  [_pathFDList release];
 
  // Instruct thread to exit
  [threadDict setValue:[NSNumber numberWithBool:YES]
		forKey:@"ThreadShouldExitNow"];
}

// #define EVENT_SIZE  ( sizeof (struct inotify_event) )
// #define BUF_LEN     ( 1024 * ( EVENT_SIZE + 16 ) )

- (void)checkForEvents
{
  int           ret, i;
  struct pollfd pfd = { in_fd, POLLIN, 0 };

  // NSLog(@"OSEFileSystemMonitorThread [checkForFSEvents]: checking for events...");

  // Sanity check
  if (!_pathFDList || [[_pathFDList allKeys] count] <= 0)
    return;

  // Determine if inotify(7) file descriptor has events to read
  ret = poll(&pfd, 1, 10); // timeout of 50ms
  if (ret < 0)
    {
      fprintf(stderr, "poll failed: %s\n", strerror(errno));
    }
  else if (ret > 0)
    {
      int          event_count, i;
      unsigned int data_size;
      // Find size of available data
      ioctl(in_fd, FIONREAD, &data_size);
      // Define buffer based on found size of available data
      char buffer[data_size];

      event_count = read(in_fd, buffer, data_size);
      
      if (event_count < 0)
        {
          // An error occurred.
          fprintf(stderr, "An error occurred (event count %d).  " \
                  "The error was %i: %s.\n", 
                  event_count, errno, strerror(errno));
          return;
        }

      // eventList
      // 3 =
      // {
      //   Operations = (Rename);
      //   ChangedPath = "/Users/me";
      //   ChangedFile = "111.txt";
      //   ChangedPathTo = "222.txt"; // only for rename
      // };
      NSMutableDictionary *eventList = [[NSMutableDictionary alloc] init];
      NSMutableDictionary *eventInfo = nil;
      i = 0;
      while (i < event_count)
        {
          struct inotify_event *event = (struct inotify_event *)&buffer[i];
          NSString *path = [self _pathForDescriptor:event->wd];
          NSString *file = [NSString stringWithCString:event->name];
          NSString *watchDescriptor = [NSString stringWithFormat:@"%i", event->wd];
          NSArray  *operations = nil, *exOps = nil;

          if ((eventInfo = [eventList objectForKey:watchDescriptor]) != nil)
            {
              exOps = [eventInfo objectForKey:@"Operations"];
            }
          else
            {
              eventInfo = [NSMutableDictionary new];
            }
          
          if (event->len)
            {
              if (event->mask & IN_CREATE)
                {
                  operations = [NSArray arrayWithObjects:@"Write", @"Create", nil];
                  [eventInfo setObject:path forKey:@"ChangedPath"];
                  [eventInfo setObject:file forKey:@"ChangedFile"];

                  // fprintf(stderr, ">>> The %s was created.\n", event->name);
                }
              else if ((event->mask & IN_DELETE) || (event->mask & IN_DELETE_SELF))
                {
                  operations = [NSArray arrayWithObjects:@"Write", @"Delete", nil];
                  [eventInfo setObject:path forKey:@"ChangedPath"];
                  [eventInfo setObject:file forKey:@"ChangedFile"];

                  // fprintf(stderr, ">>> The %s was deleted.\n", event->name);
                }
              else if (event->mask & IN_MODIFY)
                {
                  // During file downloading generates event every 10-20ms.
                  // Currently it's switched off in _addPath:.
                  operations = [NSArray arrayWithObjects:@"Write", nil];
                  [eventInfo setObject:path forKey:@"ChangedPath"];
                  [eventInfo setObject:file forKey:@"ChangedFile"];

                  // fprintf(stderr, ">>> The %s was modified.\n", event->name);
                }
              else if (event->mask & IN_ATTRIB)
                {
                  operations = [NSArray arrayWithObjects:@"Attributes", nil];
                  [eventInfo setObject:path forKey:@"ChangedPath"];
                  [eventInfo setObject:file forKey:@"ChangedFile"];

                  // fprintf(stderr, ">>> The %s attributes was modified.\n", event->name);
                }
              else if (event->mask & IN_MOVED_FROM)
                {
                  operations = [NSArray arrayWithObjects:@"Write", @"MovedFrom", nil];
                  [eventInfo setObject:path forKey:@"ChangedPath"];
                  [eventInfo setObject:file forKey:@"ChangedFile"];
                  
                  // fprintf(stderr, ">>> The %s was moved from.\n", event->name);
                }
              else if (event->mask & IN_MOVED_TO)
                {
                  NSString *fileTo = nil;

                  if (exOps &&
                      ([exOps indexOfObject:@"MovedFrom"] != NSNotFound))
                    {
                      fileTo = [NSString stringWithCString:event->name];
                      
                      operations = [NSArray arrayWithObjects:@"Rename", nil];
                      // ChangedPath & ChangedFile was added in IN_MOVED_FROM part
                      [eventInfo setObject:fileTo forKey:@"ChangedFileTo"];
                      
                      // fprintf(stderr, ">>> The %s was renamed to %s.\n",
                      //         [file cString], event->name);
                    }
                  else
                    {
                      operations = [NSArray arrayWithObjects:@"Write", @"Create", nil];
                      [eventInfo setObject:path forKey:@"ChangedPath"];
                      [eventInfo setObject:file forKey:@"ChangedFile"];

                      // fprintf(stderr, ">>> The %s was moved to.\n", event->name);
                    }
                }
              
              if (exOps)
                {
                  operations = [exOps arrayByAddingObjectsFromArray:operations];
                }
              [eventInfo setObject:operations forKey:@"Operations"];
              [eventList setObject:eventInfo forKey:watchDescriptor];
            }

          i += sizeof(struct inotify_event) + event->len;
        }

      // Now we have an eventList dictionary which contains information about
      // all read file system events
      if (eventList && [[eventList allKeys] count] > 0)
        {
          NSDebugLLog(@"OSEFileSystemMonitor",
                      @"[NXFSM_Linux] send eventList: %@", eventList);
          for (NSString *wd in [eventList allKeys])
            {
              [monitorOwner handleEvent:[eventList objectForKey:wd]];
            }
        }
    }
}

@end

#pragma clang diagnostic pop

#endif // LINUX
