/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: FreeBSD file system event monitor (kevent).
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

#import <OSEFileSystemMonitor.h>

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <errno.h>
#include <string.h>
#include <inttypes.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

int kq_fd = -1;              // kernel queue
struct kevent events[1024];  // structure filled with kevent() call
struct kevent event_data[1024];
NSMutableDictionary *_pathFDList = nil;

// Local only additions
@interface OSEFileSystemMonitorThread (FreeBSD)

- (void)_updateKQInfo;

@end

@implementation OSEFileSystemMonitorThread (FreeBSD)

// It seams that kqueue(2) returns one file descriptor per process.
// So all kqueue related ivars must be shared:
//   kq_fd - kqueue descriptor
//   _pathFSList - list of file descriptors to monitor. It's a dictionary
//                 which conatins pairs of "path = file descriptor'
- (id)initWithConnection:(NSConnection *)conn
{
  self = [super init];

  // Initialize OS-specific part
  _pathFDList = [[NSMutableDictionary alloc] init];

  // Open a kernel queue if it was not created eralier.
  if (kq_fd < 0) {
    // Creates a new kernel event queue and returns a descriptor.
    if ((kq_fd = kqueue()) < 0) {
      NSLog(@"%s: Could not open kernel queue. Error: %s.\n", __func__, strerror(errno));
    }
  }

  monitorOwner = (OSEFileSystemMonitor *)[conn rootProxy];

  threadDict = [[NSThread currentThread] threadDictionary];
  [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"ThreadShouldExitNow"];
  [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"ThreadShouldCheckForEvents"];

  NSLog(@"%s", __func__);

  return self;
}

- (void)dealloc
{
  NSLog(@"OSEFileSystem(thread): dealloc");

  [_pathFDList release];

  [super dealloc];
}

// Refill kevent structures with EV_SET
// Called on adding or removal of path
- (void)_updateKQInfo
{
  NSEnumerator *e = [_pathFDList keyEnumerator];
  NSString *pathString = nil;
  int i = 0, path_fd;

  while ((pathString = [e nextObject]) != nil) {
    path_fd = [[[_pathFDList objectForKey:pathString] objectForKey:@"Descriptor"] intValue];

    //      fprintf(stderr, "Adding [%i]%s (FD:%i) (LC:%i)\n", i, [pathString cString], path_fd,
    //	      [[[_pathFDList objectForKey:pathString] objectForKey:@"LinkCount"] intValue]);

    EV_SET(&events[i], path_fd, EVFILT_VNODE, EV_ADD | EV_ENABLE | EV_CLEAR,
           NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME |
               NOTE_REVOKE,
           0, pathString);
    i++;
  }
}

// _pathFDList:
// {
//   "/Users/me/Temporary"= {
//     Descriptor = 28;
//     LinkCount = 2;
//   }
// }
- (void)_addPath:(NSString *)absolutePath
{
  NSString *pathString;
  char *path;
  int path_fd = -1, stdin_fd;
  int i, count, link_count;
  NSNumber *pathFD;
  NSDictionary *pathDict;

  // Sanity checks
  if (kq_fd < 0) {
    NSLog(@"%s: ERROR trying to add path without opened kernel queue!", __func__);
    return;
  }

  if (absolutePath == nil || [absolutePath isEqualToString:@""]) {
    NSLog(@"%s: ERROR trying to add empty path!", __func__);
    return;
  }

  // Main code
  pathString = [NSString stringWithString:absolutePath];

  if ((pathDict = [_pathFDList objectForKey:pathString]) == nil) {
    // Open a file descriptor for the file/directory that we want to monitor.
    path = (char *)[pathString cString];

    stdin_fd = open("/dev/stdin", O_RDONLY);
    path_fd = open(path, O_RDONLY);
    close(stdin_fd);

    if (path_fd < 0) {
      NSLog(@"%s: The file %s could not be opened for monitoring. Error was %s.\n", __func__, path,
            strerror(errno));
      return;
    }

    link_count = 0;
  } else {
    link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
    path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];
  }

  // Increment LinkCount
  link_count++;
  pathDict = [NSDictionary
      dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:path_fd], @"Descriptor",
                                   [NSNumber numberWithInt:link_count], @"LinkCount", nil];

  [_pathFDList setObject:pathDict forKey:pathString];

  NSLog(@"%s: %@ -- %@", __func__, pathString, _pathFDList);

  // Update filter with new file descriptor.
  [self _updateKQInfo];
}

