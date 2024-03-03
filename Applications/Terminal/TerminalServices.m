/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>
#import <DesktopKit/NXTAlert.h>

#import "TerminalServices.h"

#import "TerminalWindow.h"
#import "TerminalView.h"
#import "Controller.h"

static NSDictionary *servicesDictionary = nil;

@implementation TerminalServices

+ (NSDictionary *)terminalServicesDictionary
{
  NSDictionary *udServices;

  udServices = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TerminalServices"];
  if (udServices == nil && servicesDictionary == nil) {  // no defs, no decision
    if (NXTRunAlertPanel(@"Terminal Services",
                         @"No services are define. "
                         @"Would you like to load a set of example services?",
                         @"Load Examples", @"Don't Load", nil) == NSOKButton) {
      NSString *dPath = [[NSBundle mainBundle] pathForResource:@"ExampleServices" ofType:@"svcs"];
      servicesDictionary = [[[NSDictionary dictionaryWithContentsOfFile:dPath]
          objectForKey:@"TerminalServices"] copy];
    } else {
      servicesDictionary = [[NSDictionary alloc] init];
    }
  } else if (udServices != nil) {  // there are defs, no decision
    ASSIGN(servicesDictionary, udServices);
  } else if (servicesDictionary != nil) {  // no defs, decision was made
    // just return 'servicesDictionary'
  }

  return servicesDictionary;
}

+ (NSString *)serviceDirectory
{
  NSArray *searchPaths;
  NSString *path;

  searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  path = [[searchPaths lastObject] stringByAppendingPathComponent:@"Services"];

  return path;
}

+ (NSDictionary *)plistForServiceNames:(NSArray *)services
{
  NSMutableArray *a = [[NSMutableArray alloc] init];
  NSDictionary *d = [TerminalServices terminalServicesDictionary];

  if (!services) {
    services = [d allKeys];
  }
  for (NSString *name in services) {
    NSMutableDictionary *md;
    NSDictionary *info;
    NSString *menu_name;
    NSString *key;
    int i;
    NSArray *types;

    info = [d objectForKey:name];

    md = [[NSMutableDictionary alloc] init];
    [md setObject:@"Terminal" forKey:@"NSPortName"];
    [md setObject:@"terminalService" forKey:@"NSMessage"];
    [md setObject:name forKey:@"NSUserData"];

    // Services menu item in format "Terminal/Service Name"
    if ([name characterAtIndex:0] == '/') {
      menu_name = [name substringFromIndex:1];
    } else {
      menu_name = [NSString stringWithFormat:@"%@/%@", @"Terminal", name];
    }
    [md setObject:@{@"default" : menu_name} forKey:@"NSMenuItem"];

    // Key equivalent
    key = [info objectForKey:Key];
    if (key && [key length]) {
      [md setObject:@{@"default" : key} forKey:@"NSKeyEquivalent"];
    }

    // "Accept" block
    if ([info objectForKey:AcceptTypes]) {
      i = [[info objectForKey:AcceptTypes] intValue];
    } else {
      i = ACCEPT_STRING;
    }

    if (i == (ACCEPT_STRING | ACCEPT_FILENAMES)) {
      types = [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil];
    } else if (i == ACCEPT_FILENAMES) {
      types = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
    } else if (i == ACCEPT_STRING) {
      types = [NSArray arrayWithObjects:NSStringPboardType, nil];
    } else {
      types = nil;
    }

    // "Use Selection" block
    i = [[info objectForKey:Input] intValue];
    // Do not insert 'NSSendTypes' key if 'Use Selection - On Cmd Line'
    // option was set and command line doesn't have '%s' symbol.
    if ([[info objectForKey:Commandline] rangeOfString:@"%s"].location == NSNotFound &&
        i == INPUT_CMDLINE) {
      i = INPUT_NO;
    }
    if (types && (i == INPUT_STDIN || i == INPUT_CMDLINE)) {
      [md setObject:types forKey:@"NSSendTypes"];
    }

    // "Execution" block
    i = [[info objectForKey:ExecType] intValue];
    if (i == EXEC_IN_BACKGROUND) {
      i = [[info objectForKey:ReturnData] intValue];
      if (types && i == 1) {
        [md setObject:types forKey:@"NSReturnTypes"];
      }
    }

    if (![md objectForKey:@"NSSendTypes"] && ![md objectForKey:@"NSReturnTypes"]) {
      NXTRunAlertPanel(@"Terminal Services",
                       @"Service with name '%@' has neither Send nor"
                        " Return values. Please specify '%%s' as command"
                        " parameter or 'Return Output' in 'Execution' block. "
                        "Services file was not saved.",
                       @"OK", nil, nil, name);
      DESTROY(md);
      DESTROY(a);
      return nil;
    }

    [a addObject:md];
    DESTROY(md);
  }

  return [NSDictionary dictionaryWithObject:[a autorelease] forKey:@"NSServices"];
}

