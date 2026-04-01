
#include "WM.h"

#include <stdio.h>
#include <stdlib.h>
// #include <unistd.h>

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/xpm.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/shape.h>
#include <X11/Xmu/SysUtil.h>

#include "core/log_utils.h"
#include "systemtray.h"

#pragma mark - Definitions

/* Global variables */
volatile sig_atomic_t exitapp = False;
volatile sig_atomic_t sigusr = 0;

int iconsize = 16;
Bool need_update = False;

int screen = 0;
Window root = None;
Window selectionWindow = None;
static Time selectionTime;

static Window iconsWindow = None;
static struct trayIcon *icons = NULL;
// static TrayFillStyle fill_style = TrayFillHorizontal;
static int num_mapped_icons = 0;
static long selwindow_mask = PropertyChangeMask;
// static char *fgcolor = "#ffffff";
// static char *bgcolor = "#535353";

// XClassHint *classHint;
// XWMHints *wmHints;
// XSizeHints *sizeHints;
// Atom wmProtocols[2];
// XTextProperty machineName;
// static struct wm_atoms wm_atoms;
static struct tray_atoms tray_atoms;

#pragma mark - Utility functions

typedef int (*x_error_handler)(Display *, XErrorEvent *);
x_error_handler orig_x_error_handler = NULL;
static Bool x_error_occurred = False;

static int _ignoreBadWindowError(Display *d, XErrorEvent *e)
{
  if (e->error_code != BadWindow)
    orig_x_error_handler(d, e);
  // warn(DEBUG_INFO, "Ignoring BadWindow error");
  x_error_occurred = True;
  return 0;
}

void *setBadWindowErrorsHandler()
{
  x_error_occurred = False;
  if (!orig_x_error_handler) {
    orig_x_error_handler = XSetErrorHandler(&_ignoreBadWindowError);
    return (void *)orig_x_error_handler;
  } else {
    return (void *)XSetErrorHandler(&_ignoreBadWindowError);
  }
}

Bool removeBadWindowErrorsHandler(void *v)
{
  XSync(dpy, False);
  XSetErrorHandler((x_error_handler)v);
  return x_error_occurred;
}

Time currentXTime()
{
  XEvent ev;
  XChangeProperty(dpy, selectionWindow, XA_WM_CLASS, XA_STRING, 8, PropModeAppend, NULL, 0);
  XWindowEvent(dpy, selectionWindow, PropertyChangeMask, &ev);
  // warn(DEBUG_DEBUG, "X time is %ld", ev.xproperty.time);
  return ev.xproperty.time;
}

#pragma mark - Icons

static Bool isIconMapped(Window w)
{
  Bool is_mapped = True;
  Atom type;
  int format;
  unsigned long nitems, bytes_after;
  unsigned char *data;
  int ret = XGetWindowProperty(dpy, w, tray_atoms.xembed_info, 0, 2, False, tray_atoms.xembed_info, &type, &format,
                               &nitems, &bytes_after, &data);
  if (type == tray_atoms.xembed_info && format == 32 && nitems >= 2) {
    is_mapped = (((long *)data)[1] & 1) ? True : False;
  }
  if (ret == Success) {
    XFree(data);
  }
  return is_mapped;
}

struct trayIcon *trayIconAdd(Window w, void *data)
{
  if (exitapp)
    return NULL;

  struct trayIcon *icon = malloc(sizeof(struct trayIcon));
  if (!icon) {
    // warn(DEBUG_ERROR, "Memory allocation failed");
    return NULL;
  }

  void *v = setBadWindowErrorsHandler();
  XFixesChangeSaveSet(dpy, w, SetModeInsert, SaveSetRoot, SaveSetUnmap);
  if (removeBadWindowErrorsHandler(v)) {
    // warn(DEBUG_INFO, "Tray icon %lx is invalid, not adding", w);
    return NULL;
  }

