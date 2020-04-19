/* 
 * AppController.h
 */

#import <AppKit/AppKit.h>
#import "NetworkManager/NetworkManager.h"
#import "ConnectionManager.h"

@interface AppController : NSObject
{
  DKPort       *sendPort;
  NSConnection *connection;
  NSTimer      *timer;

  ConnectionManager *connMan;

  // Data
  NSMutableArray *connections;

  // GUI
  NSWindow      *window;
  NSBox         *contentBox;
  NSBrowser     *connectionList;
  NSPopUpButton *connectionAction;

  NSBox         *statusBox;
  NSTextField   *statusInfo;
  NSTextField   *statusDescription;
  NSView        *connectionView;
}

@property (readonly) DKProxy<NetworkManager> *networkManager;

@end
