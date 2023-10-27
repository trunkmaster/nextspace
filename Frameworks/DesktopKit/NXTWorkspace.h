#import <Foundation/NSString.h>

/* Notifications to communicate with applications. Manadatory prefixes in
   notification names are:
     - WMShould for notification from application to perform some action
     - WMDid to notify application about action completion
   Every WMDid should complement WMShould notification.

   All notifications object must be set to @"GSWorkspaceNotification".
   Otherwise Workspace Manager will ignore this notification.
   All notifications must contain in userInfo:
     "WindowID" = CFNumber;
     "ApplicationName" = CFString;
*/
// WM.plist
extern NSString* WMDidChangeAppearanceSettingsNotification;
// WMState.plist
extern NSString* WMDidChangeDockContentNotification;
// Hide All
extern NSString* WMShouldHideOthersNotification;
extern NSString* WMDidHideOthersNotification;
// Quit or Force Quit
extern NSString* WMShouldTerminateApplicationNotification;
extern NSString* WMDidTerminateApplicationNotification;
// Zoom Window
/* additional userInfo element:
   "ZoomType" = "Vertical" | "Horizontal" | "Maximize"; */
extern NSString* WMShouldZoomWindowNotification;
extern NSString* WMDidZoomWindowNotification;
// Tile Window
/* additional userInfo element:
   "TileDirection" = "Left" | "Right" | "Top" | "Bottom"; */
extern NSString* WMShouldTileWindowNotification;
extern NSString* WMDidTileWindowNotification;
// Shade Window
extern NSString* WMShouldShadeWindowNotification;
extern NSString* WMDidShadeWindowNotification;
// Arrange in Front
extern NSString* WMShouldArrangeWindowsNotification;
extern NSString* WMDidArrangeWindowsNotification;
// Miniaturize Window
extern NSString* WMShouldMinmizeWindowNotification;
extern NSString* WMDidMinmizeWindowNotification;
// Close Window
extern NSString* WMShouldCloseWindowNotification;
extern NSString* WMDidCloseWindowNotification;