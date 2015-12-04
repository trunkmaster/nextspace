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
#include <application.h>
#include <appicon.h>
#include <shutdown.h> // Shutdown(), WSxxxMode
#include <client.h>
#include <wmspec.h>

#undef _
#define _(X) [GS_LOCALISATION_BUNDLE localizedStringForKey: (X) value: @"" table: nil]

BOOL xIsWindowManagerAlreadyRunning(void);

BOOL useInternalWindowManager;

//-----------------------------------------------------------------------------
// Calls related to internals of WindowMaker.
// 'WWM' prefix is a vector of calls 'Workspace->WindowMaker'
//-----------------------------------------------------------------------------

//--- Login related activities
// -- Should be called from already existing @autoreleasepool ---
NSString     *WWMStateCheck(void);
NSDictionary *WWMStateLoad(void);

NSString *WWMStateDockAppsKey();
NSArray  *WWMStateDockAppsLoad(void);
void      WWMStateDockAppsSave(NSArray *dockIcons);
NSArray  *WWMStateAutostartApps(void);

NSPoint WWMCreateLaunchingIcon(NSString *wmName,
                               NSImage *anImage,
                               NSPoint sourcePoint);
//--- End of functions which require existing @autorelease pool ---

void WWMInitializeWindowMaker(int argc, char **argv);
void WWMSetupFrameOffsetProperty();
void WWMSetDockAppiconState(int index_in_dock, int launching);
// Disable some signal handling inside WindowMaker code.
void WWMSetupSignalHandling(void);

//--- Logout/PowerOff related activities
void WWMWipeDesktop(WScreen * scr);
void WWMShutdown(WShutdownMode mode);

#endif //__Foundation_h_GNUSTEP_BASE_INCLUDE

//-----------------------------------------------------------------------------
// Visible in WindowMaker and Workspace
// Workspace callbacks for WindowMaker.
// 'WMW' prefix is a vector of calls 'WindowMaker->Workspace'
//-----------------------------------------------------------------------------

void XWApplicationDidCreate(WApplication *wapp, WWindow *wwin);
void XWApplicationDidAddWindow(WApplication *wapp, WWindow *wwin);

void XWApplicationDidDestroy(WApplication *wapp);
void XWApplicationDidCloseWindow(WWindow *wwin);

void xActivateWorkspace(void);

#endif //NEXTSPACE
