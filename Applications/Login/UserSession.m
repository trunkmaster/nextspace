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

// Log file for session use
// - (NSString *)_sessionLogPath
// {
//   struct passwd *user;
//   NSString *logPath;

//   user = getpwnam([_userName cString]);
//   if (user) {
//     logPath = [[NSString alloc] initWithFormat:@"/tmp/GNUstepSecure%u/console.log",
//     user->pw_uid];
//   }

//   return logPath;
// }

// Called for every launched command  (launchCommand:)
- (BOOL)_setUserEnvironment
{
  struct passwd *user;

  user = getpwnam([_userName cString]);
  endpwent();

  if (user == NULL) {
    NSLog(_(@"Unable to get credentials of user %@! Exiting."), _userName);
    return NO;
  }

  // Go to the user's home directory
  if (chdir(user->pw_dir) != 0) {
    NSLog(_(@"Unable to change to the user's home directory %s:%s\n"
            @"Staying where I am now."),
          user->pw_dir, strerror(errno));
  }

  // Lower our priviledges
  if (initgroups(user->pw_name, user->pw_gid) != 0) {
    NSLog(_(@"Unable to set user's supplementary groups: %s. "
            @"Exiting."),
          strerror(errno));
    return NO;
  }

  if (setgid(user->pw_gid) != 0) {
    NSLog(_(@"Unable to set the user's GID (%d): %s. Exiting."), user->pw_gid, strerror(errno));
    return NO;
  }
  if (setuid(user->pw_uid) != 0) {
    NSLog(_(@"Unable to set the user's UID (%d): %s. Exiting."), user->pw_uid, strerror(errno));
    return NO;
  }

  // --- Beyond this line code will be executed with user credetials

  // Create user GNUstep directory in /tmp.
  [[NSFileManager defaultManager]
      createDirectoryAtPath:[NSString stringWithFormat:@"/tmp/GNUstepSecure%d", user->pw_uid]
                 attributes:@{@"NSFilePosixPermissions" : [NSNumber numberWithShort:0700]}];

  // General environment variables
  setenv("USER", user->pw_name, 1);
  setenv("LOGNAME", user->pw_name, 1);
  setenv("HOME", user->pw_dir, 1);
  setenv("SHELL", user->pw_shell, 1);
  setenv("LC_CTYPE", "en_US.UTF-8", 1);
  setenv("DISPLAY", ":0", 1);

  setenv(
      "PATH",
      [[NSString
          stringWithFormat:@"/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin:%s",
                           getenv("PATH")] cString],
      1);
  setenv("LD_LIBRARY_PATH",
         [[NSString stringWithFormat:@"%s/Library/Libraries", user->pw_dir] cString], 1);
  setenv("GNUSTEP_PATHLIST",
         [[NSString stringWithFormat:@"%s:/:/usr/NextSpace:/Network", user->pw_dir] cString], 1);

  setenv("INFOPATH",
         [[NSString stringWithFormat:@"%s/Library/Documentation/info:/Library/Documentation/info:/"
                                     @"usr/NextSpace/Documentation/info",
                                     user->pw_dir] cString],
         1);
  // setenv("FREETYPE_PROPERTIES", "truetype:interpreter-version=35", 1);

  // For developers
  setenv("GNUSTEP_MAKEFILES", "/Developer/Makefiles", 1);

  // For CoreFoundation dynamic loading of CFNetwork
  setenv("CFNETWORK_LIBRARY_PATH", "/usr/NextSpace/lib/libCFNetwork.so", 1);

  // [self _setupSessionLog];
  setenv("NS_LOGFILE", [_sessionLog cString], 1);

  return YES;
}

- (void)dealloc
{
  NSLog(@"UserSession: dealloc");

  NSLog(@"userName: %lu", [_userName retainCount]);
  NSLog(@"sessionScript: %lu", [sessionScript retainCount]);

  [_userName release];      // retained by 'copy' in setSessionName:
  [sessionScript release];  // retained by 'copy' in setSessionScript:
  [_sessionLog release];

  NSLog(@"UserSession: dealloc end");

  [super dealloc];
}
- (id)initWithOwner:(Controller *)controller name:(NSString *)name defaults:(NSDictionary *)defaults
{
  self = [super init];
  if (self == nil) {
    return nil;
  }

  appController = controller;
  appDefaults = defaults;
  _exitStatus = 0;

  _userName = [[NSString alloc] initWithString:name];

  // _sessionLog = [self _sessionLogPath];
  _sessionLog = [[NSString alloc]
      initWithFormat:@"/tmp/GNUstepSecure%u/console.log", getpwnam([_userName cString])->pw_uid];

  return self;
}

