/*
  Copyright (C) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>

#import "TerminalServices.h"

// #include "ServicesParameterWindowController.h"

#import "TerminalWindow.h"
#import "TerminalView.h"
#import "Controller.h"

@implementation TerminalServices

+ (NSDictionary *)terminalServicesDictionary
{
  NSDictionary *d;
  NSString     *dPath;

  d = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey:@"TerminalServices"];
  if (d)
    return d;

  dPath = [[NSBundle mainBundle] pathForResource:@"DefaultTerminalServices"
                                         ofType:@"svcs"];
  d = [[NSDictionary dictionaryWithContentsOfFile:dPath]
        objectForKey:@"TerminalServices"];
  return d;
}

+ (void)updateServicesPlist
{
  NSMutableArray *a = [[NSMutableArray alloc] init];
  NSDictionary   *d = [TerminalServices terminalServicesDictionary];
  NSEnumerator   *e;
  NSString       *name;

  e = [d keyEnumerator];
  while ((name = [e nextObject]))
    {
      int i;
      NSString *key;
      NSMutableDictionary *md;
      NSDictionary *info;
      NSArray *types;
      NSString *menu_name;

      info = [d objectForKey:name];

      md = [[NSMutableDictionary alloc] init];
      [md setObject:@"Terminal" forKey:@"NSPortName"];
      [md setObject:@"terminalService" forKey:@"NSMessage"];
      [md setObject:name forKey:@"NSUserData"];

      // Services menu item in format "Terminal/Service Name"
      if ([name characterAtIndex:0] == '/')
        menu_name = [name substringFromIndex:1];
      else
        menu_name = [NSString stringWithFormat:@"%@/%@",@"Terminal",name];
      [md setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    menu_name,
                                  @"default",nil]
             forKey: @"NSMenuItem"];

      // Key equivavelnt
      key = [info objectForKey:Key];
      if (key && [key length])
        {
          [md setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                         key,@"default",nil]
                 forKey: @"NSKeyEquivalent"];
        }

      // "Accept" block
      if ([info objectForKey:AcceptTypes])
        i = [[info objectForKey:AcceptTypes] intValue];
      else
        i = ACCEPT_STRING;
      
      if (i == (ACCEPT_STRING | ACCEPT_FILENAMES))
        types = [NSArray arrayWithObjects:NSStringPboardType,NSFilenamesPboardType,nil];
      else if (i == ACCEPT_FILENAMES)
        types = [NSArray arrayWithObjects:NSFilenamesPboardType,nil];
      else if (i == ACCEPT_STRING)
        types = [NSArray arrayWithObjects:NSStringPboardType,nil];
      else
        types = nil;

      // "Use Selection" block
      i = [[info objectForKey:Input] intValue];
      if (types && (i == INPUT_STDIN || i ==  INPUT_CMDLINE))
        [md setObject:types forKey:@"NSSendTypes"];

      // "Execution" block
      i = [[info objectForKey:Type] intValue];
      if (i == TYPE_BACKGROUND)
        {
          i = [[info objectForKey:ReturnData] intValue];
          if (types && i==1)
            [md setObject:types forKey:@"NSReturnTypes"];
        }

      [a addObject:md];
      DESTROY(md);
    }

  {
    NSString *path;

    path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                NSUserDomainMask, YES)
                                               lastObject];
    path = [path stringByAppendingPathComponent:@"Services"];
    path = [path stringByAppendingPathComponent:@"TerminalServices.plist"];

    d = [NSDictionary dictionaryWithObject:a forKey:@"NSServices"];
    [d writeToFile:path atomically:YES];
  }

  /* TODO: if a submenu of services is 'held' open when services are
     reloaded, -gui crashes */

  [[NSWorkspace sharedWorkspace] findApplications];
}

- (NSDictionary *)_serviceInfoForName:(NSString *)name
{
  NSDictionary *d;
  
  d = [[TerminalServices terminalServicesDictionary] objectForKey:name];
  
  if (!d || ![d isKindOfClass:[NSDictionary class]])
    return nil;
  
  return d;
}

