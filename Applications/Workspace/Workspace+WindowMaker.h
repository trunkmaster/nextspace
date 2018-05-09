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

//--- Login related activities
// -- Should be called from already existing @autoreleasepool ---

void WWMDockStateInit(void);
void WWMDockShowIcons(WDock *dock);

NSInteger WWMDockAppsCount();
BOOL      WWMIsDockAppAutolaunch(int position);
void      WWMSetDockAppAutolaunch(int position, BOOL autolaunch);
BOOL      WWMIsDockAppLocked(int position);
void      WWMSetDockAppLocked(int position, BOOL lock);
NSString  *WWMDockAppName(int position);
NSImage   *WWMDockAppImage(int position);
NSString  *WWMDockAppCommand(int position);

NSString     *WWMDockStatePath(void);
NSString     *WWMDockStateAppsKey();
NSArray      *WWMDockStateApps(void);
NSArray      *WWMStateAutostartApps(void);
NSDictionary *WWMDockState(void);

WAppIcon *WWMCreateLaunchingIcon(NSString *wmName, NSImage *anImage,
                                 NSPoint sourcePoint,
                                 NSString *imagePath);
void WWMDestroyLaunchingIcon(WAppIcon *appIcon);
//--- End of functions which require existing @autorelease pool ---

void WWMInitializeWindowMaker(int argc, char **argv);
void WWMSetupFrameOffsetProperty();
void WWMSetDockAppiconState(int index_in_dock, int launching);
// Disable some signal handling inside WindowMaker code.
void WWMSetupSignalHandling(void);

void WWMDockStateLoad(void);
void WWMDockShowIcons(WDock *dock);

//--- Logout/PowerOff related activities
void WWMWipeDesktop(WScreen * scr);
void WWMShutdown(WShutdownMode mode);

#endif //__Foundation_h_GNUSTEP_BASE_INCLUDE

//-----------------------------------------------------------------------------
// Visible in WindowMaker and Workspace
// Workspace callbacks for WindowMaker.
//-----------------------------------------------------------------------------

// Applications creation and destroying
void XWApplicationDidCreate(WApplication *wapp, WWindow *wwin);
void XWApplicationDidAddWindow(WApplication *wapp, WWindow *wwin);
void XWApplicationDidDestroy(WApplication *wapp);
void XWApplicationDidCloseWindow(WWindow *wwin);

// Called from WM/src/event.c on update of XrandR screen configuration
void XWUpdateScreenInfo(WScreen *scr);

void xActivateWorkspace(void);

#endif //NEXTSPACE