  // warn(DEBUG_DEBUG, "Adding tray icon %lx", w);
  icon->w = w;
  icon->data = data;
  icon->parent = None;
  icon->x = 0;
  icon->y = 0;
  icon->mapped = False;
  icon->visible = False;
  icon->next = NULL;
  struct trayIcon **p;
  for (p = &icons; *p; p = &(*p)->next)
    ;
  *p = icon;
  need_update = True;
  return icon;
}

void _removeTrayIconWindow(struct trayIcon *icon)
{
  // warn(DEBUG_INFO, "SystemTray: Reparenting %lx to the root window", icon->w);
  void *v = setBadWindowErrorsHandler();
  XSelectInput(dpy, icon->w, NoEventMask);
  XUnmapWindow(dpy, icon->w);
  XReparentWindow(dpy, icon->w, root, 0, 0);
  removeBadWindowErrorsHandler(v);
  free(icon->data);
}

void trayIconRemove(Window w)
{
  struct trayIcon *icon, **n;
  n = &icons;
  while (*n) {
    icon = *n;
    if (icon->w == w) {
      *n = icon->next;
      // warn(DEBUG_DEBUG, "Removing tray icon %lx", icon->w);
      _removeTrayIconWindow(icon);
      if (icon->mapped) {
        num_mapped_icons--;
        need_update = True;
      }
      free(icon);
    } else {
      n = &icon->next;
    }
  }
}

struct trayIcon *trayIconFind(Window w)
{
  for (struct trayIcon *i = icons; i; i = i->next) {
    if (i->w == w)
      return i;
  }
  return NULL;
}

Bool trayIconSetIsMapped(struct trayIcon *icon, Bool map)
{
  if (icon->mapped == map) {
    return True;
  }
  // warn(DEBUG_DEBUG, "%sapping tray icon %lx", map ? "M" : "Unm", icon->w);
  icon->mapped = map;
  num_mapped_icons += map ? 1 : -1;
  need_update = True;
  return True;
}

Bool trayIconBeginMessage(Window w, int id, int length, int timeout)
{
  // warn(DEBUG_INFO, "begin_icon_message called for window %lx id %d (length=%d timeout=%d)", w, id,
  //      length, timeout);
  return False;
}

Bool getTrayIconMessageData(Window w, int id, char *data, int datalen)
{
  // warn(DEBUG_INFO, "icon_message_data called for window %lx id %d: %.*s", w, id, datalen, data);
  return False;
}

void trayIconCancelMessage(Window w, int id)
{
  // warn(DEBUG_INFO, "cancel_icon_message called for window %lx id %d", w, id);
}

#pragma mark - Windows

// static void updateWindow()
// {
//   struct trayIcon *icon;
//   int i, x, y;
//   Window dummy;
  
//   need_update = False;

// redo:
//   icon = icons;
//   x = y = i = 0;
//   while (icon) {
//     void *v = setBadWindowErrorsHandler();
//     if (!icon->mapped || i < 0) {
//       // warn(DEBUG_DEBUG, "Tray icon %lx is not visible", icon->w);
//       icon->visible = False;
//       if (icon->parent == None) {
//         // Parent it somewhere
//         // warn(DEBUG_DEBUG, "Reparenting %lx to %lx", icon->w, iconsWindow);
//         XReparentWindow(dpy, icon->w, iconsWindow, 0, 0);
//         icon->parent = iconsWindow;
//       }
//       XUnmapWindow(dpy, icon->w);
//     } else {
//       icon->visible = True;
//       switch (fill_style) {
//         case TrayFillHorizontal:
//           y = 4;
//           x += 8 + (i * iconsize);
//           break;
//         case TrayFillVertical:
//           y += 8 + (i * iconsize);
//           x = 4;
//           break;
//         default:
//           x = 8;
//           y = 8;
//           break;
//       }
//       // warn(DEBUG_DEBUG, "[%d] Tray icon %lx at %d,%d", i, icon->w, x, y);
//       if (icon->parent != iconsWindow) {
//         // warn(DEBUG_DEBUG, "Reparenting %lx to %lx", icon->w, iconsWindow);
//         XReparentWindow(dpy, icon->w, iconsWindow, x, y);
//         icon->parent = iconsWindow;
//       }
//       XMoveResizeWindow(dpy, icon->w, x, y, iconsize, iconsize);
//       XClearArea(dpy, icon->w, 0, 0, 0, 0, True);
//       XMapRaised(dpy, icon->w);
//       XTranslateCoordinates(dpy, icon->w, root, iconsize / 2, iconsize / 2, &icon->x, &icon->y,
//                             &dummy);
//     }
//     if (removeBadWindowErrorsHandler(v)) {
//       // warn(DEBUG_INFO, "Tray icon %lx is invalid, removing and restarting layout", icon->w);
//       trayIconRemove(icon->w);
//       goto redo;
//     }
//     if (icon->mapped) {
//       i++;
//     }
//     icon = icon->next;
//   }
// }

