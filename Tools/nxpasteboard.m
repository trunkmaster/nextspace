/* Copyright (C) 2020 Free Software Foundation, Inc.

   Written by:  onflapp
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

void printUsage() {
  fprintf(stderr, "Usage: nxpasteboard [--copy] [--paste] [--service <name>]\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Help: gives you copy&paste and system services from command line\n");
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  --copy            copy text from standard input to the pasteboard\n");
  fprintf(stderr, "  --paste           paste text from the pasteboard to standard output\n");
  fprintf(stderr, "  --service <name>  call service with text from standard input\n");
  fprintf(stderr, "\n");
}

int main(int argc, char** argv, char** env) {
  
  NSProcessInfo *pInfo;
  NSArray *arguments;
  CREATE_AUTORELEASE_POOL(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env_c];
#endif

  pInfo = [NSProcessInfo processInfo];
  arguments = [pInfo arguments];
  int rv = 1;

  @try {
    if ([arguments count] == 1)  {
      printUsage();
      rv = 1;
    }
    else if ([arguments containsObject: @"--copy"] == YES) {
      NSFileHandle *sin = [NSFileHandle fileHandleWithStandardInput];
      NSData* data = [sin readDataToEndOfFile];
      if ([data length] > 0) {
        NSString* str = [[NSString alloc ]initWithData:data encoding:NSUTF8StringEncoding];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
        [pboard setString:str forType:NSPasteboardTypeString];
        rv = EXIT_SUCCESS;
      }
      else {
        rv = 4;
      }
    }
    else if ([arguments containsObject: @"--service"] == YES) {
      //suppress NSLog from NSApplication
      fclose(stderr);

      //register service types, this will refresh the service manager
      id app = [NSApplication sharedApplication]; 
      [app registerServicesMenuSendTypes:[NSArray arrayWithObject:NSPasteboardTypeString] 
                             returnTypes:[NSArray arrayWithObject:NSPasteboardTypeString]];

      NSFileHandle *sin = [NSFileHandle fileHandleWithStandardInput];
      NSData* data = [sin readDataToEndOfFile];
      if ([data length] > 0) {
        NSString* serviceMenu = [arguments objectAtIndex:2];
        NSString* str = [[NSString alloc ]initWithData:data encoding:NSUTF8StringEncoding];
        NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
        [pboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
        [pboard setString:str forType:NSPasteboardTypeString];

        BOOL done = NSPerformService(serviceMenu, pboard);
        
        if (done) {
          str = [pboard stringForType:NSPasteboardTypeString];
          if (str) {
            printf("%s", [str UTF8String]);
          }
          rv = EXIT_SUCCESS;
        }
        else {
          rv = 4;
        }
      }
      else {
        rv = 4;
      }
    }
    else if ([arguments containsObject: @"--paste"] == YES) {
      NSPasteboard *pboard = [NSPasteboard generalPasteboard];
      NSString* str = [pboard stringForType:NSPasteboardTypeString];
      if (str) {
        printf("%s", [str UTF8String]);
        rv = EXIT_SUCCESS;
      }
      else {
        rv = 4;
      }
    }
    else {
      printUsage();
      rv = 1;
    }
  }
  @catch (NSException* ex) {
    NSLog(@"exception %@", ex);
    printUsage();
    rv = 6;
  }

  RELEASE(pool);

  exit(rv);
}

