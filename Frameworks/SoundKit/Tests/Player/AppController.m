/* 
   Project: Player

   Author: Developer

   Created: 2019-02-21 15:58:25 +0200 by me
   
   Application Controller
*/

#import "Player.h"
#import "AppController.h"

@implementation AppController

+ (void) initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  /*
   * Register your app's defaults here by adding objects to the
   * dictionary, eg
   *
   * [defaults setObject:anObject forKey:keyForThatObject];
   *
   */
  
  [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
  NSLog(@"Application did finish launching.");
  [Player new];
}

- (BOOL)applicationShouldTerminate:(id)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

- (BOOL)application:(NSApplication *)application
           openFile:(NSString *)fileName
{
  return NO;
}

- (void)showPrefPanel:(id)sender
{
}

@end