// static Pixel _pixelFromColor(char *color_description, Pixel default_pix)
// {
//   Pixel pix = 0;
//   XColor color;
//   XWindowAttributes a;

//   if (color_description == NULL) {
//     return default_pix;;
//   }

//   // warn(DEBUG_DEBUG, "Allocating colormap entry for fgcolor '%s'", fgcolor);

//   XGetWindowAttributes(dpy, root, &a);
//   color.pixel = 0;
//   if (!XParseColor(dpy, a.colormap, color_description, &color)) {
//     // warn(DEBUG_ERROR, "Specified foreground color '%s' could not be parsed, using Black", fgcolor);
//     pix = default_pix;
//   } else if (!XAllocColor(dpy, a.colormap, &color)) {
//     // warn(DEBUG_ERROR, "Cannot allocate colormap entry for foreground color '%s', using Black",
//     //      fgcolor);
//     pix = default_pix;
//   } else {
//     pix = color.pixel;
//   }

//   return pix;
// }

// static void createWindow(int argc, char **argv, int pid)
// {
//   Pixel fgpix, bgpix;

//   fgpix = _pixelFromColor(fgcolor, BlackPixel(dpy, screen));
//   bgpix = _pixelFromColor(bgcolor, WhitePixel(dpy, screen));

//   iconsWindow = XCreateSimpleWindow(dpy, root, sizeHints->x, sizeHints->y, sizeHints->width,
//                                     sizeHints->height, 1, fgpix, bgpix);

//   XSetWMNormalHints(dpy, iconsWindow, sizeHints);
//   XSetClassHint(dpy, iconsWindow, classHint);
//   XSetWMProtocols(dpy, iconsWindow, wmProtocols, 2);

//   XSelectInput(dpy, iconsWindow,
//                (ButtonPressMask | ExposureMask | ButtonReleaseMask | StructureNotifyMask |
//                 VisibilityChangeMask));

//   XStoreName(dpy, iconsWindow, PROGNAME);
//   XSetCommand(dpy, iconsWindow, argv, argc);
//   XSetWMClientMachine(dpy, iconsWindow, &machineName);
//   XChangeProperty(dpy, iconsWindow, wm_atoms.net_wm_pid, XA_CARDINAL, 32, PropModeReplace,
//                   (unsigned char *)&pid, 1);

//   XMapWindow(dpy, iconsWindow);

//   updateWindow();
// }

#pragma mark - Events handling

