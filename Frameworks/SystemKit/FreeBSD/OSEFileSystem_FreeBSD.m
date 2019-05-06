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

#import <OSEFileSystem.h>

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

int                 kq_fd = -1; // kernel queue
struct kevent       events[1024]; // structure filled with kevent() call
struct kevent       event_data[1024];
NSMutableDictionary *_pathFDList = nil;

// Local only additions
@interface OSEFileSystem (FreeBSD)

- (void)_updateKQInfo;

@end

@implementation OSEFileSystem (FreeBSD)

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
  if (kq_fd < 0)
    {
      // Creates a new kernel event queue and returns a descriptor.
      if ((kq_fd = kqueue()) < 0)
	{
	  fprintf(stderr, "OSEFileSystem(thread): Could not open kernel queue." \
		  "Error: %s.\n", strerror(errno));
	}
    }

  monitorOwner = (OSEFileSystem *)[conn rootProxy];

  threadDict = [[NSThread currentThread] threadDictionary];
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldExitNow"];
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldCheckForEvents"];

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
  NSString     *pathString = nil;
  int          i = 0, path_fd;

  while ((pathString = [e nextObject]) != nil)
    {
      path_fd = [[[_pathFDList objectForKey:pathString] objectForKey:@"Descriptor"] intValue];

//      fprintf(stderr, "Adding [%i]%s (FD:%i) (LC:%i)\n", i, [pathString cString], path_fd, 
//	      [[[_pathFDList objectForKey:pathString] objectForKey:@"LinkCount"] intValue]);

      EV_SET(&events[i], path_fd, EVFILT_VNODE, 
	     EV_ADD | EV_ENABLE | EV_CLEAR, 
	     NOTE_DELETE |  NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | 
	     NOTE_LINK | NOTE_RENAME | NOTE_REVOKE, 0, pathString);
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
- (void)_addEventMonitorPath:(NSString *)absolutePath
{
  NSString     *pathString;
  char         *path;
  int          path_fd = -1, stdin_fd;
  int          i, count, link_count;
  NSNumber     *pathFD;

  NSMutableDictionary *pathDict;

  // Sanity checks
  if (kq_fd < 0)
    {
      NSLog(@"OSEFileSystem(thread): ERROR trying to add path"
            @" without opened kernel queue!");
      return;
    }

  if (absolutePath == nil || [absolutePath isEqualToString:@""])
    {
      NSLog(@"OSEFileSystem(thread): ERROR trying to add empty path!");
      return;
    }

  // Main code
  // pathString = [[NSString alloc] initWithString:absolutePath];
  pathString = [NSString stringWithString:absolutePath];

  if ((pathDict = [_pathFDList objectForKey:pathString]) == nil)
    {
      // Open a file descriptor for the file/directory that we want to monitor.
      path = (char *)[pathString cString];

      stdin_fd = open("/dev/stdin", O_RDONLY);
      path_fd = open(path, O_RDONLY);
      close(stdin_fd);

      if (path_fd < 0)
	{
	  fprintf(stderr, "OSEFileSystem(thread): The file %s could not be"
                  " opened for monitoring. Error was %s.\n",
                  path, strerror(errno));
	  return;
	}

      link_count = 0;
    }
  else
    {
      link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
      path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];
    }

  // Increment LinkCount
  link_count++;
  pathDict = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt:path_fd], @"Descriptor",
    [NSNumber numberWithInt:link_count], @"LinkCount",
    nil];

  [_pathFDList setObject:pathDict forKey:pathString];

  // NSLog(@"OSEFileSystem(thread): addEventMonitorPath: %@ -- %@", 
  //        pathString, _pathFDList);

  // [pathString release];

  // Update filter with new file descriptor.
  [self _updateKQInfo];
}

- (void)_removeEventMonitorPath:(NSString *)absolutePath
{
  NSDictionary *pathDict;
  unsigned int path_fd;
  int          i, count = [_pathFDList count], link_count;

  // Validate conditions
  if (kq_fd < 0)
    {
      NSLog(@"OSEFileSystem(thread): ERROR trying to remove path without"
            " opened kernel queue!");
      return;
    }

  if (absolutePath == nil || [absolutePath isEqualToString:@""])
    {
      NSLog(@"OSEFileSystem(thread): ERROR trying to remove empty path!");
      return;
    }

  // Get path descriptor
  if ((pathDict = [_pathFDList objectForKey:absolutePath]) == nil)
    {
      NSLog(@"OSEFileSystem(thread): ERROR no info for monitor"
            " at path %@ found!", absolutePath);
      return;
    }
  path_fd = [[pathDict objectForKey:@"Descriptor"] intValue];

  // Find kevent structure (corresponding to 'path_fd') in 'events' array
  // Index used in next call to EV_SET
  for (i = 0; i < count; i++)
    {
      if (events[i].ident == path_fd)
	{
	  break;
	}
    }

  if (i == count)
    {
      NSLog(@"OSEFileSystem(thread): ERROR: kevent structure not found for %@!",
            absolutePath);
      return;
    }

  // NSLog(@"OSEFileSystem(thread): removeEventMonitorPath:"
  //       @" %@(FD:%i, %i) -- %@", 
  //       absolutePath, path_fd, i, _pathFDList);

  // Decrement LinkCount
  link_count = [[pathDict objectForKey:@"LinkCount"] intValue];
  if (link_count == 1)
    {
      // Last link: remove path from dictionary and kernel queue
      [_pathFDList removeObjectForKey:absolutePath];
      EV_SET(&events[i], path_fd, EVFILT_VNODE, EV_DISABLE | EV_DELETE, 0, 0, 0);
      close(path_fd);
    }
  else
    {
      link_count--;
      pathDict = [NSDictionary dictionaryWithObjectsAndKeys:
	[NSNumber numberWithInt:path_fd], @"Descriptor",
	[NSNumber numberWithInt:link_count], @"LinkCount",
	nil];
      [_pathFDList setObject:pathDict forKey:absolutePath];
    }

  // Refill kqueue even if we've just removed path descriptior with EV_SET call
  [self _updateKQInfo];
}

