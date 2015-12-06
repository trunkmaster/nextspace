/*
*/
#import <AppKit/NSImage.h>
#import <Preferences.h>

@interface Password: NSObject <PrefsModule>
{
  IBOutlet id passwordTextField;
  IBOutlet id lockView;

  IBOutlet id window;
  IBOutlet id view;

  NSImage *lockOpenImage;
NSImage *lockImage;
NSImage *image;
}

- (IBAction) passwordChanged:(id)sender;

@end