+ (void)updateServicesPlist
{
  NSString *path = [[TerminalServices serviceDirectory]
      stringByAppendingPathComponent:@"TerminalServices.plist"];

  [[TerminalServices plistForServiceNames:nil] writeToFile:path atomically:YES];

  /* TODO: if a submenu of services is 'held' open when services are
     reloaded, -gui crashes */
  [[NSWorkspace sharedWorkspace] findApplications];
}

- (NSDictionary *)_serviceInfoForName:(NSString *)name
{
  NSDictionary *d = [[TerminalServices terminalServicesDictionary] objectForKey:name];

  if (!d || ![d isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  return d;
}

- (void)terminalService:(NSPasteboard *)pb userData:(NSString *)name error:(NSString **)error
{
  NSDictionary *info = [self _serviceInfoForName:name];

  int type, input, ret_data, accepttypes, shell;
  NSString *cmdline;
  NSString *data;
  NSString *program;
  NSArray *arguments;

  NSDebugLLog(@"service", @"run service %@\n", name);
  if (!info) {
    NSString *s = _(@"There is no terminal service called '%@'.\n"
                    @"Your services list is probably out-of-date.\n"
                    @"Run 'make_services' to update it.");

    *error = [[NSString stringWithFormat:s, name] retain];
    return;
  }

  // Extract fields from service info
  type = [[info objectForKey:ExecType] intValue];
  ret_data = [[info objectForKey:ReturnData] intValue];
  input = [[info objectForKey:Input] intValue];
  cmdline = [info objectForKey:Commandline];
  if ([info objectForKey:AcceptTypes]) {
    accepttypes = [[info objectForKey:AcceptTypes] intValue];
  } else {
    accepttypes = ACCEPT_STRING;
  }
  shell = [[info objectForKey:ExecInShell] intValue];

  NSDebugLLog(@"service", @"cmdline='%@' %i %i %i %i", cmdline, type, ret_data, input, accepttypes);

  // "Accept"
  data = nil;
  NSLog(@"NSStringPboardType: %@", [pb stringForType:NSStringPboardType]);
  if (input && (accepttypes & ACCEPT_STRING) && (data = [pb stringForType:NSStringPboardType])) {
    NSLog(@"Got NSStringPboardType");
  } else if (input && (accepttypes & ACCEPT_FILENAMES) &&
             (data = [pb propertyListForType:NSFilenamesPboardType])) {
    NSDebugLLog(@"service", @"got filenames '%@' '%@' %i", data, [data class], [data isProxy]);
    NSLog(@"Got NSFilenamesPboardType");
  }

  NSDebugLLog(@"service", @"got data '%@'", data);

  // "Selection"
  if (input == INPUT_STDIN) {
    if ([data isKindOfClass:[NSArray class]])
      data = [(NSArray *)data componentsJoinedByString:@"\n"];
  } else if (input == INPUT_CMDLINE) {
    if (data && [data isKindOfClass:[NSArray class]])
      data = [(NSArray *)data componentsJoinedByString:@" "];
  }
  NSLog(@"Services: got data: %@", data);

  // Process 'Command' service parameter
  {
    int i;
    BOOL add_args;
    NSMutableString *str = [cmdline mutableCopy];
    unichar ch;
    int p_pos;

    add_args = YES;
    p_pos = -1;
    for (i = 0; i < [str length] - 1; i++) {
      ch = [str characterAtIndex:i];
      if (ch != '%') {
        continue;
      }
      ch = [str characterAtIndex:i + 1];
      if (ch == '%') {
        [str replaceCharactersInRange:NSMakeRange(i, 1) withString:@""];
        continue;
      }
      if (ch == 's' && data && (input == 2)) {
        add_args = NO;
        [str replaceCharactersInRange:NSMakeRange(i, 2) withString:data];
        i += [data length];
        continue;
      }
      if (ch == 'p') {
        p_pos = i;
        continue;
      }
    }

    if (input == INPUT_CMDLINE && data && add_args) {
      [str appendString:@" "];
      [str appendString:data];
    }
    cmdline = [str autorelease];

    // "Add Arguments" panel will be shown
    if (p_pos != -1) {
      cmdline = [self getCommandlineFrom:cmdline selectRange:NSMakeRange(p_pos, 2) service:name];
      if (!cmdline) {
        *error = [_(@"Service aborted by user.") retain];
        return;
      }
    }

    NSLog(@"Services: got cmdline: %@", cmdline);

    // No Shell/Default shell
    if (shell) {
      program = [[Defaults shared] shell];
      program = [program stringByAppendingFormat:@" -c %@", cmdline];
      NSLog(@"Command line with default shell: %@", program);

      arguments = [program componentsSeparatedByString:@" "];
      program = [arguments objectAtIndex:0];
      arguments = [arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)];
    } else {
      NSMutableArray *args;

      args = [[cmdline componentsSeparatedByString:@" "] mutableCopy];
      program = [[args objectAtIndex:0] copy];
      [args removeObjectAtIndex:0];
      arguments = [args copy];

      [args autorelease];
      [program autorelease];
    }
  }

  NSDebugLLog(@"service", @"final command line='%@'", cmdline);

  // "Exectute" type
  switch (type) {
    case EXEC_IN_BACKGROUND: {
      NSTask *t = [[[NSTask alloc] init] autorelease];
      NSPipe *sin, *sout;
      NSFileHandle *in, *out;

      [t setLaunchPath:program];
      [t setArguments:arguments];

      NSDebugLLog(@"service", @"t=%@", t);

      sin = [[[NSPipe alloc] init] autorelease];
      [t setStandardInput:sin];
      in = [sin fileHandleForWriting];
      sout = [[[NSPipe alloc] init] autorelease];
      [t setStandardOutput:sout];
      out = [sout fileHandleForReading];

      NSDebugLLog(@"service", @"launching");
      [t launch];

      if (data && (input == INPUT_STDIN)) {
        NSDebugLLog(@"service", @"writing data");
        [in writeData:[data dataUsingEncoding:NSUTF8StringEncoding]];
      }
      [in closeFile];

      NSDebugLLog(@"service", @"waitUntilExit");
      [t waitUntilExit];

      if (ret_data) {
        NSString *s;
        NSData *result;

        NSDebugLLog(@"service", @"get result");
        result = [out readDataToEndOfFile];
        NSDebugLLog(@"service", @"got data |%@|", result);
        s = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        s = [s autorelease];
        NSDebugLLog(@"service", @"= '%@'", s);

        if (accepttypes == (ACCEPT_STRING | ACCEPT_FILENAMES)) {
          [pb declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]
                     owner:self];
        } else if (accepttypes == ACCEPT_FILENAMES) {
          [pb declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:self];
        } else if (accepttypes == ACCEPT_STRING) {
          [pb declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:self];
        }

        if (accepttypes & ACCEPT_FILENAMES) {
          NSMutableArray *ma = [[[NSMutableArray alloc] init] autorelease];
          int i, c = [s length];
          NSRange cur;

          for (i = 0; i < c;) {
            for (; i < c && [s characterAtIndex:i] <= 32; i++)
              ;
            if (i == c) {
              break;
            }
            cur.location = i;
            for (; i < c && [s characterAtIndex:i] > 32; i++)
              ;
            cur.length = i - cur.location;
            [ma addObject:[s substringWithRange:cur]];
          }

          NSDebugLLog(@"service", @"returning filenames: %@", ma);
          [pb setPropertyList:ma forType:NSFilenamesPboardType];
        }

        if (accepttypes & ACCEPT_STRING) {
          [pb setString:s forType:NSStringPboardType];
        }

        NSDebugLLog(@"service", @"return is set");
      } else {
        NSDebugLLog(@"service", @"ignoring output");
        [out closeFile];
        [t waitUntilExit];
      }

      NSDebugLLog(@"service", @"clean up");
    } break;
    case EXEC_IN_WINDOW: {
      TerminalWindowController *twc = nil;

      if ([[info objectForKey:WindowType] intValue] == WINDOW_IDLE) {
        twc = [[NSApp delegate] idleTerminalWindow];
        NSDebugLLog(@"service", @"got window %@", twc);
        if (twc) {
          [twc showWindow:self];
          [[twc terminalView] runProgram:program
                           withArguments:arguments
                            initialInput:input == INPUT_STDIN ? data : nil];
        } else {
          twc = [[NSApp delegate] newWindowWithProgram:program
                                             arguments:arguments
                                                 input:input == INPUT_STDIN ? data : nil];
          [twc showWindow:self];
        }
      } else {
        if (shell) {
          twc = [[NSApp delegate] newWindowWithShell];
          [[[twc terminalView] terminalParser]
              sendString:[NSString stringWithFormat:@"%@\n", cmdline]];
        } else {
          twc = [[NSApp delegate] newWindowWithProgram:program
                                             arguments:arguments
                                                 input:input == INPUT_STDIN ? data : nil];
        }
        [twc showWindow:self];
      }
    } break;
  }
  NSDebugLLog(@"service", @"return");
}