static void _sendXEembedNotify(Window w, Window parent)
{
  XEvent ev;
  ev.xclient.type = ClientMessage;
  ev.xclient.window = w;
  ev.xclient.message_type = tray_atoms.xembed;
  ev.xclient.format = 32;
  ev.xclient.data.l[0] = currentXTime();
  ev.xclient.data.l[1] = 0;  // XEMBED_EMBEDDED_NOTIFY
  ev.xclient.data.l[2] = 0;
  ev.xclient.data.l[3] = parent;
  ev.xclient.data.l[4] = 0;  // version
  void *v = setBadWindowErrorsHandler();
  XSendEvent(dpy, w, False, NoEventMask, &ev);
  if (removeBadWindowErrorsHandler(v)) {
    // warn(DEBUG_WARN, "Tray icon %lx is invalid", w);
    trayIconRemove(w);
  }
}

static void _handleDockRequest(Window w)
{
  // WMLogInfo("SystemTray: Dock request for window %lx", w);
  int *data = malloc(sizeof(int));
  if (!data) {
    // warn(DEBUG_ERROR, "memory allocation failed");
    return;
  }
  void *v = setBadWindowErrorsHandler();
  XWithdrawWindow(dpy, w, screen);
  XSelectInput(dpy, w, StructureNotifyMask | PropertyChangeMask);
  Bool isMapped = isIconMapped(w);
  if (removeBadWindowErrorsHandler(v)) {
    // warn(DEBUG_WARN, "SystemTray: Dock request for invalid window %lx", w);
    free(data);
    return;
  }
  struct trayIcon *icon = trayIconAdd(w, data);
  if (!icon) {
    free(data);
    return;
  }
  trayIconSetIsMapped(icon, isMapped);
}

static Bool _handleTrayPropertyNotify(XEvent *ev)
{
  struct trayIcon *icon;
  void *v;
  
  if (ev->xproperty.atom != tray_atoms.xembed_info) {
    return False;
  }
  icon = trayIconFind(ev->xproperty.window);
  if (!icon) {
    return False;
  }
  WMLogInfo("SystemTray: PropertyNotify for icon window %lx", ev->xproperty.window);
  v = setBadWindowErrorsHandler();
  Bool map = isIconMapped(icon->w);
  if (removeBadWindowErrorsHandler(v)) {
    // warn(DEBUG_WARN, "Tray icon %lx is invalid", icon->w);
    trayIconRemove(icon->w);
  } else {
    trayIconSetIsMapped(icon, map);
  }
  return True;
}

Bool _handleTrayConfigureNotify(XEvent *ev)
{
  struct trayIcon *icon;
  void *v;
  XWindowAttributes a;

  icon = trayIconFind(ev->xconfigure.window);
  if (!icon) {
    return False;
  }
  v = setBadWindowErrorsHandler();
  XGetWindowAttributes(dpy, icon->w, &a);
  if (a.width != iconsize || a.height != iconsize) {
    XResizeWindow(dpy, icon->w, iconsize, iconsize);
  }
  if (removeBadWindowErrorsHandler(v)) {
    // warn(DEBUG_WARN, "Tray icon %lx is invalid", icon->w);
    trayIconRemove(icon->w);
  }
  return True;
}

Bool _handleTrayReparentNotify(XEvent *ev)
{
  struct trayIcon *icon;

  icon = trayIconFind(ev->xreparent.window);
  if (!icon) {
    return False;
  }
  if (ev->xreparent.parent == iconsWindow) {
    _sendXEembedNotify(icon->w, ev->xreparent.parent);
  } else {
    // warn(DEBUG_WARN, "Tray icon %lx was reparented, removing", icon->w);
    trayIconRemove(icon->w);
  }
  return True;
}

Bool _handleTrayDestroyNotify(XEvent *ev)
{
  struct trayIcon *icon;

  icon = trayIconFind(ev->xdestroywindow.window);
  if (!icon) {
    return False;
  }
  // warn(DEBUG_WARN, "Tray icon %lx was destroyed, removing", icon->w);
  trayIconRemove(icon->w);
  return True;
}

