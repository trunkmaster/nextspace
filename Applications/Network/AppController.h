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
  NSBrowser     *connectionList;
  NSPopUpButton *connectionAction;
  
  NSTextField *statusInfo;
  NSTextField *statusDescription;

  NSTextField *ipAddress;
  NSTextField *subnetMask;
  NSTextField *defaultGateway;
  NSTextField *dnsServers;
  NSTextField *searchDomains;
}

@property (readonly) DKProxy<NetworkManager> *networkManager;

@end
