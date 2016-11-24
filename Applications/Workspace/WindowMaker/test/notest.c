/* quick and dirty test application that demonstrates: Notify grabbing
 *
 * TODO: remake
 */

#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xproto.h>
#include <WMaker.h>

Display *dpy;
Window leader;
WMAppContext *app;
Atom delete_win;
Atom prots[6];
XWMHints *hints;
WMMenu *menu;

static void quit(void *foo, int item, Time time)
{
	exit(0);
}

static void hide(void *foo, int item, Time time)
{
	WMHideApplication(app);
}

int notify_print(int id, XEvent * event, void *data)
{
	printf("Got notification 0x%x, window 0x%lx, data '%s'\n", id, event->xclient.data.l[1], (char *)data);
	return True;
}

static void newwin(void *foo, int item, Time time)
{
	Window win;
	XClassHint classhint;
	char title[100];

	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 200, 100, 0, 0, 0);
	prots[0] = delete_win;
	XSetWMProtocols(dpy, win, prots, 1);
	sprintf(title, "Notify Test Window");
	XStoreName(dpy, win, title);

	/* set class hint */
	classhint.res_name = "notest";
	classhint.res_class = "Notest";
	XSetClassHint(dpy, win, &classhint);

	hints = XAllocWMHints();
	/* set window group leader */
	hints->window_group = leader;
	hints->flags = WindowGroupHint;
	XSetWMHints(dpy, win, hints);

	WMAppAddWindow(app, win);
	XMapWindow(dpy, win);
}

int main(int argc, char **argv)
{
	XClassHint classhint;

	dpy = XOpenDisplay("");
	if (!dpy) {
		puts("could not open display!");
		exit(1);
	}
	delete_win = XInternAtom(dpy, "WM_DELETE_WINDOW", False);

	leader = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 10, 10, 10, 10, 0, 0, 0);
	/* set class hint */
	classhint.res_name = "notest";
	classhint.res_class = "Notest";
	XSetClassHint(dpy, leader, &classhint);

	/* set window group leader to self */
	hints = XAllocWMHints();
	hints->window_group = leader;
	hints->flags = WindowGroupHint;
	XSetWMHints(dpy, leader, hints);

	/* create app context */
	app = WMAppCreateWithMain(dpy, DefaultScreen(dpy), leader);
	menu = WMMenuCreate(app, "Notify Test Menu");
	WMMenuAddItem(menu, "Hide", (WMMenuAction) hide, NULL, NULL, NULL);
	WMMenuAddItem(menu, "Quit", (WMMenuAction) quit, NULL, NULL, NULL);

	WMAppSetMainMenu(app, menu);
	WMRealizeMenus(app);

	/* Get some WindowMaker notifications */
	WMNotifySet(app, WMN_APP_START, notify_print, (void *)"App start");
	WMNotifySet(app, WMN_APP_EXIT, notify_print, (void *)"App end");
	WMNotifySet(app, WMN_WIN_FOCUS, notify_print, (void *)"Focus in");
	WMNotifySet(app, WMN_WIN_UNFOCUS, notify_print, (void *)"Focus out");
	WMNotifySet(app, WMN_NOTIFY_ALL, notify_print, (void *)"Unknown type");
	WMNotifyMaskUpdate(app);	/* Mask isn't actually set till we do this */

	/* set command to use to startup this */
	XSetCommand(dpy, leader, argv, argc);

	/* create first window */
	newwin(NULL, 0, 0);

	XFlush(dpy);
	while (1) {
		XEvent ev;
		XNextEvent(dpy, &ev);
		if (ev.type == ClientMessage) {
			if (ev.xclient.data.l[0] == delete_win) {
				XDestroyWindow(dpy, ev.xclient.window);
				break;
			}
		}
		WMProcessEvent(app, &ev);
	}
	exit(0);
}