Bool _handleClientMessage(XEvent *ev)
{
  struct trayIcon *icon;

  if (ev->xclient.message_type == tray_atoms.net_system_tray_opcode) {
    switch (ev->xclient.data.l[1]) {
      case 0:  // SYSTEM_TRAY_REQUEST_DOCK
        _handleDockRequest(ev->xclient.data.l[2]);
        break;

      case 1:  // SYSTEM_TRAY_BEGIN_MESSAGE
        icon = trayIconFind(ev->xclient.window);
        if (!icon) {
          return False;
        }
        *(int *)icon->data = ev->xclient.data.l[4];
        trayIconBeginMessage(icon->w, ev->xclient.data.l[4], ev->xclient.data.l[3],
                             ev->xclient.data.l[2]);
        break;

      case 2:  // SYSTEM_TRAY_CANCEL_MESSAGE
        icon = trayIconFind(ev->xclient.window);
        if (!icon) {
          return False;
        }
        trayIconCancelMessage(icon->w, ev->xclient.data.l[2]);
        break;
    }
    return True;
  } else if (ev->xclient.message_type == tray_atoms.net_system_tray_message_data) {
    icon = trayIconFind(ev->xclient.window);
    if (!icon) {
      return False;
    }
    getTrayIconMessageData(icon->w, *(int *)icon->data, ev->xclient.data.b, 20);
    return True;
  }

  return False;
}

Bool wSystemTrayHandleEvent(XEvent *ev)
{
  if (exitapp == True || selectionWindow == 0) {
    return False;
  }

  switch (ev->type) {
    case SelectionClear:
      if (ev->xselectionclear.selection == tray_atoms.net_system_tray_s &&
          XGetSelectionOwner(dpy, tray_atoms.net_system_tray_s) != selectionWindow) {
        // warn(DEBUG_ERROR,
        //      "SystemTray: Another application (window %lx) has forcibly taken the system tray "
        //      "registration",
        //      ev->xselectionclear.window);
        exitapp = True;
        return True;
      }
      break;

    case PropertyNotify:
      return _handleTrayPropertyNotify(ev);
      break;

    case ConfigureNotify:
      return _handleTrayConfigureNotify(ev);
      break;

    case ReparentNotify:
      return _handleTrayReparentNotify(ev);
      break;

    case DestroyNotify:
      return _handleTrayDestroyNotify(ev);
      break;

    case ClientMessage:
      return _handleClientMessage(ev);
      break;
  }
  return False;
}

