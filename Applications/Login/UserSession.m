/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Copyright (C) 2011 Sergii Stoian
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

#import "Controller.h"
#import "UserSession.h"

#import <string.h>
#import <errno.h>
#import <pwd.h>
#import <grp.h>
#import <sys/types.h>
#import <sys/wait.h>

#import <fcntl.h>
#import <sys/ioctl.h>

#import <unistd.h>

@implementation UserSession

- (id)initWithOwner:(Controller *)controller
               name:(NSString *)name
{
  self = [super init];

  appController = controller;

  [self setSessionName:name];

  return self;
}

- (void)dealloc
{
  NSLog(@"UserSession: dealloc");

  NSLog(@"userName: %lu", [userName retainCount]);
  NSLog(@"sessionScript: %lu", [sessionScript retainCount]);

  [userName release]; // retained by 'copy' in setSessionName:
  [sessionScript release]; // retained by 'copy' in setSessionScript:

  NSLog(@"UserSession: dealloc end");

  [super dealloc];
}

- (void)setSessionName:(NSString *)name
{
  userName = [name copy];
}

- (NSString *)sessionName
{
  return userName;
}

- (void)setSessionScript:(NSArray *)script
{
  sessionScript = [script copy];
}

// Starts:
// 1. LoginHook (~/L/P/.N/Login)
// 2. sessionScript
// 3. LogoutHook (~/L/P/.N/Login)
- (void)launchSessionScript
{
  int  ret;
  BOOL appendToLog;

  NSLog(@"launchSession: %@", sessionScript);

  for (NSArray *scriptCommand in sessionScript)
    {
      NSString *commandName = nil;

      if ([scriptCommand count] == 0)
        continue;

      commandName = [scriptCommand objectAtIndex:0];

      NSLog(@"SESSION: starting command %@", commandName);

      if (commandName == nil || [commandName isEqualToString:@""])
        continue;

      appendToLog = ([sessionScript indexOfObject:scriptCommand]==0) ? NO : YES;
      ret = [self launchCommand:scriptCommand
                      logAppend:appendToLog
                           wait:YES];
      if (ret != 0)
	{
	  NSLog(@"Error launching session script command %@", commandName);
          break;
	}
    }
}

- (id)userDefaultsObjectForKey:(NSString *)key
{
  NSString	*pathFormat = @"%@/Library/Preferences/.NextSpace/Login";
  NSString	*homeDir = NSHomeDirectoryForUser(userName);
  NSString	*defsPath;
  NSDictionary	*defs;
  
  defsPath = [NSString stringWithFormat:pathFormat, homeDir];
  defs = [NSDictionary dictionaryWithContentsOfFile:defsPath];

  return [defs objectForKey:key];
}

#define GS @"/usr/NextSpace/bin/gnustep-services"
#define WM @"/usr/NextSpace/Apps/Workspace.app/Workspace"

- (void)launch
{
  int 		ret;
  NSArray	*hook;
  NSString	*message = nil;
  
  // GNUstep services start
  ret = [self launchCommand:[NSArray arrayWithObjects:GS, @"start", nil]
                  logAppend:NO
                       wait:YES];
  // LoginHook - must be a string
  hook = [self userDefaultsObjectForKey:@"LoginHook"];
  if (hook && [hook isKindOfClass:[NSString class]])
    {
      ret = [self launchCommand:[NSArray arrayWithObjects:hook, nil]
                      logAppend:YES wait:NO];
    }
  // Workspace Manager
  ret = [self launchCommand:[NSArray arrayWithObjects:WM, nil]
                  logAppend:YES
                       wait:YES];
  if (ret != 0)
    {
      message = @"Workspace Manager quit with error.";
    }
  // LogoutHook
  hook = [self userDefaultsObjectForKey:@"LogoutHook"];
  if (hook && [hook isKindOfClass:[NSString class]])
    {
      ret = [self launchCommand:[NSArray arrayWithObjects:hook, nil]
                      logAppend:YES wait:NO];
    }
  // Stop GNUstep services
  ret = [self launchCommand:[NSArray arrayWithObjects:GS, @"stop", nil]
                  logAppend:YES
                       wait:YES];

  if (message)
    {
      [appController performSelectorOnMainThread:@selector(showSessionMessage:)
                                      withObject:message
                                   waitUntilDone:YES];
    }
}

