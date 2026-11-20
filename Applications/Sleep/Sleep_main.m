#import <AppKit/AppKit.h>
#import <X11/Xlib.h>
#import <X11/Xatom.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import "SleepView.h"
#include <time.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static BOOL autolaunched;
static NSArray *defaultCommand(void)
{
#ifdef __FreeBSD__
  return @[@"/usr/local/bin/doas", @"-n", @"/usr/sbin/zzz"];
#else
  return @[@"/usr/bin/systemctl", @"suspend"];
#endif
}
static NSTimeInterval monotonicTime(void)
{
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec / 1e9;
}

@interface SleepController : NSObject <RunLoopEvents>
{
  SleepView *view;
  NSPanel *panel;
  NSTextField *label;
  NSTimer *timer;
  NSTimeInterval deadline;
  BOOL counting;
  BOOL requestScheduled;
  BOOL showingError;
  NSInteger modalResult;
  NSTask *task;
  NSFileHandle *logHandle;
  NSString *logPath;
  Display *actionDisplay;
  Window actionWindow;
  Atom actionAtom;
}
- (void)begin:(id)sender;
- (void)requestSleep:(id)sender;
- (void)cancel:(id)sender;
- (void)finishCountdown:(NSInteger)result;
- (void)tick:(NSTimer *)sender;
- (void)finished:(NSNotification *)notification;
@end