// void runEventLoop()
// {
//   XEvent ev;
//   int fd;
//   fd_set rfds;
//
//   // warn(DEBUG_DEBUG, "Entering main loop");
//   while (!exitapp) {
//     while (XPending(dpy)) {
//       struct trayIcon *icon = NULL;
//       XNextEvent(dpy, &ev);
//       warn(DEBUG_DEBUG, "Got X event %d", ev.type);
//       switch (ev.type) {
//         case GraphicsExpose:
//         case Expose:
//         case MapRequest:
//           need_update = True;
//           break;
// 
//         case MapNotify: {
//           icon = trayIconFind(ev.xmap.window);
//           if (icon && !icon->visible) {
//             warn(DEBUG_WARN, "A poorly-behaved application tried to map window %lx!",
//                  ev.xmap.window);
//             need_update = True;
//           }
//         } break;
//
//         case UnmapNotify: {
//           icon = trayIconFind(ev.xunmap.window);
//           if (icon && icon->visible) {
//             warn(DEBUG_WARN, "A poorly-behaved application tried to unmap window %lx!",
//                  ev.xmap.window);
//             need_update = True;
//           }
//         } break;
//
//         case DestroyNotify: {
//           if (exitapp)
//             break;
//           if (selectionWindow == ev.xdestroywindow.window) {
//             warn(DEBUG_WARN, "Selection window %lx destroyed!", ev.xdestroywindow.window);
//             exitapp = 1;
//           }
//           if (iconsWindow == ev.xdestroywindow.window) {
//             warn(DEBUG_WARN, "Window %lx destroyed!", ev.xdestroywindow.window);
//             exitapp = 1;
//           }
//         } break;
//
//         case ButtonPress:
//           // switch (ev.xbutton.button) {
//           //   case 1:
//           //     down_window = ev.xbutton.window;
//           //     down_button = 0;
//           //     if (ev.xbutton.y >= 53 && ev.xbutton.y < 61) {
//           //       if (ev.xbutton.x >= 5 && ev.xbutton.x < 18) {
//           //         warn(DEBUG_INFO, "Left button mouse down");
//           //         down_button = -1;
//           //       } else if (ev.xbutton.x >= 46 && ev.xbutton.x < 59) {
//           //         warn(DEBUG_INFO, "Right button mouse down");
//           //         down_button = 1;
//           //       }
//           //     }
//           //     need_update = True;
//           //     break;
//           //   case 4:
//           //   case 6:
//           //     warn(DEBUG_INFO, "Left/Up scroll wheel");
//           //     if (current_page > 0) {
//           //       current_page--;
//           //       need_update = True;
//           //     }
//           //     break;
//           //   case 5:
//           //   case 7:
//           //     warn(DEBUG_INFO, "Right/Down scroll wheel");
//           //     if (current_page <
//           //         (num_mapped_icons - 1) / icons_per_row / icons_per_col / num_windows) {
//           //       current_page++;
//           //       need_update = True;
//           //     }
//           //     break;
//           // }
//           break;
//
//         case ButtonRelease:
//           // switch (ev.xbutton.button) {
//           //   case 1:
//           //     if (ev.xbutton.y >= 53 && ev.xbutton.y < 61) {
//           //       if (ev.xbutton.x >= 5 && ev.xbutton.x < 18 && down_button == -1) {
//           //         warn(DEBUG_INFO, "Left button mouse up");
//           //         if (current_page > 0) {
//           //           current_page--;
//           //           need_update = True;
//           //         }
//           //       } else if (ev.xbutton.x >= 46 && ev.xbutton.x < 59 && down_button == 1) {
//           //         warn(DEBUG_INFO, "Right button mouse up");
//           //         if (current_page <
//           //             (num_mapped_icons - 1) / icons_per_row / icons_per_col / num_windows) {
//           //           current_page++;
//           //           need_update = True;
//           //         }
//           //       }
//           //     }
//           //     down_window = None;
//           //     down_button = 0;
//           //     need_update = True;
//           //     break;
//           // }
//           break;
//
//         case ClientMessage:
//           if (ev.xclient.message_type == wm_atoms.wm_protocols && ev.xclient.format == 32) {
//             if (ev.xclient.data.l[0] == wm_atoms.net_wm_ping) {
//               warn(DEBUG_DEBUG, "_NET_WM_PING!");
//               ev.xclient.window = root;
//               XSendEvent(dpy, root, False, SubstructureNotifyMask | SubstructureRedirectMask,
//                          &ev);
//             } else if (ev.xclient.data.l[0] == wm_atoms.wm_delete_window) {
//               warn(DEBUG_DEBUG, "WM_DELETE_WINDOW called for %lx!", ev.xclient.window);
//               exitapp = 1;
//             }
//           }
//           break;
//       }
//       _handleTrayEvent(&ev);
//     }
//     if (exitapp) {
//       break;
//     }
//     warn(DEBUG_DEBUG, "Need update? %s", need_update ? "Yes" : "No");
//     if (need_update) {
//       updateWindow();
//     }
//     if (XPending(dpy)) {
//       continue;
//     }
//     fd = ConnectionNumber(dpy);
//     FD_ZERO(&rfds);
//     FD_SET(fd, &rfds);
//     select(fd + 1, &rfds, NULL, NULL, NULL);
//   }
//   // warn(DEBUG_DEBUG, "Main loop ended");
// }

#pragma mark - Init and quit

