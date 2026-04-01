#ifndef __WORKSPACE_WM_SYSTEMTRAY__
#define __WORKSPACE_WM_SYSTEMTRAY__

#include <signal.h>
#include <X11/Xlib.h>

/*
 * Structs
 */
struct trayIcon {
  Window w;
  void *data;

  /* private */
  Bool mapped;
  Bool visible;
  Window parent;
  int x, y;
  struct trayIcon *next;
};

struct tray_atoms {
  Atom net_system_tray_s;
  Atom net_system_tray_opcode;
  Atom net_system_tray_message_data;
  Atom manager;
  Atom xembed;
  Atom xembed_info;
};

typedef enum TrayFillStyle { TrayFillHorizontal, TrayFillVertical } TrayFillStyle;

Bool wSystemTrayInit();
void wSystemTrayQuit();
Bool wSystemTrayHandleEvent(XEvent *ev);

/*
 * X functions
 */

// Call this before accessing any window not created by us. MUST be matched by
// a call to removeBadWindowErrorsHandler.
void *setBadWindowErrorsHandler();

// Pass the pointer from catch_BadWindow_errors. Returns True if an error was
// ignored.
Bool removeBadWindowErrorsHandler(void *v);

// Get the current X time
Time currentXTime();

/*
 * Icon handling
 */

// Call this to find out if a particular window is one of ours
Bool isIconParentWindow(Window w);

// Add an icon for the specified window. Returns NULL on error.
struct trayIcon *trayIconAdd(Window w, void *data);

// Remove the icon for the specified window.
void trayIconRemove(Window w);

// Find the icon struct for the specified window.
struct trayIcon *trayIconFind(Window w);

// Any sane icon protocol will have the icon indicate whether it should
// be mapped or not, rather than just trying to call XMapWindow or XUnmapWindow
// directly. Use this function to indicate that state change.
Bool trayIconSetIsMapped(struct trayIcon *icon, Bool map);

// If the icon wants us to display a popup message (rather than just using
// libnotify itself), begin by passing the metadata here. "id" must be unique
// for this window. Returns True if the message may be continued.
Bool trayIconBeginMessage(Window w, int id, int length, int timeout);

// After begin_icon_message(), call this function to pass the text of the
// message. It will automatically be displayed once the full length has been
// sent. No trailing '\0' is necessary.
Bool getTrayIconMessageData(Window w, int id, char *data, int datalen);

// If an existing popup is to be cancelled, call this.
void trayIconCancelMessage(Window w, int id);

#endif