@implementation SleepController
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  view = [[SleepView alloc] initWithFrame:NSMakeRect(0,0,64,64)];
  [view setTarget:self action:@selector(requestSleep:)];
  [[NSApp iconWindow] setContentView:view];
  [[NSApp iconWindow] setContentSize:NSMakeSize(64,64)];
  [[NSApp iconWindow] display];
  // A separate connection receives explicit Dock actions without stealing
  // events from AppKit or relying on a focusable document window.
  actionDisplay = XOpenDisplay(NULL);
  if (!actionDisplay) return;
  actionWindow = XCreateSimpleWindow(actionDisplay, DefaultRootWindow(actionDisplay), 0,0,1,1,0,0,0);
  actionAtom = XInternAtom(actionDisplay, "_NEXTSPACE_DOCK_ACTION", False);
  XSync(actionDisplay, False);
  for (NSString *mode in @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode])
    [[NSRunLoop currentRunLoop] addEvent:(void *)(intptr_t)ConnectionNumber(actionDisplay)
      type:ET_RDESC watcher:self forMode:mode];
  GSDisplayServer *server = GSCurrentServer();
  Display *display = [server serverDevice];
  Window icon = (Window)[server windowDevice:[[NSApp iconWindow] windowNumber]];
  XChangeProperty(display, icon, XInternAtom(display, "_NEXTSPACE_DOCK_ACTION_WINDOW", False),
    XA_WINDOW, 32, PropModeReplace, (unsigned char *)&actionWindow, 1);
  XFlush(display);
  if (!autolaunched) [self requestSleep:nil];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible
{
  [self requestSleep:nil];
  return NO;
}
- (void)receivedEvent:(void *)data type:(RunLoopEventType)type extra:(void *)extra forMode:(NSString *)mode
{
  while (XPending(actionDisplay)) {
    XEvent event;
    XNextEvent(actionDisplay, &event);
    if (event.type == ClientMessage && event.xclient.window == actionWindow &&
        event.xclient.message_type == actionAtom && event.xclient.format == 32)
      [self requestSleep:nil];
  }
}
- (void)requestSleep:(id)sender
{
  if (counting || task || requestScheduled || showingError ||
      (panel && [NSApp modalWindow] == panel)) return;
  // Coalesce launch and activation notifications before entering a modal loop.
  requestScheduled = YES;
  [self performSelector:@selector(begin:) withObject:nil afterDelay:0];
}
- (NSTextField *)text:(NSString *)string frame:(NSRect)frame
{
  NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
  [field setStringValue:string]; [field setEditable:NO]; [field setSelectable:NO];
  [field setBezeled:NO]; [field setDrawsBackground:NO];
  [field setAlignment:NSCenterTextAlignment];
  return field;
}
- (void)cancel:(id)sender
{
  if (counting) [self finishCountdown:NSCancelButton];
}
- (void)finishCountdown:(NSInteger)result
{
  NSLog(@"Sleep: ending countdown with result %ld", (long)result);
  counting = NO;
  modalResult = result;
  [timer invalidate];
}
- (BOOL)windowShouldClose:(id)sender { [self cancel:nil]; return NO; }
- (void)tick:(NSTimer *)sender
{
  NSTimeInterval remaining = deadline - monotonicTime();
  if (counting && remaining <= 0) {
    [self finishCountdown:NSOKButton];
  } else {
    [label setStringValue:[NSString stringWithFormat:@"Sleeping in %ld…", (long)ceil(MAX(0,remaining))]];
  }
}
- (void)begin:(id)sender
{
  requestScheduled = NO;
  if (counting) { [panel makeKeyAndOrderFront:nil]; return; }
  if (task) return; // One outstanding command, including across suspend/resume.
  // Keep command configuration separate from AppKit's cached Sleep defaults.
  NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/SleepWidget.plist"];
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  NSDictionary *settings = exists ? [NSDictionary dictionaryWithContentsOfFile:path] : @{};
  if (![settings isKindOfClass:[NSDictionary class]]) settings = nil;
  id command = [settings objectForKey:@"Command"] ?: defaultCommand();
  id seconds = [settings objectForKey:@"CountdownSeconds"] ?: @5;
  BOOL valid = (!exists || settings != nil) &&
    [command isKindOfClass:[NSArray class]] && [command count] > 0;
  if (valid) {
    for (id arg in command) {
      if (![arg isKindOfClass:[NSString class]]) { valid = NO; continue; }
      const char *bytes = [arg UTF8String];
      if (!bytes || strlen(bytes) != [arg lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) valid = NO;
    }
  }
  if (valid) valid = [[command objectAtIndex:0] isAbsolutePath] &&
    [[NSFileManager defaultManager] isExecutableFileAtPath:[command objectAtIndex:0]];
  BOOL validSeconds = [seconds isKindOfClass:[NSNumber class]] &&
    [seconds doubleValue] == [seconds integerValue] && [seconds integerValue] >= 1 && [seconds integerValue] <= 3600;
  if (!valid || !validSeconds) {
    NSLog(@"Sleep: invalid settings (command=%d, countdown=%d)", valid, validSeconds);
    showingError = YES;
    [NSApp activateIgnoringOtherApps:YES];
    NSRunAlertPanel(@"Sleep settings", @"Set Command to an array beginning with an executable's absolute path, and CountdownSeconds to an integer from 1 to 3600 in SleepWidget.plist.", @"OK", nil, nil);
    showingError = NO;
    [NSApp hide:nil];
    return;
  }
  // Snapshot settings before confirmation: edits during the dialog apply next time.
  NSArray *confirmedCommand = [command copy];
  NSInteger duration = [seconds integerValue];
  if (!panel) {
    panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,330,150)
      styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [panel setTitle:@"Sleep"]; [panel setDelegate:self]; [panel setReleasedWhenClosed:NO];
    label = [self text:@"" frame:NSMakeRect(15,92,300,30)];
    [label setFont:[NSFont boldSystemFontOfSize:18]];
    [[panel contentView] addSubview:label];
    [[panel contentView] addSubview:[self text:@"You can cancel before the countdown ends." frame:NSMakeRect(10,62,310,22)]];
    NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(115,17,100,30)] autorelease];
    [button setTitle:@"Cancel"]; [button setTarget:self]; [button setAction:@selector(cancel:)];
    [button setKeyEquivalent:@"\033"];
    [[panel contentView] addSubview:button];
  }
  counting = YES;
  modalResult = NSCancelButton;
  [label setStringValue:[NSString stringWithFormat:@"Sleeping in %ld…", (long)duration]];
  [NSApp activateIgnoringOtherApps:YES];
  [panel center]; [panel makeKeyAndOrderFront:nil];
  // Give the user the full interval after the dialog has appeared.
  deadline = monotonicTime() + duration;
  [self tick:nil];
  timer = [[NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
  // GNUstep's blocking runModalForWindow can keep waiting for native input
  // after a timer stops the session. Pump a real modal session with bounded
  // run-loop waits so unattended expiry never depends on another click.
  NSModalSession session = [NSApp beginModalSessionForWindow:panel];
  while (counting) {
    if ([NSApp runModalSession:session] != NSRunContinuesResponse) break;
    if (counting)
      [[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode
        beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  }
  [NSApp endModalSession:session];
  NSInteger result = modalResult;
  NSLog(@"Sleep: modal returned %ld", (long)result);
  counting = NO;
  [timer invalidate]; [timer release]; timer = nil;
  [panel orderOut:nil];
  // Return to the background after either outcome. Window Maker will then
  // activate us on the next Dock click, even after a cancelled countdown.
  [NSApp hide:nil];
  NSLog(@"Sleep: returned to background");
  if (result != NSOKButton) { [confirmedCommand release]; return; }

  // A file, not a pipe: arbitrary command output cannot block a child on a full pipe.
  NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Sleep-command-XXXXXX"];
  char *temporaryPath = strdup([template fileSystemRepresentation]);
  int fd = mkstemp(temporaryPath);
  if (fd < 0) {
    free(temporaryPath); [confirmedCommand release];
    showingError = YES;
    [NSApp activateIgnoringOtherApps:YES];
    NSRunAlertPanel(@"Sleep", @"Could not create the command log.", @"OK", nil, nil);
    showingError = NO; [NSApp hide:nil]; return;
  }
  logPath = [[NSString alloc] initWithUTF8String:temporaryPath]; free(temporaryPath);
  logHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
  task = [NSTask new];
  [task setLaunchPath:[confirmedCommand objectAtIndex:0]];
  [task setArguments:[confirmedCommand subarrayWithRange:NSMakeRange(1,[confirmedCommand count]-1)]];
  [confirmedCommand release];
  [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardOutput:logHandle]; [task setStandardError:logHandle];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finished:) name:NSTaskDidTerminateNotification object:task];
  @try { [task launch]; NSLog(@"Sleep: command started (PID %d)", [task processIdentifier]); }
  @catch (NSException *exception) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
    [task release]; task = nil; [logHandle release]; logHandle = nil;
    unlink([logPath fileSystemRepresentation]); [logPath release]; logPath = nil;
    showingError = YES;
    [NSApp activateIgnoringOtherApps:YES];
    NSRunAlertPanel(@"Sleep command failed", @"%@", @"OK", nil, nil, [exception reason]);
    showingError = NO;
    [NSApp hide:nil];
  }
}
- (void)finished:(NSNotification *)notification
{
  NSInteger status = [task terminationStatus];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
  [logHandle release]; logHandle = nil;
  NSString *path = [logPath autorelease]; logPath = nil;
  if (status != 0) {
    NSLog(@"Sleep: command failed with status %ld", (long)status);
    [NSApp activateIgnoringOtherApps:YES];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data = [file readDataOfLength:4096]; [file closeFile];
    NSString *details = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSRunAlertPanel(@"Sleep command failed", @"The command exited with status %ld.\n%@\nLog: %@", @"OK", nil, nil, (long)status, details ?: @"", path);
    [NSApp hide:nil];
  } else unlink([path fileSystemRepresentation]);
  [task release]; task = nil;
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self cancel:nil]; }
- (void)dealloc
{
  if (actionDisplay) {
    for (NSString *mode in @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode])
      [[NSRunLoop currentRunLoop] removeEvent:(void *)(intptr_t)ConnectionNumber(actionDisplay)
        type:ET_RDESC forMode:mode all:YES];
    XDestroyWindow(actionDisplay, actionWindow); XCloseDisplay(actionDisplay);
  }
  [timer invalidate]; [timer release];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [task release]; [logHandle release]; [logPath release];
  [panel release]; [view release]; [super dealloc];
}
@end

int main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  for (int i=1; i+1<argc; i++)
    if ((!strcmp(argv[i],"-autolaunch") || !strcmp(argv[i],"-NXAutoLaunch")) && !strcasecmp(argv[i+1],"YES")) autolaunched = YES;
  XInitThreads(); [NSApplication sharedApplication];
  if (argc==3 && !strcmp(argv[1],"--render-icon")) {
    SleepView *v = [[SleepView alloc] initWithFrame:NSMakeRect(0,0,64,64)];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(64,64)];
    [image lockFocus]; [v drawRect:[v bounds]];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[v bounds]];
    [image unlockFocus];
    BOOL ok = [[rep TIFFRepresentation] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES];
    [rep release]; [image release]; [v release]; [pool drain]; return ok ? 0 : 1;
  }
  SleepController *controller = [SleepController new]; [NSApp setDelegate:controller];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Sleep"];
  id<NSMenuItem> item = [menu addItemWithTitle:@"Sleep…" action:@selector(requestSleep:) keyEquivalent:@"s"];
  [item setTarget:controller];
  [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
  [NSApp setMainMenu:menu]; [menu release]; [NSApp run];
  [NSApp setDelegate:nil]; [controller release]; [pool drain]; return 0;
}
