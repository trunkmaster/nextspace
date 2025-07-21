/* Copyright (C) 2020 Free Software Foundation, Inc.

   Written by: onflapp
   Created: September 2020

   This file is part of the NEXTSPACE Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

   */

#import	<AppKit/AppKit.h>

NSString* absolutePath(NSString* path) {
  if ([path isAbsolutePath]) return [path stringByStandardizingPath];
  else {
    NSFileManager* fm = [NSFileManager defaultManager];
    path = [[fm currentDirectoryPath] stringByAppendingPathComponent:path];
    return [path stringByStandardizingPath];
  }
}

void printUsage() {
  fprintf(stderr, "Usage: nxworkspace [--open <path> <app>] [--activate <app>]\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Help: invoke Workspace commands from command line\n");
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  --open <path>       open path in Workspace\n");
  fprintf(stderr, "  --open <path> <app> open path with specific application\n");
  fprintf(stderr, "  --activate <app>    launch or activate application\n");
  fprintf(stderr, "\n");
}

int main(int argc, char** argv, char** env)
{
  NSProcessInfo *pInfo;
  NSArray *arguments;
  CREATE_AUTORELEASE_POOL(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env_c];
#endif

  pInfo = [NSProcessInfo processInfo];
  arguments = [pInfo arguments];

  @try {
    if ([arguments count] == 1) {
      printUsage();
      exit(1);
    }
    else if ([[arguments objectAtIndex:1] isEqualToString:@"--open"] && [arguments count] >= 3 ) {
      NSWorkspace* ws = [NSWorkspace sharedWorkspace];
      NSString* path = absolutePath([arguments objectAtIndex:2]);
      NSString* app = ([arguments count] == 4)?[arguments objectAtIndex:3]:nil;

      [ws openFile:path withApplication:app];
    }
    else if ([[arguments objectAtIndex:1] isEqualToString:@"--activate"] && [arguments count] == 3) {
      NSWorkspace* ws = [NSWorkspace sharedWorkspace];
      NSString* app = [arguments objectAtIndex:2];

      [ws launchApplication:app];
    }
    else {
      printUsage();
      exit(1);
    }
  }
  @catch (NSException* ex) {
    NSLog(@"exception: %@", ex);
    printUsage();
    exit(6);
  }

  RELEASE(pool);

  exit(EXIT_SUCCESS);
}