// Called for every launched command  (launchCommand:)
- (BOOL)_setUserEnvironment
{
  struct passwd	*user;
  
  user = getpwnam([userName cString]);
  endpwent();
  
  if (user == NULL)
    {
      NSLog(_(@"Unable to get credentials of user %@! Exiting."), userName);
      return NO;
    }

  // Go to the user's home directory
  if (chdir(user->pw_dir) != 0)
    {
      NSLog(_(@"Unable to change to the user's home directory %s:%s\n"
	      @"Staying where I am now."), user->pw_dir, strerror(errno));
    }

  // Lower our priviledges
  if (initgroups(user->pw_name, user->pw_gid) != 0)
    {
      NSLog(_(@"Unable to set user's supplementary groups: %s. "
	      @"Exiting."), strerror(errno));
      return NO;
    }

  if (setgid(user->pw_gid) != 0)
    {
      NSLog(_(@"Unable to set the user's GID (%d): %s. Exiting."),
	    user->pw_gid, strerror(errno));
      return NO;
    }
  if (setuid(user->pw_uid) != 0)
    {
      NSLog(_(@"Unable to set the user's UID (%d): %s. Exiting."),
	    user->pw_uid, strerror(errno));
      return NO;
    }

  // General environment variables
  setenv("USER", user->pw_name, 1);
  setenv("LOGNAME", user->pw_name, 1);
  setenv("HOME", user->pw_dir, 1);
  setenv("SHELL", user->pw_shell, 1);
  setenv("LC_CTYPE", "en_US.UTF-8", 1);
  setenv("DISPLAY", ":0", 1);

  setenv("PATH", [[NSString stringWithFormat:@"/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin:%s", getenv("PATH")] cString], 1);
  setenv("LD_LIBRARY_PATH", [[NSString stringWithFormat:@"%s/Library/Libraries", user->pw_dir] cString], 1);
  setenv("GNUSTEP_PATHLIST", [[NSString stringWithFormat:@"%s:/:/usr/NextSpace:/Network", user->pw_dir] cString], 1);
  
  setenv("INFOPATH", [[NSString stringWithFormat:@"%s/Library/Documentation/info:/Library/Documentation/info:/usr/NextSpace/Documentation/info", user->pw_dir] cString], 1);
  setenv("FREETYPE_PROPERTIES", "truetype:interpreter-version=35", 1);
  
  // Set for WindowMaker part of Workspace to find its preferences
  // and other stuff
  // setenv("GNUSTEP_USER_ROOT", [[NSString stringWithFormat:@"%s/Library", user->pw_dir] cString], 1);

  // For developers
  setenv("GNUSTEP_MAKEFILES", "/Developer/Makefiles", 1);

  // Log file for session use
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString	*logDir = [NSString stringWithFormat:@"/tmp/GNUstepSecure%u", user->pw_uid];
  BOOL		isDir;

  if (![fm fileExistsAtPath:logDir isDirectory:&isDir])
    {
      [fm createDirectoryAtPath:logDir
          withIntermediateDirectories:YES
                     attributes:[NSDictionary dictionaryWithObject:@"700" forKey:NSFilePosixPermissions]
                          error:0];
    }
  setenv("NS_LOGFILE", [[logDir stringByAppendingPathComponent:@"console.log"] cString], 1);
  
  return YES;
}

- (int)launchCommand:(NSArray *)command
           logAppend:(BOOL)append
                wait:(BOOL)isWait
{
  const char *executable = NULL;
  int        ac = [command count];
  const char *args[ac+1];
  int        i;
  int        pid=0;
  int        status=0;
  pid_t      wpid;

  executable = [[command objectAtIndex:0] fileSystemRepresentation];
  args[0] = executable;

  for (i = 1; i < ac; i++)
    {     
      args[i] = [[command objectAtIndex:i] cString];
      // fprintf(stderr, "[launchCommand] Added argument: %s\n", args[i]);
    }
  args[ac] = NULL;

  pid = fork();
  switch (pid)
    {
    case 0:
      fprintf(stderr, "[fork] Executing %s\n", executable);
      if ([self _setUserEnvironment] == YES)
	{
	  // fprintf(stderr, "[fork] USER=%s, HOME=%s, DISPLAY=%s\n",
	  //         getenv("USER"), getenv("HOME"), getenv("DISPLAY"));
          if (append)
            {
              freopen(getenv("NS_LOGFILE"), "a", stderr);
              freopen(getenv("NS_LOGFILE"), "a", stdout);
            }
          else
            {
              freopen(getenv("NS_LOGFILE"), "w+", stderr);
              freopen(getenv("NS_LOGFILE"), "w+", stdout);
            }
	  status = execv(executable, (char**)args);
	}
      // If forked process goes here - something went wrong: aborting.
      fprintf(stderr, "[fork] 'execv' returned error %i (%i:%s). Aborting.\n",
              status, errno, strerror(errno));
      abort();
      break;
    default:
      if (isWait == NO)
        break;
      
      // Wait for command to finish launching
      fprintf(stderr, "[lanchCommand] Waiting for PID: %i\n", pid);
      wpid = waitpid(pid, &status, 0);
      // if (wpid == -1)
      //   {
      //     fprintf(stderr, "<launchCommand> waitpid (%i) error (%s)\n", 
      //   	  pid, strerror(errno));
      //     return 0;
      //   }
      // else
      if (WIFEXITED(status))
	{
	  fprintf(stderr, "<launchCommand> %s EXITED with code %d(%d)\n", 
		  executable, WEXITSTATUS(status), status);
	}
      else if (WIFSIGNALED(status))
	{
	  fprintf(stderr, "<launchCommand> %s KILLED with signal %d\n", 
		  executable, WTERMSIG(status));
	  if (WCOREDUMP(status))
	    {
	      fprintf(stderr, " (CORE DUMPED)\n");
	    }
	  else
	    {
	      fprintf(stderr, "\n");
	    }
	}
      else if (WIFSTOPPED(status))
	{
	  fprintf(stderr, "<launchCommand> %s is STOPPED\n", executable);
	}
      else
        {
          fprintf(stderr, "<launchCommand> %s finished with exit code %i\n", 
                  executable, status);
        }

      break;
    }

  return status;
}

@end
