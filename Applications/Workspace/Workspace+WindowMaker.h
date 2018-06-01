/*
 * This header is for WindowMaker and Workspace integration
 */

#ifdef NEXTSPACE

//-----------------------------------------------------------------------------
// Common part
//-----------------------------------------------------------------------------
#include <dispatch/dispatch.h>
dispatch_queue_t workspace_q;
dispatch_queue_t wmaker_q;

//-----------------------------------------------------------------------------
// Visible in Workspace only
//-----------------------------------------------------------------------------
#ifdef __Foundation_h_GNUSTEP_BASE_INCLUDE

#undef _

#include <wraster.h>

#include <screen.h>
#include <window.h>
#include <event.h>
#include <dock.h>
#include <actions.h> // wArrangeIcons()
#include <application.h>
#include <appicon.h>
#include <shutdown.h> // Shutdown(), WSxxxMode
#include <client.h>
#include <wmspec.h>
// Appicons placement
#include <stacking.h>
#include <placement.h>

#undef _
#define _(X) [GS_LOCALISATION_BUNDLE localizedStringForKey: (X) value: @"" table: nil]

BOOL xIsWindowServerReady(void);
BOOL xIsWindowManagerAlreadyRunning(void);

BOOL useInternalWindowManager;

//-----------------------------------------------------------------------------
// Calls related to internals of WindowMaker.
// 'WWM' prefix is a vector of calls 'Workspace->WindowMaker'
//-----------------------------------------------------------------------------

void WWMInitializeWindowMaker(int argc, char **argv);
void WWMSetupFrameOffsetProperty();
void WWMSetDockAppiconState(int index_in_dock, int launching);
// Disable some signal handling inside WindowMaker code.
void WWMSetupSignalHandling(void);

// --- Logout/PowerOff related activities
void WWMWipeDesktop(WScreen * scr);
void WWMShutdown(WShutdownMode mode);

// --- Dock
void WWMDockInit(void);
void WWMDockShowIcons(WDock *dock);
void WWMDockHideIcons(WDock *dock);
void WWMDockUncollapse(WDock *dock);
void WWMDockCollapse(WDock *dock);

// - Should be called from already existing @autoreleasepool
NSString     *WWMDockStatePath(void);
NSDictionary *WWMDockState(void);
NSArray      *WWMDockStateApps(void);
void         WWMDockAutoLaunch(WDock *dock);

// Appicons getters/setters of on-screen Dock
WAppIcon  **launchingIcons;
NSInteger WWMDockAppsCount(void);
NSString  *WWMDockAppName(int position);
NSImage   *WWMDockAppImage(int position);
void      WWMSetDockAppImage(NSString *path, int position, BOOL saved);
BOOL      WWMIsDockAppAutolaunch(int position);
void      WWMSetDockAppAutolaunch(int position, BOOL autolaunch);
BOOL      WWMIsDockAppLocked(int position);
void      WWMSetDockAppLocked(int position, BOOL lock);
NSString  *WWMDockAppCommand(int position);
void      WWMSetDockAppCommand(int position, const char *command);
NSString  *WWMDockAppPasteCommand(int position);
void      WWMSetDockAppPasteCommand(int postion, const char *command);
NSString  *WWMDockAppDndCommand(int position);
void      WWMSetDockAppDndCommand(int position, const char *command);

WAppIcon *WWMCreateLaunchingIcon(NSString *wmName, NSImage *anImage,
                                 NSPoint sourcePoint,
                                 NSString *imagePath);
void WWMDestroyLaunchingIcon(WAppIcon *appIcon);
// - End of functions which require existing @autorelease pool

NSPoint _pointForNewLaunchingIcon(int *x_ret, int *y_ret);

#endif //__Foundation_h_GNUSTEP_BASE_INCLUDE

//-----------------------------------------------------------------------------
// Visible in WindowMaker and Workspace
// Workspace callbacks for WindowMaker.
//-----------------------------------------------------------------------------

char *XWSaveRasterImageAsTIFF(RImage *r_image, char *file_path);
  
// Applications creation and destroying
void XWApplicationDidCreate(WApplication *wapp, WWindow *wwin);
void XWApplicationDidAddWindow(WApplication *wapp, WWindow *wwin);
void XWApplicationDidDestroy(WApplication *wapp);
void XWApplicationDidCloseWindow(WWindow *wwin);

// Called from WM/src/event.c on update of XrandR screen configuration
void XWUpdateScreenInfo(WScreen *scr);
void XWWorkspaceDidChange(WScreen *scr, int workspace);
#include <dock.h> // to silence icon.c compile error
void XWDockContentDidChange(WDock *dock);

#endif //NEXTSPACE