- (int)launchCommand:(NSArray *)command logAppend:(BOOL)append wait:(BOOL)isWait
{
  const char *executable = NULL;
  int ac = [command count];
  const char *args[ac + 1];
  int i;
  int pid = 0;
  int status = 0;

  executable = [[command objectAtIndex:0] fileSystemRepresentation];
  args[0] = executable;

  for (i = 1; i < ac; i++) {
    args[i] = [[command objectAtIndex:i] cString];
  }
  args[ac] = NULL;

  // Without this call waitpid() looses forked child process.
  signal(SIGCHLD, SIG_DFL);

  pid = fork();
  switch (pid) {
    case 0: {
      fprintf(stderr, "[fork] Executing %s\n", executable);
      if ([self _setUserEnvironment] == YES) {
        if (append) {
          freopen(getenv("NS_LOGFILE"), "a", stderr);
          freopen(getenv("NS_LOGFILE"), "a", stdout);
        } else {
          freopen(getenv("NS_LOGFILE"), "w+", stderr);
          freopen(getenv("NS_LOGFILE"), "w+", stdout);
        }
        status = execv(executable, (char **)args);
      }
      // If forked process goes here - something went wrong: aborting.
      fprintf(stderr, "[fork] 'execv' returned error %i (%i:%s). Aborting.\n", status, errno,
              strerror(errno));
      abort();
    } break;
    default: {
      if (isWait == NO)
        break;

      // Wait for command to finish launching
      fprintf(stderr, "[launchCommand] Waiting for PID: %i\n", pid);

      while (waitpid(pid, &status, 0) == -1) {
        if (errno == EINTR) {
          printf("[laucnCommand] Parent interrrupted - restarting...\n");
          continue;
        } else {
          perror("[launchCommand] waitpid() failed");
          status = 1;
        }
      }

      if (WIFEXITED(status)) {
        fprintf(stderr, "[launchCommand] %s EXITED with code %d(%d)\n", executable,
                WEXITSTATUS(status), status);
        status = WEXITSTATUS(status);
      } else if (WIFSIGNALED(status)) {
        fprintf(stderr, "[launchCommand] %s KILLED with signal %d", executable, WTERMSIG(status));
        if (WCOREDUMP(status)) {
          fprintf(stderr, " (CORE DUMPED)\n");
        } else {
          fprintf(stderr, "\n");
        }
        status = WTERMSIG(status);
      } else if (WIFSTOPPED(status)) {
        fprintf(stderr, "[launchCommand] %s is STOPPED\n", executable);
        status = 0;
      } else {
        fprintf(stderr, "[launchCommand] %s finished with exit code %i\n", executable, status);
        status = 0;
      }
    } break;
  }

  return status;
}

- (void)setRunning:(NSNumber *)isRunning
{
  NSLog(@"isRunning = %@", isRunning);
  self.isRunning = [isRunning boolValue];
}

@end

@implementation UserSession (ScriptLaunch)

- (void)readSessionScript
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *homeDir = NSHomeDirectoryForUser(_userName);
  NSString *pathFormat;
  NSString *defaultsPath;
  NSDictionary *userDefaults;
  NSString *hook;

  sessionScript = [NSMutableArray new];
  pathFormat = @"%@/Library/Preferences/.NextSpace/Login";
  defaultsPath = [NSString stringWithFormat:pathFormat, homeDir];
  if ([fm fileExistsAtPath:defaultsPath] == NO) {
    [fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"Login" ofType:@"user"]
                toPath:defaultsPath
                 error:0];
    [fm changeFileAttributes:@{NSFileOwnerAccountName : _userName} atPath:defaultsPath];
  }
  userDefaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];

  // Login hook
  if ((hook = [userDefaults objectForKey:@"LoginHook"]) != nil) {
    [sessionScript addObject:hook];
  }

  // Session script
  [sessionScript addObjectsFromArray:[userDefaults objectForKey:@"SessionScript"]];

  // Try system session script
  if (sessionScript == nil || [sessionScript count] == 0) {
    NSLog(@"Using DefaultSessionScript...");
    [sessionScript addObjectsFromArray:[appDefaults objectForKey:@"DefaultSessionScript"]];
  }

  // Logout hook
  if ((hook = [userDefaults objectForKey:@"LogoutHook"]) != nil) {
    [sessionScript addObject:hook];
  }
}

// Starts:
// 1. LoginHook (~/L/P/.N/Login)
// 2. sessionScript
// 3. LogoutHook (~/L/P/.N/Login)
- (void)launchSessionScript
{
  int ret;
  BOOL firstCommand = YES;

  NSLog(@"launchSession: %@", sessionScript);

  _exitStatus = 0;
  // self.isRunning = YES;
  [self performSelectorOnMainThread:@selector(setRunning:)
                         withObject:[NSNumber numberWithBool:YES]
                      waitUntilDone:YES];

  for (id scriptCommand in sessionScript) {
    if (scriptCommand == nil ||
        ([scriptCommand isKindOfClass:[NSArray class]] != NO && [scriptCommand count] == 0)) {
      continue;
    }
    if ([scriptCommand isKindOfClass:[NSString class]] != NO) {
      if ([scriptCommand isEqualToString:@""])
        continue;
      scriptCommand = [scriptCommand componentsSeparatedByString:@" "];
    } else {
      NSString *command;
      command = [scriptCommand objectAtIndex:0];
      if (command == nil || [command isEqualToString:@""])
        continue;
      NSLog(@"SESSION: %@", scriptCommand);
    }

    ret = [self launchCommand:scriptCommand logAppend:!firstCommand wait:YES];
    if (firstCommand != NO) {
      firstCommand = NO;
    }
    // If any of the command in session script finished with error
    // we should leave info for the Controller.
    _exitStatus |= (NSInteger)ret;

    if (ret == SIGABRT) {
      NSLog(@"Command %@ was aborted (SIGABRT). Interrupting session script launch sequence...",
            scriptCommand);
      break;
    }
  }

  // self.isRunning = NO;
  // Session is running on cuncurrent thread. Change ivar value on main thread for KVO code.
  [self performSelectorOnMainThread:@selector(setRunning:)
                         withObject:[NSNumber numberWithBool:NO]
                      waitUntilDone:YES];
}

@end