- (oneway void)_startEventMonitorThread
{
  NSLog(@"OSEFileSystem(thread): startEventMonitorThread: kqueue %i", kq_fd);
  
  // Start checking for events
  [threadDict setValue:[NSNumber numberWithBool:YES] 
		forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_stopEventMonitorThread
{
  NSLog(@"OSEFileSystem(thread): stopEventMonitorThread: kqueue %i", kq_fd);

  // Stop checking for events
  [threadDict setValue:[NSNumber numberWithBool:NO] 
		forKey:@"ThreadShouldCheckForEvents"];
}

- (oneway void)_cancelEventMonitorThread
{
  NSEnumerator *e;
  NSString     *pathString;

  [self _stopEventMonitorThread];

  //Close all opened descriptors
  e = [[_pathFDList allKeys] objectEnumerator];
  while ((pathString = [e nextObject]) != nil)
    {
      [self _removeEventMonitorPath:pathString];
    }

  // Close kernel queue descriptor
  close(kq_fd);
  kq_fd = -1;

  // Instruct thread to exit
  [threadDict setValue:[NSNumber numberWithBool:YES] 
		forKey:@"ThreadShouldExitNow"];
}

// A simple routine to return a string for a set of flags.
char *flags_to_string(int flags)
{
  static char ret[512];
  char *or = "";

  ret[0]='\0'; // clear the string.
  if (flags & NOTE_DELETE) {strcat(ret,or);strcat(ret,"NOTE_DELETE");or="|";}
  if (flags & NOTE_WRITE) {strcat(ret,or);strcat(ret,"NOTE_WRITE");or="|";}
  if (flags & NOTE_EXTEND) {strcat(ret,or);strcat(ret,"NOTE_EXTEND");or="|";}
  if (flags & NOTE_ATTRIB) {strcat(ret,or);strcat(ret,"NOTE_ATTRIB");or="|";}
  if (flags & NOTE_LINK) {strcat(ret,or);strcat(ret,"NOTE_LINK");or="|";}
  if (flags & NOTE_RENAME) {strcat(ret,or);strcat(ret,"NOTE_RENAME");or="|";}
  if (flags & NOTE_REVOKE) {strcat(ret,or);strcat(ret,"NOTE_REVOKE");or="|";}

  return ret;
}

- (NSArray*)operationsFromEvents:(NSArray *)events
{
  NSEnumerator   *e = [events objectEnumerator];
  NSString       *event;
  NSMutableArray *operations = [NSMutableArray new];

  while ((event = [e nextObject]))
    {
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

- (void)checkForFSEvents
{
  struct timespec timeout;
  int             event_count, i;

  // Set the timeout to wake us every half second.
  timeout.tv_sec = 0;           // 0 seconds
  //  timeout.tv_nsec = 500000000;  // 500 microseconds
  timeout.tv_nsec = 0;          // 0 microseconds

//  event_count = kevent(kq_fd, &events, 1, &event_data, 1, &timeout); 
  event_count = kevent(kq_fd, events, [_pathFDList count], 
		       event_data, [_pathFDList count], 
		       &timeout); 

  if (event_count == 0)
    {
      return;
    }

  if ((event_count < 0) /*|| (event_data.flags == EV_ERROR)*/)
    {
      // An error occurred.
      fprintf(stderr, "An error occurred (event count %d).  " \
	      "The error was %i: %s.\n", 
	      event_count, errno, strerror(errno));
      return;
    }

  if (event_count > 0)
    {
      NSString *pathString;
      NSString *flagsString;
      NSArray  *opsList;

      for (i = 0; i < event_count; i++)
	{
	  if (event_data[i].flags & EV_DELETE)
	    continue;
	  if (event_data[i].udata == 0)
	    continue;

	  flagsString = [NSString stringWithCString:flags_to_string(event_data[i].fflags)];
//	  NSLog(@"[OSEFileSystem -checkFSEvents] event flags %@ on ident %i", flagsString, event_data[i].ident);

	  pathString = (NSString *)event_data[i].udata;
	  // Check for path specified in event data
	  if (pathString == nil ||
	      [pathString isEqualToString:@""])
	    {
	      NSLog(@"FS event with unknown path occured!");
	      continue;
	    }

	  opsList = [flagsString componentsSeparatedByString:@"|"];

	  // Process event occured
    	  fprintf(stderr, "Event %" PRIdPTR " occurred.  Filter %d, flags %d, " \
		  "filter flags %s, filter data %" PRIdPTR ", path '%s'\n",
		  event_data[i].ident,
		  event_data[i].filter,
		  event_data[i].flags,
		  [flagsString cString],
		  event_data[i].data,
		  [pathString cString]);

	  [monitorOwner fileSystemEventsOccured:[self operationsFromEvents:opsList]
	        			 atPath:pathString];
	}
    }
}

@end