Bool wSystemTrayInit()
{
  char buf[50];
  XEvent ev;

  root = RootWindow(dpy, 0);
  // Create selection window
  selectionWindow = XCreateSimpleWindow(dpy, root, -1, -1, 1, 1, 0, 0, 0);
  XSelectInput(dpy, selectionWindow, selwindow_mask);
  // XSetClassHint(dpy, selectionWindow, classHint);
  // XSetWMProtocols(dpy, selectionWindow, wmProtocols, 2);
  XShapeCombineRectangles(dpy, selectionWindow, ShapeBounding, 0, 0, NULL, 0, ShapeSet,
                          YXBanded);

  // XStoreName(dpy, selectionWindow, PROGNAME);
  // XSetWMClientMachine(dpy, selectionWindow, &machineName);
  // XSetCommand(dpy, selectionWindow, argv, argc);
  // XChangeProperty(dpy, selectionWindow, wm_atoms.net_wm_pid, XA_CARDINAL, 32, PropModeReplace,
  //                 (unsigned char *)&pid, 1);

  // Get the necessary atoms
  snprintf(buf, sizeof(buf), "_NET_SYSTEM_TRAY_S%d", screen);
  tray_atoms.net_system_tray_s = XInternAtom(dpy, buf, False);
  tray_atoms.net_system_tray_opcode = XInternAtom(dpy, "_NET_SYSTEM_TRAY_OPCODE", False);
  tray_atoms.net_system_tray_message_data = XInternAtom(dpy, "_NET_SYSTEM_TRAY_MESSAGE_DATA", False);
  tray_atoms.manager = XInternAtom(dpy, "MANAGER", False);
  tray_atoms.xembed = XInternAtom(dpy, "_XEMBED", False);
  tray_atoms.xembed_info = XInternAtom(dpy, "_XEMBED_INFO", False);

  // Try to grab the system tray selection. ICCCM specifies that we first
  // check for an existing owner, then grab it with a non-CurrentTime
  // timestamp, then check again if we now own it.
  if (XGetSelectionOwner(dpy, tray_atoms.net_system_tray_s)) {
    // warn(DEBUG_WARN,
    //      "Another application is already running as the freedesktop.org protocol system tray");
    return False;
  }

  // Grabbing system tray selection
  selectionTime = currentXTime();
  XSetSelectionOwner(dpy, tray_atoms.net_system_tray_s, selectionWindow, selectionTime);
  if (XGetSelectionOwner(dpy, tray_atoms.net_system_tray_s) != selectionWindow) {
    // warn(DEBUG_WARN, "Failed to register as the freedesktop.org protocol system tray");
    return False;
  }

  // Notify anyone who cares that we are now accepting tray icons
  ev.type = ClientMessage;
  ev.xclient.window = root;
  ev.xclient.message_type = tray_atoms.manager;
  ev.xclient.format = 32;
  ev.xclient.data.l[0] = selectionTime;
  ev.xclient.data.l[1] = tray_atoms.net_system_tray_s;
  ev.xclient.data.l[2] = selectionWindow;
  ev.xclient.data.l[3] = 0;
  ev.xclient.data.l[4] = 0;
  XSendEvent(dpy, root, False, StructureNotifyMask, &ev);

  return True;
}

void wSystemTrayQuit()
{
  // warn(DEBUG_INFO, "Free selection");
  if (XGetSelectionOwner(dpy, tray_atoms.net_system_tray_s) == selectionWindow) {
    // warn(DEBUG_INFO, "SystemTray: Releasing system tray selection");
    // The ICCCM specifies "and the time specified as the timestamp that
    // was used to acquire the selection", so that what we do here.
    XSetSelectionOwner(dpy, tray_atoms.net_system_tray_s, None, selectionTime);
  }

  // warn(DEBUG_DEBUG, "Removing all icons");
  while (icons) {
    trayIconRemove(icons->w);
  }
}
