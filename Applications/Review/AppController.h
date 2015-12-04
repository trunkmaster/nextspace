/* 
 * AppController.h
 */

#import <AppKit/AppKit.h>

@class Inspector;
@class PrefController;

@interface AppController : NSObject
{
  NSMutableArray *images;

  Inspector      *inspector;
  PrefController *preferences;
}

+ (void)initialize;

- (id)init;
- (void)dealloc;

//- (void)applicationDidFinishLaunching:(NSNotification *)notif;

//- (BOOL)applicationShouldTerminate:(id)sender;
//- (void)applicationWillTerminate:(NSNotification *)notification;
//- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName;

- (void)showPrefPanel:(id)sender;

- (void)showInspector:(id)sender;

- (BOOL)openImageAtPath:(NSString *)path;
- (void)openImage:(id)sender;

- (void)imageWindowWillClose:(id)sender;

- (void)servicesOpenFileOrDirectory:(NSPasteboard *)pb     
			   userData:(NSString *)ud 
			      error:(NSString **)msg;

- (void)setDefaultSize:(id)sender;

@end