- (void)terminalService:(NSPasteboard *)pb
               userData:(NSString *)name
                  error:(NSString **)error
{
  NSDictionary *info = [self _serviceInfoForName:name];

  int type, input, ret_data, accepttypes, shell;
  NSString *cmdline;
  NSString *data;
  NSString *program;
  NSArray  *arguments;

  NSDebugLLog(@"service",@"run service %@\n",name);
  if (!info)
    {
      NSString *s =
        _(@"There is no terminal service called '%@'.\n"
          @"Your services list is probably out-of-date.\n"
          @"Run 'make_services' to update it.");

      *error=[[NSString stringWithFormat: s, name] retain];
      return;
    }

  // Extract fields from service info
  type = [[info objectForKey:Type] intValue];
  ret_data = [[info objectForKey:ReturnData] intValue];
  input = [[info objectForKey:Input] intValue];
  cmdline=[info objectForKey:Commandline];
  if ([info objectForKey:AcceptTypes])
    accepttypes = [[info objectForKey:AcceptTypes] intValue];
  else
    accepttypes = ACCEPT_STRING;
  shell = [[info objectForKey:ExecuteInShell] intValue];

  NSDebugLLog(@"service",@"cmdline='%@' %i %i %i %i",
              cmdline,type,ret_data,input,accepttypes);

  // "Accept"
  data = nil;
  if (input && accepttypes&ACCEPT_STRING &&
      (data = [pb stringForType:NSStringPboardType]))
    {
    }
  else if (input && accepttypes&ACCEPT_FILENAMES &&
           (data = [pb propertyListForType:NSFilenamesPboardType]))
    {
      NSDebugLLog(@"service",@"got filenames '%@' '%@' %i",
                  data,[data class],[data isProxy]);
    }

  NSDebugLLog(@"service",@"got data '%@'",data);

  // "Selection"
  if (input == INPUT_STDIN)
    {
      if ([data isKindOfClass:[NSArray class]])
        data = [(NSArray *)data componentsJoinedByString:@"\n"];
    }
  else if (input == INPUT_CMDLINE)
    {
      if (data && [data isKindOfClass:[NSArray class]])
        data = [(NSArray *)data componentsJoinedByString:@" "];
    }

  // Process 'Command' service parameter
  {
    int i;
    BOOL add_args;
    NSMutableString *str = [cmdline mutableCopy];
    unichar ch;
    int p_pos;

    add_args = YES;
    p_pos = -1;
    for (i = 0;i < [str length]-1; i++)
      {
        ch = [str characterAtIndex:i];
        if (ch != '%')
          continue;
        ch = [str characterAtIndex:i+1];
        if (ch == '%')
          {
            [str replaceCharactersInRange:NSMakeRange(i,1)
                               withString:@""];
            continue;
          }
        if (ch == 's' && data && input==2)
          {
            add_args = NO;
            [str replaceCharactersInRange:NSMakeRange(i,2)
                               withString:data];
            i += [data length];
            continue;
          }
        if (ch == 'p')
          {
            p_pos = i;
            continue;
          }
      }

    if (input == INPUT_CMDLINE && data && add_args)
      {
        [str appendString:@" "];
        [str appendString:data];
      }
    cmdline = [str autorelease];

    // if (p_pos!=-1)
    //   {
    //     cmdline = [TerminalServicesParameterWindowController
    //     			getCommandlineFrom:cmdline
    //                                    selectRange:NSMakeRange(p_pos,2)
    //                                        service:name];
    //     if (!cmdline)
    //       {
    //         *error=[_(@"Service aborted by user.") retain];
    //         return;
    //       }
    //   }
    
    // No Shell/Default shell
    if (shell)
      {
        program = @"/bin/sh";
        arguments = [NSArray arrayWithObjects:@"-c",cmdline,nil];
      }
    else
      {
        NSMutableArray *args;

        args = [[cmdline componentsSeparatedByString:@" "] mutableCopy];
        program = [[args objectAtIndex:0] copy];
        [args removeObjectAtIndex:0];
        arguments = [args copy];
        
        [args autorelease];
        [program autorelease];
      }
  }

  NSDebugLLog(@"service",@"final command line='%@'",cmdline);

  // "Exectute" type
  switch (type)
    {
    case TYPE_BACKGROUND:
      {
        NSTask *t = [[[NSTask alloc] init] autorelease];
        NSPipe *sin,*sout;
        NSFileHandle *in,*out;

        [t setLaunchPath:program];
        [t setArguments:arguments];

        NSDebugLLog(@"service",@"t=%@",t);

        sin = [[[NSPipe alloc] init] autorelease];
        [t setStandardInput:sin];
        in = [sin fileHandleForWriting];
        sout = [[[NSPipe alloc] init] autorelease];
        [t setStandardOutput:sout];
        out = [sout fileHandleForReading];

        NSDebugLLog(@"service",@"launching");
        [t launch];

        if (data && input==INPUT_STDIN)
          {
            NSDebugLLog(@"service",@"writing data");
            [in writeData: [data dataUsingEncoding: NSUTF8StringEncoding]];
          }
        [in closeFile];

        // NSDebugLLog(@"service",@"waitUntilExit");
        // [t waitUntilExit];

        if (ret_data)
          {
            NSString *s;
            NSData *result;
            NSDebugLLog(@"service",@"get result");
            result = [out readDataToEndOfFile];
            NSDebugLLog(@"service",@"got data |%@|",result);
            s = [[NSString alloc] initWithData:result
                                      encoding:NSUTF8StringEncoding];
            s = [s autorelease];
            NSDebugLLog(@"service",@"= '%@'",s);

            if (accepttypes == (ACCEPT_STRING|ACCEPT_FILENAMES))
              [pb declareTypes:[NSArray arrayWithObjects:
                                          NSStringPboardType,
                                        NSFilenamesPboardType,nil]
                         owner:self];
            else if (accepttypes == ACCEPT_FILENAMES)
              [pb declareTypes:[NSArray arrayWithObjects:
                                          NSFilenamesPboardType,nil]
                         owner:self];
            else if (accepttypes == ACCEPT_STRING)
              [pb declareTypes:[NSArray arrayWithObjects:
                                          NSStringPboardType,nil]
                         owner:self];

            if (accepttypes&ACCEPT_FILENAMES)
              {
                NSMutableArray *ma = [[[NSMutableArray alloc] init] autorelease];
                int i, c = [s length];
                NSRange cur;

                for (i=0;i<c;)
                  {
                    for (;i<c && [s characterAtIndex: i]<=32;i++) ;
                    if (i==c)
                      break;
                    cur.location=i;
                    for (;i<c && [s characterAtIndex: i]>32;i++) ;
                    cur.length=i-cur.location;
                    [ma addObject: [s substringWithRange: cur]];
                  }

                NSDebugLLog(@"service",@"returning filenames: %@",ma);
                [pb setPropertyList:ma forType:NSFilenamesPboardType];
              }

            if (accepttypes&ACCEPT_STRING)
              [pb setString:s forType:NSStringPboardType];

            NSDebugLLog(@"service",@"return is set");
          }
        else
          {
            NSDebugLLog(@"service",@"ignoring output");
            [out closeFile];
            [t waitUntilExit];
          }

        NSDebugLLog(@"service",@"clean up");
      }
      break;


    case TYPE_WINDOW_IDLE:
    case TYPE_WINDOW_NEW:
      {
        TerminalWindowController *twc = nil;

        // if (type == TYPE_WINDOW_IDLE)
        //   {
        //     twc = [[NSApp delegate] idleTerminalWindow];
        //     [twc showWindow:self];
        //   }
        // if (!twc)
        //   {
        //     twc = [[NSApp delegate] newWindow];
        //     [twc showWindow:self];
        //   }

        NSDebugLLog(@"service",@"got window %@",twc);

        // [[twc terminalView] runProgram:program
        //                  withArguments:arguments
        //                   initialInput:input == INPUT_STDIN ? data : nil];
        twc = [[NSApp delegate]
                newWindowWithProgram:program
                           arguments:arguments
                               input:input == INPUT_STDIN ? data : nil];
        [twc showWindow:self];
      }
      break;

    }
  NSDebugLLog(@"service",@"return");
}


@end

