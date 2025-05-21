/*
 *  AppController.m 
 */

#import <DesktopKit/NXTOpenPanel.h>
#import <DesktopKit/NXTAlert.h>

#import "AppController.h"
#import "ImageWindow.h"
#import "Inspector.h"
#import "PrefController.h"

@implementation AppController

+ (void)initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)init
{
  if ((self = [super init]))
    {
      imageWindows = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void)dealloc
{
  RELEASE(imageWindows);

  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  [NSApp activateIgnoringOtherApps: YES];
  return [self openImageAtPath:fileName]; 
}

- (void)showPrefPanel:(id)sender
{
  if (preferences == nil)
    {
      preferences = [[PrefController alloc] init];
    }

  [preferences show];
}

- (void)showInspector:(id)sender
{
  if (inspector == nil)
    {
      inspector = [Inspector sharedInspector];
    }

  [inspector show];
}

//------------------------------------------------------------------------------

- (BOOL)openImageAtPath:(NSString *)path
{
  ImageWindow *win = [[ImageWindow alloc] initWithContentsOfFile:path];

  if (win) {
    [win setDelegate:self];
    [imageWindows addObject:win];
    return YES;
  }
  return NO;
}

- (void)openImage:(id)sender
{
  int result;
  NSArray *fileTypes = [NSImage imageFileTypes];
  NXTOpenPanel *openPanel = [NXTOpenPanel openPanel];
  NSString *pth = [[NSUserDefaults standardUserDefaults] objectForKey:@"OpenDir"];

  [openPanel setCanChooseDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  result = [openPanel runModalForDirectory:pth file:nil types:fileTypes];

  if (result == NSOKButton) {
    [[NSUserDefaults standardUserDefaults] setObject:[openPanel directory] forKey:@"OpenDir"];

    for (NSString *imageFile in [openPanel filenames]) {
      if (![self openImageAtPath:imageFile]) {
        NXTRunAlertPanel(@"Error when opening file", @"Couldn't open %@", @"OK", nil, nil,
                         imageFile);
      }
    }
  }
}

- (void)saveImageAs:(id)sender
{
  NXTSavePanel *savePanel = [NXTSavePanel new];
  NSString *fileName;

  if (savePanel) {
    NSWindow *keyWindow = [NSApp keyWindow];

    [savePanel runModal];
    fileName = [savePanel filename];
    if (fileName && [fileName length] > 0) {
      NSString *pathExtension = [fileName pathExtension];
      if (pathExtension.length == 0) {
        fileName = [fileName stringByAppendingPathExtension:@"tiff"];
      } else {
        fileName =
            [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
      }
    }

    for (ImageWindow *win in imageWindows) {
      if (win.window == keyWindow) {
        // NSData *data = [win.image TIFFRepresentation];
        NSBitmapImageRep *imgRep = [[win.image representations] objectAtIndex:0];
        NSData *data = [imgRep representationUsingType:NSPNGFileType properties:nil];
        if (data) {
          [data writeToFile:fileName atomically:NO];
        } else {
          NSLog(@"Can't save image - no data found!");
        }
        break;
      }
    }

    [savePanel release];
    savePanel = nil;
  }
}

- (void)imageWindowWillClose:(id)sender
{
  if (sender)
    {
      [imageWindows removeObject:sender];
      AUTORELEASE(sender);
    }
}

- (void)servicesOpenFileOrDirectory:(NSPasteboard *)pb
                           userData:(NSString *)ud 
			      error:(NSString **)msg
{
  // TODO : be able to deal with a real property list
  // i.e. to deal with the different the property lists types :
  // - a string
  // - an array of string (this is what we do at this time)
  // (what to do with dictionary or data ?)

  id  fileNamesPl;
  int i, count;

  fileNamesPl = [pb propertyListForType:NSFilenamesPboardType];

  if ([fileNamesPl respondsToSelector: @selector(count)] == NO)
    {
      // we only deal with NSArray
      // we cannot do a test on the class because the class is NSDistantObject
      NSRunAlertPanel(@"Process service request",
		      @"Unknown user data", @"OK", nil, nil,nil);
      return;
    }

  count = [fileNamesPl count];

  for (i = 0; i < count; i++)
    {
      NSFileManager *manager = [NSFileManager defaultManager];
      NSString      *imageFile = [fileNamesPl objectAtIndex: i];

      if ([manager fileExistsAtPath:imageFile])
	{
	  if (![self application:NSApp openFile:imageFile])
	    {
	      NSRunAlertPanel(@"Review service", 
			      @"Couldn't open %@", @"OK", nil, nil,imageFile);
	    }
	}
      else
	{
	  NSLog(@"Can't open %@", imageFile);
	}
    }
}

- (void)setDefaultSize:(id)sender
{
  NSWindow *mainWindow = [[NSApplication sharedApplication] mainWindow];

  if (mainWindow)
    {
      [mainWindow saveFrameUsingName:@"default ImagesWindow"];
    }
}

- (void)showInfoPanel:(id)sender
{
  if (!infoPanel) {
    if (![NSBundle loadNibNamed:@"InfoPanel" owner:self]) {
      NSLog (@"Failed to load InfoPanel.nib");
      return;
    }
   [infoPanel center];
  }
 [infoPanel makeKeyAndOrderFront:nil];
}

@end
