/* 
   Project: $PROJECTNAME$

   Author: $FULLUSERNAME$

   Created: $DATE$ by $USERNAME$
   
   Application Controller
*/

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

- (id) init
{
  if ((self = [super init]))
    {
    }
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (void) awakeFromNib
{
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
// Uncomment if your application is Renaissance-based
//  [NSBundle loadGSMarkupNamed: @"Main" owner: self];
}

- (BOOL) applicationShouldTerminate: (id)sender
{
  return YES;
}

- (void) applicationWillTerminate: (NSNotification *)aNotif
{
}

- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName
{
  return NO;
}

- (void) showPrefPanel: (id)sender
{
}

@end
