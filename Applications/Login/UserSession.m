/*
   Controller.m
   The user session execution.

   This file is part of xSTEP.

   Copyright (C) 2006

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXAppKit/NXAlert.h>
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

- (id)initWithOwner:(Controller *)owner
	     script:(NSDictionary *)script
	       name:(NSString *)name
{
  self = [super init];

  NSLog(@"INIT session with name: %@", name);

  [self setSessionScript:script];
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

- (void)setSessionScript:(NSDictionary *)script
{
  sessionScript = [script copy];
}

- (void)setSessionName:(NSString *)name
{
  userName = [name copy];
}

- (NSString *)sessionName
{
  return userName;
}

- (void)launchSession
{
  int     i;
  NSArray *scriptKeys = [[sessionScript allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  int     sc = [scriptKeys count];

  NSLog(@"launchSession: %@", sessionScript);

  for (i = 0; i < sc; i++)
    {
      NSArray  *scriptCommand = nil;
      NSString *commandName = nil; 

      scriptCommand = [sessionScript objectForKey:[scriptKeys objectAtIndex:i]];

      if ([scriptCommand count] == 0)
	{
	  continue;
	}

      commandName = [scriptCommand objectAtIndex:0];

      NSLog(@"SESSION: starting command %@", commandName);

      if (commandName == nil || [commandName isEqualToString:@""])
	{
	  continue;
	}

      if (([self launchCommand:scriptCommand]) != 0)
	{
	  NSLog(@"Error launching session script command %@", commandName);
          break;
	}
    }
}

- (BOOL)setUserEnvironment
{
  struct passwd	*user;
  char		*env_display;
  char		*env_gs_user_root;
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
      NXRunAlertPanel(@"Login",
		      @"Unable to set user's supplementary groups: %s. ",
		      nil, nil, nil, strerror(errno));
      NSLog(_(@"Unable to set user's supplementary groups: %s. "
	      @"Exiting."), strerror(errno));
      return NO;
    }

  if (setgid(user->pw_gid) != 0)
    {
      NXRunAlertPanel(@"Login",
		      @"Unable to set the user's GID (%d): %s. Exiting.",
		      nil, nil, nil, user->pw_gid, strerror(errno));
      NSLog(_(@"Unable to set the user's GID (%d): %s. Exiting."),
	    user->pw_gid, strerror(errno));
      return NO;
    }
  if (setuid(user->pw_uid) != 0)
    {
      NXRunAlertPanel(_(@"Login"),
		      _(@"Unable to set the user's UID (%d): %s. Exiting."), 
		      nil, nil, nil, user->pw_uid, strerror(errno));
      NSLog(_(@"Unable to set the user's UID (%d): %s. Exiting."),
	    user->pw_uid, strerror(errno));
      return NO;
    }

  // General environment variables
  setenv("USER", user->pw_name, 1);
  setenv("LOGNAME", user->pw_name, 1);
  setenv("HOME", user->pw_dir, 1);
  setenv("SHELL", user->pw_shell, 1);

  env_display = strdup(getenv("DISPLAY"));
  setenv("DISPLAY", env_display, 1);
  free(env_display);
  
  // Set for WindowMaker part of Workspace to find its preferences
  // and other stuff
  env_gs_user_root = malloc(strlen(user->pw_dir) + strlen("/Library") + 1);
  strcpy(env_gs_user_root, user->pw_dir);
  strcat(env_gs_user_root, "/Library");
  setenv("GNUSTEP_USER_ROOT", env_gs_user_root, 1);
  free(env_gs_user_root);

  return YES;
}

- (int)launchCommand:(NSArray *)command
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
      fprintf(stderr, "<launchCommand> Added argument: %s\n", args[i]);
    }
  args[ac] = NULL;

  pid = fork();
  switch (pid)
    {
    case 0:
      fprintf(stderr, "<launchCommand> Executing %s\n", executable);
      if ([self setUserEnvironment] == YES)
	{
	  fprintf(stderr, "<launchCommand> %s, %s, %s\n",
		  getenv("USER"), getenv("HOME"), getenv("DISPLAY"));
	  execv(executable, (char**)args);
	}
      else
        {
          exit(1);
        }
      break;
    default:
      // Wait for command to finish launching
      fprintf(stderr, "Waiting for PID: %i\n", pid);
      wpid = waitpid(pid, &status, 0);
      if (wpid == -1)
	{
	  fprintf(stderr, "<launchCommand> waitpid (%i) error (%s)\n", 
		  pid, strerror(errno));
	  return 1;
	}
      else if (WIFEXITED(status))
	{
	  fprintf(stderr, "<launchCommand> %s EXITED with code %d(%d)\n", 
		  executable, WEXITSTATUS(status), status);
	}
      else if (WIFSIGNALED(status))
	{
	  fprintf(stderr, "<launchCommand> %s KILLED with signal %d", 
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

