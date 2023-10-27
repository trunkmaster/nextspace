#import "NXTWorkspace.h"

// WM.plist
NSString* WMDidChangeAppearanceSettingsNotification = @"WMDidChangeAppearanceSettingsNotification";
// WMState.plist
NSString* WMDidChangeDockContentNotification = @"WMDidChangeDockContentNotification";
// Hide Others
NSString* WMShouldHideOthersNotification = @"WMShouldHideOthersNotification";
NSString* WMDidHideOthersNotification = @"WMDidHideOthersNotification";
// Quit or Force Quit
NSString* WMShouldTerminateApplicationNotification = @"WMShouldTerminateApplicationNotification";
NSString * WMDidTerminateApplicationNotification = @"WMDidTerminateApplicationNotification";
// Windows -> Zoom Window
NSString* WMShouldZoomWindowNotification = @"WMShouldZoomWindowNotification";
NSString* WMDidZoomWindowNotification = @"WMDidZoomWindowNotification";
// Windows -> Tile Window -> Left | Right | Top | Bottom
NSString* WMShouldTileWindowNotification = @"WMShouldTileWindowNotification";
NSString* WMDidTileWindowNotification = @"WMDidTileWindowNotification";
// Windows -> Shade Window
NSString* WMShouldShadeWindowNotification = @"WMShouldShadeWindowNotification";
NSString* WMDidShadeWindowNotification = @"WMDidShadeWindowNotification";
// Windows -> Arrange in Front
NSString* WMShouldArrangeWindowsNotification = @"WMShouldArrangeWindowsNotification";
NSString* WMDidArrangeWindowsNotification = @"WMDidArrangeWindowsNotification";
// Windows -> Miniaturize Window
NSString * WMShouldMinmizeWindowNotification = @"WMShouldMinmizeWindowNotification";
NSString* WMDidMinmizeWindowNotification = @"WMDidMinmizeWindowNotification";
// Windows -> Close Window
NSString* WMShouldCloseWindowNotification = @"WMShouldCloseWindowNotification";
NSString* WMDidCloseWindowNotification = @"WMDidCloseWindowNotification";