- (void)_removePath:(NSString *)absolutePath
{
  NSDictionary *pathDict;
  unsigned int path_fd;
  int i, count = [_pathFDList count], link_count;

  // Validate conditions
  if (kq_fd < 0) {
    NSLog(@"%s: ERROR trying to remove path without opened kernel queue!", __func__);
    return;
  }

  if (absolutePath == nil || [absolutePath isEqualToString:@""]) {
    NSLog(@"%s: ERROR trying to remove empty path!", __func__);
    return;
  }

  // Get path descriptor
  if ((pathDict = [_pathFDList objectForKey:absolutePath]) == nil) {
    NSLog(@"%s: ERROR no info for monitor at path %@ found!", __func__, absolutePath);
    return;
  }
  path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];

  // Find kevent structure (corresponding to 'path_fd') in 'events' array
  // Index used in next call to EV_SET
  for (i = 0; i < count; i++) {
    if (events[i].ident == path_fd) {
      break;
    }
  }

  if (i == count) {
    NSLog(@"%s: ERROR: kevent structure not found for %@!", __func__, absolutePath);
    return;
  }

  // NSLog(@"OSEFileSystem(thread): removeEventMonitorPath:"
  //       @" %@(FD:%i, %i) -- %@",
  //       absolutePath, path_fd, i, _pathFDList);

  // Decrement LinkCount
  link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
  if (link_count == 1) {
    // Last link: remove path from dictionary and kernel queue
    [_pathFDList removeObjectForKey:absolutePath];
    EV_SET(&events[i], path_fd, EVFILT_VNODE, EV_DISABLE | EV_DELETE, 0, 0, 0);
    close(path_fd);
  } else {
    link_count--;
    pathDict = [NSDictionary
        dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:path_fd], @"Descriptor",
                                     [NSNumber numberWithInt:link_count], @"LinkCount", nil];
    [_pathFDList setObject:pathDict forKey:absolutePath];
  }

  // Refill kqueue even if we've just removed path descriptior with EV_SET call
  [self _updateKQInfo];
}

