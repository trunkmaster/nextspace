/* 
 * AppController.h
 */

#import <AppKit/AppKit.h>
#import "NetworkManager/NetworkManager.h"

@interface AppController : NSObject
{
  DKPort       *sendPort;
  NSConnection *connection;
  NSTimer      *timer;

  // GUI
  NSWindow      *window;
  NSBox         *contentBox;
  NSBrowser     *connectionList;
  NSPopUpButton *connectionAction;
  
  NSTextField   *statusInfo;
  NSTextField   *statusDescription;
  NSView        *connectionView;
}

@property (readonly) DKProxy<NetworkManager> *networkManager;

@end