@end

@implementation TerminalServices (AddArguments)

- (NSString *)getCommandlineFrom:(NSString *)cmdline
                     selectRange:(NSRange)r
                         service:(NSString *)service_name
{
  NSString *s;
  int result;

  if (addArgsPanel == nil) {
    if ([NSBundle loadNibNamed:@"AddArguments" owner:self] == NO) {
      NSLog(@"Error loading NIB AddArguments");
      return nil;
    }
  }

  [commandField setStringValue:cmdline];
  [serviceNameField setStringValue:service_name];
  [addArgsPanel makeKeyAndOrderFront:self];
  if (r.length) {
    NSText *text = [addArgsPanel fieldEditor:NO forObject:commandField];
    // printf("t=%@ r=%@\n",[t text],NSStringFromRange(r));
    [text setSelectedRange:r];
  }

  result = [NSApp runModalForWindow:addArgsPanel];
  s = [commandField stringValue];
  [addArgsPanel close];

  if (result == NSRunStoppedResponse) {
    return s;
  } else {
    return nil;
  }
}

- (void)awakeFromNib
{
  [addArgsPanel setFrameAutosaveName:@"AddArgumentsPanel"];
  [addArgsPanel setDefaultButtonCell:[okBtn cell]];
}

- (void)cancel:(id)sender
{
  [NSApp stopModalWithCode:NSRunAbortedResponse];
}

- (void)ok:(id)sender
{
  [NSApp stopModalWithCode:NSRunStoppedResponse];
}

@end
