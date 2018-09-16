/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <NXAppKit/NXAlert.h>
#import "Launcher.h"

@implementation Launcher

static Launcher *shared = nil;

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }

  return shared;
}

- (void)dealloc
{
  NSDebugLLog(@"Launcher", @"Launcher: dealloc");

  [super dealloc];
}

- init
{
  [super init];

  ASSIGN(savedString, @"");

  return self;
}

- (void)awakeFromNib
{
  [commandName setStringValue:savedString];
  DESTROY(savedString);

  [window setFrameAutosaveName:@"Launcher"];
}

- (void)activate
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"Launcher" owner:self];
  }

  [commandName selectText:nil];
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (void)runCommand:(id)sender
{
  NSString       *commandPath = nil;
  NSMutableArray *commandArgs = nil;
  NSTask         *commandTask = nil;

  commandArgs = [NSMutableArray 
    arrayWithArray:[[commandName stringValue] componentsSeparatedByString:@" "]];
  commandPath = [commandArgs objectAtIndex:0];
  [commandArgs removeObjectAtIndex:0];

  NSLog(@"Running command: %@ with args %@", commandPath, commandArgs);
  
  commandTask = [NSTask new];
  [commandTask setArguments:commandArgs];
  [commandTask setLaunchPath:commandPath];
//  [commandTask setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];
//  [commandTask setStandardError:[NSFileHandle fileHandleWithStandardError]];
//  [commandTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
/*  [commandTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
  [commandTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [commandTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];*/
  NS_DURING {
    [commandTask launch];
  }
  NS_HANDLER {
    NXRunAlertPanel(@"Run Command",
                    @"Run command failed with exception: \'%@\'", 
                    @"Close", nil, nil,
                    [localException reason]);
  }
  NS_ENDHANDLER

  DESTROY(savedString);
  ASSIGN(savedString, [commandName stringValue]);
  [window close];
}

@end