- (oneway void)_startThread
{
  NSLog(@"%s: kqueue %i", __func__, kq_fd);

  // Start checking for events
  [threadDict setValue:[NSNumber numberWithBool:YES] forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_stopThread
{
  NSLog(@"%s: kqueue %i", __func__, kq_fd);

  // Stop checking for events
  [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_terminateThread
{
  NSEnumerator *e;
  NSString *pathString;

  [self _stopThread];

  // Close all opened descriptors
  e = [[_pathFDList allKeys] objectEnumerator];
  while ((pathString = [e nextObject]) != nil) {
    [self _removePath:pathString];
  }

  // Close kernel queue descriptor
  close(kq_fd);
  kq_fd = -1;

  // Instruct thread to exit
  [threadDict setValue:[NSNumber numberWithBool:YES] forKey:@"ThreadShouldExitNow"];
}

// A simple routine to return a string for a set of flags.
char *flags_to_string(int flags)
{
  static char ret[512];
  char *or = "";

  ret[0] = '\0';  // clear the string.
  if (flags & NOTE_DELETE) {
    strcat(ret, or);
    strcat(ret, "NOTE_DELETE");
    or = "|";
  }
  if (flags & NOTE_WRITE) {
    strcat(ret, or);
    strcat(ret, "NOTE_WRITE");
    or = "|";
  }
  if (flags & NOTE_EXTEND) {
    strcat(ret, or);
    strcat(ret, "NOTE_EXTEND");
    or = "|";
  }
  if (flags & NOTE_ATTRIB) {
    strcat(ret, or);
    strcat(ret, "NOTE_ATTRIB");
    or = "|";
  }
  if (flags & NOTE_LINK) {
    strcat(ret, or);
    strcat(ret, "NOTE_LINK");
    or = "|";
  }
  if (flags & NOTE_RENAME) {
    strcat(ret, or);
    strcat(ret, "NOTE_RENAME");
    or = "|";
  }
  if (flags & NOTE_REVOKE) {
    strcat(ret, or);
    strcat(ret, "NOTE_REVOKE");
    or = "|";
  }

  return ret;
}

- (NSArray *)operationsFromEvents:(NSArray *)events
{
  NSEnumerator *e = [events objectEnumerator];
  NSString *event;
  NSMutableArray *operations = [NSMutableArray new];

  while ((event = [e nextObject])) {
    if ([event isEqualToString:@"NOTE_DELETE"])
      [operations addObject:@"Delete"];
    else if ([event isEqualToString:@"NOTE_WRITE"])
      [operations addObject:@"Write"];
    else if ([event isEqualToString:@"NOTE_RENAME"])
      [operations addObject:@"Rename"];
    else if ([event isEqualToString:@"NOTE_ATTRIB"])
      [operations addObject:@"Attributes"];
    //      else if ([event isEqualToString:@"NOTE_LINK"])
    //	[operations addObject:@"Link"];
    //      else if ([event isEqualToString:@"NOTE_EXTEND"])
    //	[operations addObject:@"Extend"];
    //      else if ([event isEqualToString:@"NOTE_REVOKE"])
    //	[operations addObject:@"Revoke"];
  }

  return operations;
}

// struct kevent {
//   uintptr_t ident; /* identifier for this event */
//   short filter;    /* filter for event */
//   u_short flags;   /* action flags for kqueue */
//   u_int fflags;    /* filter flag value */
//   int64_t data;    /* filter data value */
//   void *udata;     /* opaque user data identifier */
//   uint64_t ext[4]; /* extensions */
// };
- (void)checkForEvents
{
  struct timespec timeout;
  int event_count, i;

  // Set the timeout to wake us every half second.
  timeout.tv_sec = 0;  // 0 seconds
  //  timeout.tv_nsec = 500000000;  // 500 microseconds
  timeout.tv_nsec = 0;  // 0 microseconds

  //  event_count = kevent(kq_fd, &events, 1, &event_data, 1, &timeout);
  event_count =
      kevent(kq_fd, events, [_pathFDList count], event_data, [_pathFDList count], &timeout);

  if (event_count == 0) {
    return;
  }

  if ((event_count < 0) /*|| (event_data.flags == EV_ERROR)*/) {
    // An error occurred.
    NSLog(@"%s: An error occurred (event count %d). The error was %i: %s.\n", __func__, event_count,
          errno, strerror(errno));
    return;
  }

  {
    NSString *pathString;
    NSString *flagsString;
    NSArray *opsList;

    for (i = 0; i < event_count; i++) {
      if (event_data[i].flags & EV_DELETE) {
        continue;
      }
      if (event_data[i].udata == 0) {
        continue;
      }

      flagsString = [NSString stringWithCString:flags_to_string(event_data[i].fflags)];
      //	  NSLog(@"[OSEFileSystem -checkFSEvents] event flags %@ on ident %i", flagsString,
      //event_data[i].ident);

      pathString = (NSString *)event_data[i].udata;
      // Check for path specified in event data
      if (pathString == nil || [pathString isEqualToString:@""]) {
        NSLog(@"%s: FS event with unknown path occured!", __func__);
        continue;
      }

      opsList = [flagsString componentsSeparatedByString:@"|"];

      // Process event occured
      NSLog(@"%s: Event %" PRIdPTR
             " occurred.  Filter %d, flags %d, filter flags %s, filter data %" PRIdPTR
             ", path '%s', operations: %@",
            __func__, event_data[i].ident, event_data[i].filter, event_data[i].flags,
            [flagsString cString], event_data[i].data, [pathString cString], opsList);

      // eventList
      // 3 = // file descriptor
      // {
      //   Operations = (Rename);
      //   ChangedPath = "/Users/me";
      //   ChangedFile = "111.txt";
      //   ChangedPathTo = "222.txt"; // only for rename
      // };
      NSMutableDictionary *eventList = [[NSMutableDictionary alloc] init];
      NSMutableDictionary *eventInfo = nil;
      NSString *path = (NSString *)event_data[i].udata;
      NSString *file = [path lastPathComponent];
      NSString *watchDescriptor = [NSString stringWithFormat:@"%lu", event_data[i].ident];
      NSArray *operations = nil, *existingOperations = nil;

      if ((eventInfo = [eventList objectForKey:watchDescriptor]) != nil) {
        existingOperations = [eventInfo objectForKey:@"Operations"];
      } else {
        eventInfo = [NSMutableDictionary new];
      }

      if (event_data[i].flags & NOTE_WRITE) {
        operations = [NSArray arrayWithObjects:@"Write", @"Create", nil];
        [eventInfo setObject:path forKey:@"ChangedPath"];
        [eventInfo setObject:file forKey:@"ChangedFile"];

        // fprintf(stderr, ">>> The %s was created.\n", event->name);
      } else if (event_data[i].flags & NOTE_DELETE) {
        operations = [NSArray arrayWithObjects:@"Write", @"Delete", nil];
        [eventInfo setObject:path forKey:@"ChangedPath"];
        [eventInfo setObject:file forKey:@"ChangedFile"];

        // fprintf(stderr, ">>> The %s was deleted.\n", event->name);
      } else if (event_data[i].flags & NOTE_ATTRIB) {
        operations = [NSArray arrayWithObjects:@"Attributes", nil];
        [eventInfo setObject:path forKey:@"ChangedPath"];
        [eventInfo setObject:file forKey:@"ChangedFile"];

        // fprintf(stderr, ">>> The %s attributes was modified.\n", event->name);
      } else if (event_data[i].flags & NOTE_RENAME) {
        operations = [NSArray arrayWithObjects:@"Rename", nil];
        [eventInfo setObject:path forKey:@"ChangedPath"];
        [eventInfo setObject:file forKey:@"ChangedFile"];

        // fprintf(stderr, ">>> The %s was moved from.\n", event->name);
      }

      if (existingOperations) {
        operations = [existingOperations arrayByAddingObjectsFromArray:operations];
      }
      [eventInfo setObject:operations forKey:@"Operations"];
      [eventList setObject:eventInfo forKey:watchDescriptor];

      // Now we have an eventList dictionary which contains information about
      // all read file system events
      if (eventList && [[eventList allKeys] count] > 0) {
        // NSDebugLLog(@"OSEFileSystemMonitor", @"[NXFSM_Linux] send eventList: %@", eventList);
        for (NSString *wd in [eventList allKeys]) {
          [monitorOwner handleEvent:[eventList objectForKey:wd]];
        }
      }
    }
  }
}

@end

#pragma clang diagnostic pop