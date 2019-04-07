
#include <WINGs/WINGs.h>
#include <stdlib.h>

#include "mywidget.h"

void wAbort()
{
	exit(1);
}

int main(int argc, char **argv)
{
	Display *dpy = XOpenDisplay("");
	WMScreen *scr;
	WMWindow *win;
	MyWidget *thing;

	WMInitializeApplication("Test", &argc, argv);

	if (!dpy) {
		wfatal("could not open display");
		exit(1);
	}

	scr = WMCreateSimpleApplicationScreen(dpy);

	/* init our widget */
	InitMyWidget(scr);

	win = WMCreateWindow(scr, "test");
	WMResizeWidget(win, 150, 50);

	thing = CreateMyWidget(win);
	SetMyWidgetText(thing, "The Test");
	WMResizeWidget(thing, 100, 20);
	WMMoveWidget(thing, 10, 10);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

	WMScreenMainLoop(scr);

	return 0;
}
